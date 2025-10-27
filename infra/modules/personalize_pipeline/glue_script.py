import sys
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from awsglue.context import GlueContext
from awsglue.job import Job 
import pyspark.sql.functions as F

args = getResolvedOptions(sys.argv, ['JOB_NAME', 'datalake_bucket', 'events_prefix', 'output_prefix'])
sc = SparkContext()
glueContext = GlueContext(sc)
spark = glueContext.spark_session
job = Job(glueContext)
job.init(args['JOB_NAME'], args)

datalake_bucket = args['datalake_bucket']
events_prefix = args['events_prefix'].rstrip('/') + '/'
output_prefix = args['output_prefix'].rstrip('/') + '/'

input_path = f"s3://{datalake_bucket}/{events_prefix}*"
output_path = f"s3://{datalake_bucket}/{output_prefix}"

# Read JSON files
df = spark.read.json(input_path)

# Common field names produced by the event consumer:
# user_id (string), event_time (number in ms), event_type, item_id
# Convert to expected Personalize interactions schema:
# USER_ID, ITEM_ID, TIMESTAMP (seconds since epoch)

df2 = df.select(
    F.col("user_id").alias("USER_ID"),
    F.col("item_id").alias("ITEM_ID"),
    (F.col("event_time")/1000).cast("long").alias("TIMESTAMP")
).where(F.col("USER_ID").isNotNull() & F.col("ITEM_ID").isNotNull())

# Write as single CSV file (coalesce(1) for small scale POC)
df2_coalesced = df2.coalesce(1)
df2_coalesced.write.mode("overwrite").option("header", "false").csv(output_path + "interactions_tmp")

# Move the generated part file to interactions.csv - Glue / S3 may produce part files; for POC we can keep the directory
# The Personalize import supports pointing to a prefix; referencing the folder is ok.
job.commit()
