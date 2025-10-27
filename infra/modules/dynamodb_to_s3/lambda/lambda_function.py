import os
import json
import boto3
import uuid
from datetime import datetime, timezone

s3 = boto3.client("s3", region_name=os.environ.get("REGION", "us-east-1"))
BUCKET = os.environ.get("BUCKET")

def convert_dynamodb_image(dynamo_image):
    # Convert DynamoDB JSON (type-wrapped) to plain JSON
    def unwrap(value):
        # value is a dict like {"S": "abc"} or {"N":"123"} or {"M": {...}} or {"L":[...]}
        if "S" in value:
            return value["S"]
        if "N" in value:
            # convert numeric strings to number when possible
            n = value["N"]
            try:
                if "." in n:
                    return float(n)
                return int(n)
            except:
                return n
        if "M" in value:
            return {k: unwrap(v) for k, v in value["M"].items()}
        if "L" in value:
            return [unwrap(i) for i in value["L"]]
        if "BOOL" in value:
            return value["BOOL"]
        if "NULL" in value:
            return None
        return value

    return {k: unwrap(v) for k, v in dynamo_image.items()}

def lambda_handler(event, context):
    try:
        records = event.get("Records", [])
        items = []
        for rec in records:
            # only handle INSERT/ MODIFY events with NewImage
            if rec.get("eventName") in ("INSERT", "MODIFY"):
                new_image = rec.get("dynamodb", {}).get("NewImage")
                if new_image:
                    items.append(convert_dynamodb_image(new_image))
        if not items:
            return {"statusCode": 200, "body": json.dumps({"status": "no_items"})}

        # create an S3 object key partitioned by date
        now = datetime.now(timezone.utc)
        date_prefix = now.strftime("year=%Y/month=%m/day=%d")
        file_key = f"events/{date_prefix}/{now.strftime('%H%M%S')}-{uuid.uuid4()}.json"

        payload = {
            "ingested_at": now.isoformat(),
            "count": len(items),
            "items": items
        }

        s3.put_object(
            Bucket=BUCKET,
            Key=file_key,
            Body=json.dumps(payload).encode("utf-8"),
            ContentType="application/json"
        )

        return {"statusCode": 200, "body": json.dumps({"status": "ok", "s3_key": file_key})}
    except Exception as e:
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
