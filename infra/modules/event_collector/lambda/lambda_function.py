import os, json, time
import boto3
from botocore.exceptions import ClientError

region = os.environ.get("REGION", "us-east-1")
ddb_table = os.environ.get("DDB_TABLE")
kinesis_stream = os.environ.get("KINESIS_STREAM") # This may be empty or None

dynamodb = boto3.resource("dynamodb", region_name=region)
table = dynamodb.Table(ddb_table)
kinesis = boto3.client("kinesis", region_name=region)

def lambda_handler(event, context):
    try:
        if event.get("body"):
            payload = json.loads(event["body"])
        else:
            payload = event

        user_id = str(payload.get("user_id", "anonymous"))
        event_type = payload.get("event_type", "unknown")
        item_id = payload.get("item_id", "none")
        ts = int(payload.get("timestamp", int(time.time() * 1000)))

        item = {
            "user_id": user_id,
            "event_time": ts,
            "event_type": event_type,
            "item_id": item_id
        }
        # Put item into DynamoDB
        table.put_item(Item=item)

        # Create record for Kinesis
        record = {"user_id": user_id, "event_time": ts, "event_type": event_type, "item_id": item_id}
        
        # Only put the record to Kinesis if the stream name is provided
        if kinesis_stream:
            kinesis.put_record(
                StreamName=kinesis_stream, 
                Data=json.dumps(record).encode("utf-8"), 
                PartitionKey=user_id
            )

        return {"statusCode": 200, "body": json.dumps({"status": "ok"})}

    except ClientError as e:
        # Specific boto3 error
        return {"statusCode": 500, "body": json.dumps({"error": str(e)})}
    except Exception as e:
        # General error (e.g., JSON parsing)
        return {"statusCode": 400, "body": json.dumps({"error": str(e)})}
