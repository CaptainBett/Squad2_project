# infra/modules/glue_etl/glue_script.py
import sys, time, datetime
import boto3
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job
import pyspark.sql.functions as F
from pyspark.sql.types import LongType

# Accept args
args = getResolvedOptions(sys.argv, ['JOB_NAME', 'datalake_bucket', 'events_prefix', 'output_prefix'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

datalake_bucket = args['datalake_bucket']
events_prefix = args['events_prefix'].rstrip('/') + '/'
output_prefix = args['output_prefix'].rstrip('/') + '/'

print(f"[GLUE] bucket={datalake_bucket}, events_prefix={events_prefix}, output_prefix={output_prefix}", flush=True)

# enumerate JSON files using boto3 paginator (safe)
s3 = boto3.client("s3")
paginator = s3.get_paginator("list_objects_v2")
paths = []
max_files = 10000
for page in paginator.paginate(Bucket=datalake_bucket, Prefix=events_prefix):
    for obj in page.get("Contents", []):
        k = obj.get("Key")
        if not k:
            continue
        if k.lower().endswith(".json"):
            paths.append(f"s3://{datalake_bucket}/{k}")
            if len(paths) >= max_files:
                break
    if len(paths) >= max_files:
        break

print(f"[GLUE] json_files_found={len(paths)}", flush=True)
if len(paths) == 0:
    raise Exception(f"No JSON files found under s3://{datalake_bucket}/{events_prefix}")

# read JSON from explicit list of s3 paths
df = spark.read.json(paths)

# Normalization: support multiple timestamp fields and formats
# If event_time exists (ms) use it; else if timestamp numeric use it; else if timestamp string parse ISO.
def to_epoch_seconds_expr():
    # prefer event_time (ms), then timestamp numeric, then iso string parsed via unix_timestamp
    return (
        F.when(F.col("event_time").isNotNull(), (F.col("event_time")/1000).cast(LongType()))
         .when(F.col("timestamp").cast("bigint").isNotNull(), F.col("timestamp").cast(LongType()))
         .when(F.col("timestamp").isNotNull(), F.unix_timestamp(F.col("timestamp")).cast(LongType()))
         .otherwise(None)
    )

df2 = df.select(
    F.coalesce(F.col("user_id"), F.col("userId"), F.col("user")).alias("USER_ID"),
    F.coalesce(F.col("item_id"), F.col("itemId"), F.col("item")).alias("ITEM_ID"),
    to_epoch_seconds_expr().alias("TIMESTAMP")
)

# Filter out rows missing critical fields
df2_filtered = df2.where(F.col("USER_ID").isNotNull() & F.col("ITEM_ID").isNotNull() & F.col("TIMESTAMP").isNotNull())

# debug counts
count_all = df.count()
count_filtered = df2_filtered.count()
print(f"[GLUE] input_rows={count_all} filtered_rows={count_filtered}", flush=True)

# coalesce and write CSV (header for easier inspect; change header to false for Personalize)
if count_filtered > 0:
    df2_filtered_coalesced = df2_filtered.coalesce(1)
    df2_filtered_coalesced.write.mode("overwrite").option("header", "true").csv(f"s3://{datalake_bucket}/{output_prefix}interactions_tmp")
    print("[GLUE] wrote interactions_tmp CSV", flush=True)
else:
    print("[GLUE] no rows passed filter; nothing to write", flush=True)

job.commit()
print("[GLUE] job finished", flush=True)
