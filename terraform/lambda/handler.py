"""Lambda: читає список книжок із S3 і повертає його через API Gateway (Lambda proxy)."""
import json
import os

import boto3

BUCKET = os.environ["BUCKET_NAME"]
KEY = os.environ.get("DATA_KEY", "books.json")
ENDPOINT = os.environ.get("S3_ENDPOINT")  # для floci/LocalStack, у справжньому AWS порожньо

s3 = boto3.client("s3", endpoint_url=ENDPOINT) if ENDPOINT else boto3.client("s3")


def _response(status, body):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json; charset=utf-8"},
        "body": json.dumps(body, ensure_ascii=False),
    }


def lambda_handler(event, context):
    try:
        obj = s3.get_object(Bucket=BUCKET, Key=KEY)
        books = json.loads(obj["Body"].read())
    except Exception as exc:  # noqa: BLE001
        return _response(500, {"error": str(exc)})

    params = (event or {}).get("queryStringParameters") or {}
    author = params.get("author")
    if author:
        books = [b for b in books if author.lower() in b["author"].lower()]

    return _response(200, {"count": len(books), "items": books})
