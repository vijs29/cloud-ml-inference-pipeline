import json
import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    print("Lambda invoked.")

    try:
        BUCKET = os.environ["BUCKET_NAME"]
        print(f"Using bucket: {BUCKET}")
    except KeyError:
        print("❌ BUCKET_NAME environment variable is missing.")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": "Missing BUCKET_NAME env var"})
        }

    print(f"Received event: {json.dumps(event)}")

    key = f"event-{datetime.utcnow().isoformat()}.json"
    s3 = boto3.client("s3")

    try:
        print("Writing to S3...")
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=json.dumps(event)
        )
        print("✅ S3 write successful")
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Event stored", "key": key})
        }
    except Exception as e:
        print(f"❌ Exception during S3 write: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
