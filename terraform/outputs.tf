output "api_id" {
  value = aws_api_gateway_rest_api.api.id
}

output "api_url" {
  description = "URL ендпоінта GET /books"
  value = var.use_floci ? (
    "${var.floci_endpoint}/restapis/${aws_api_gateway_rest_api.api.id}/${var.stage_name}/_user_request_/books"
  ) : "${aws_api_gateway_stage.stage.invoke_url}/books"
}

output "bucket" {
  value = aws_s3_bucket.data.bucket
}

output "lambda" {
  value = aws_lambda_function.books.function_name
}
