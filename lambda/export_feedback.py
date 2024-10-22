import sys
from pyspark.context import SparkContext
from awsglue.transforms import *
from awsglue.utils import getResolvedOptions
from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame

args = getResolvedOptions(sys.argv, ['JOB_NAME'])
glueContext = GlueContext(SparkContext.getOrCreate())

# Read data from DynamoDB
dynamo_frame = glueContext.create_dynamic_frame.from_options(
    connection_type="dynamodb",
    connection_options={
        "dynamodb.input.tableName": "CustomerFeedback"
    }
)

# Write data to S3
s3_frame = glueContext.write_dynamic_frame.from_options(
    frame = dynamo_frame,
    connection_type = "s3",
    connection_options = {"path": "s3://<your bucket>/"},
    format = "json"
)
