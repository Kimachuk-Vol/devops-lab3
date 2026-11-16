############################
# S3: сховище даних
############################
resource "aws_s3_bucket" "data" {
  bucket        = "${var.project}-data"
  force_destroy = true
}

resource "aws_s3_object" "books" {
  bucket       = aws_s3_bucket.data.id
  key          = "books.json"
  source       = "${path.module}/data/books.json"
  etag         = filemd5("${path.module}/data/books.json")
  content_type = "application/json"
}

############################
# IAM: роль для Lambda
############################
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.project}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

data "aws_iam_policy_document" "lambda_s3_read" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.data.arn}/*"]
  }
  statement {
    actions   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "lambda_s3_read" {
  name   = "${var.project}-s3-read"
  role   = aws_iam_role.lambda.id
  policy = data.aws_iam_policy_document.lambda_s3_read.json
}

############################
# Lambda
############################
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/build/lambda.zip"
}

resource "aws_lambda_function" "books" {
  function_name    = "${var.project}-get-books"
  role             = aws_iam_role.lambda.arn
  runtime          = "python3.12"
  handler          = "handler.lambda_handler"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  timeout          = 10

  environment {
    variables = merge(
      {
        BUCKET_NAME = aws_s3_bucket.data.bucket
        DATA_KEY    = aws_s3_object.books.key
      },
      # Lambda у floci працює в окремому Docker-контейнері, тому S3 шукаємо через host.docker.internal
      var.use_floci ? { S3_ENDPOINT = "http://host.docker.internal:4566" } : {}
    )
  }
}

############################
# API Gateway (REST): GET /books
############################
resource "aws_api_gateway_rest_api" "api" {
  name        = "${var.project}-api"
  description = "Books API (Lab 3, Kimachuk)"
}

resource "aws_api_gateway_resource" "books" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "books"
}

resource "aws_api_gateway_method" "get_books" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.books.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "get_books" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.books.id
  http_method             = aws_api_gateway_method.get_books.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.books.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.books.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.books.id,
      aws_api_gateway_method.get_books.id,
      aws_api_gateway_integration.get_books.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
  stage_name    = var.stage_name
}
