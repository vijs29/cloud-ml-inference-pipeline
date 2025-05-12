import json
import boto3
import os
from datetime import datetime

s3 = boto3.client("s3")
BUCKET = os.environ.get("BUCKET_NAME", "default-bucket-name")

def lambda_handler(event, context):
    print("Lambda invoked.")
    print(f"Using bucket: {BUCKET}")
    print(f"Received event: {json.dumps(event)}")

    key = f"event-{datetime.utcnow().isoformat()}.json"

    try:
        s3.put_object(
            Bucket=BUCKET,
            Key=key,
            Body=json.dumps(event)
        )
        print(f"Successfully wrote object to bucket: {BUCKET}, key: {key}")
        return {
            "statusCode": 200,
            "body": json.dumps({"message": "Event stored", "key": key})
        }
    except Exception as e:
        print(f"Error storing event: {str(e)}")
        return {
            "statusCode": 500,
            "body": json.dumps({"message": "Error storing event", "error": str(e)})
        }

