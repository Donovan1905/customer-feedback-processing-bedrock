
provider "aws" {
  region = "eu-west-3"
}

resource "random_uuid" "example" {
}

resource "aws_s3_bucket" "feedback_storage" {
  bucket = "feedback-storage-bucket-${random_uuid.example.result}"
}

resource "aws_dynamodb_table" "feedback_table" {
  name         = "CustomerFeedback"
  hash_key     = "FeedbackID"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "FeedbackID"
    type = "S"
  }
}

resource "aws_cloudwatch_event_rule" "feedback_rule" {
  name        = "FeedbackEventRule"
  description = "Trigger Lambda to analyze customer feedback"
  event_pattern = jsonencode({
    "source": ["custom.feedback"],
    "detail": {
      "sentiment": [{
        "exists": false  # Ignore events that already have sentiment (processed events)
      }]
    }
  })
}


resource "aws_lambda_function" "process_feedback" {
  function_name = "ProcessFeedback"
  runtime       = "python3.9"
  handler       = "lambda_function.lambda_handler"
  role          = aws_iam_role.lambda_exec_role.arn
  filename      = "../lambda.zip"
  source_code_hash = filebase64sha256("../lambda.zip")


  environment {
    variables = {
      DYNAMODB_TABLE = aws_dynamodb_table.feedback_table.name
    }
  }
}


resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": "sts:AssumeRole",
        "Effect": "Allow",
        "Principal": {
          "Service": "lambda.amazonaws.com"
        }
      }
    ]
  })



  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  ]
}

resource "aws_iam_role_policy" "bedrock_access_policy" {
  name = "BedrockAccessPolicy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "bedrock:InvokeModel"
        ],
        "Resource": "arn:aws:bedrock:eu-west-3::foundation-model/anthropic.claude-3-haiku-20240307-v1:0"
      },
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:PutItem"
        ],
        "Resource": "${aws_dynamodb_table.feedback_table.arn}"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ddb_access_policy" {
  name = "DDBPolicy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:PutItem"
        ],
        "Resource": aws_dynamodb_table.feedback_table.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "ebe_access_policy" {
  name = "EBEPolicy"
  role = aws_iam_role.lambda_exec_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "events:PutEvents"
        ],
        "Resource": "arn:aws:events:eu-west-3:${data.aws_caller_identity.current.account_id}:event-bus/default"
      }
    ]
  })
}


resource "aws_cloudwatch_event_target" "feedback_event_target" {
  rule      = aws_cloudwatch_event_rule.feedback_rule.name
  target_id = "lambda"
  arn       = aws_lambda_function.process_feedback.arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_feedback.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.feedback_rule.arn
}

resource "aws_sns_topic" "feedback_alerts_topic" {
  name = "feedback-alerts-topic"
}

resource "aws_cloudwatch_event_rule" "feedback_negative_rule" {
  name        = "FeedbackNegativeRule"
  description = "Trigger when Negative feedback with score >= 3 is received"
  event_pattern = jsonencode({
    "source": ["custom.feedback_processed"],
    "detail-type": ["FeedbackEvent"],
    "detail": {
      "sentiment": ["Negative"],
      "score": [{
        "numeric": [">=", 3]  # Make sure you treat the score as a number
      }]
    }
  })
}


resource "aws_cloudwatch_event_target" "send_to_sns_target" {
  rule      = aws_cloudwatch_event_rule.feedback_negative_rule.name
  target_id = "sendToSNS"
  arn       = aws_sns_topic.feedback_alerts_topic.arn
}

# Create SNS topic policy to allow Eventbridge to publish to the SNS topic
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.feedback_alerts_topic.arn
  policy = jsonencode(
    {
      "Version" : "2008-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Principal" : {
            "Service" : "events.amazonaws.com"
          },
          "Action" : "sns:Publish",
          "Resource" : "${aws_sns_topic.feedback_alerts_topic.arn}",
          "Condition" : {
            "ArnEquals" : {
              "aws:SourceArn" : "${aws_cloudwatch_event_rule.feedback_negative_rule.arn}"
            }
          }
        }
      ]
    }
  )
}

resource "aws_s3_bucket" "athena_feedback_storage" {
  bucket = "athena-feedback-storage-${var.suffix}"
}

resource "aws_s3_bucket" "etl-job" {
  bucket = "etl-script-${var.suffix}"
}


resource "aws_glue_crawler" "dynamodb_feedback_crawler" {
  name         = "DynamoDBFeedbackCrawler"
  role         = aws_iam_role.glue_service_role.arn
  database_name = "feedback_catalog"
  table_prefix  = "dynamodb_"

  dynamodb_target {
    path = aws_dynamodb_table.feedback_table.name
  }

  configuration = jsonencode({
    "Version": 1.0,
    "CrawlerOutput": {
      "Partitions": {
        "AddOrUpdateBehavior": "InheritFromTable"
      }
    }
  })
}

resource "aws_iam_role" "glue_service_role" {
  name = "glue_service_role"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "glue.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_glue_job" "export_feedback_to_s3" {
  name        = "ExportFeedbackToS3"
  role_arn        = aws_iam_role.glue_service_role.arn
  command {
    name            = "glueetl"
    script_location = "s3://${aws_s3_bucket.etl-job.bucket}/export_feedback.py"
    python_version  = "3"
  }
  default_arguments = {
    "--job-language" = "python"
  }
}

resource "aws_iam_role_policy" "glue_dynamodb_s3_policy" {
  role = aws_iam_role.glue_service_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:Scan",
          "dynamodb:DescribeTable",
          "s3:PutObject",
          "s3:GetObject",  # Add this permission for reading the script from S3
          "glue:*"
        ],
        "Resource": [
          aws_dynamodb_table.feedback_table.arn,
          "arn:aws:s3:::${aws_s3_bucket.athena_feedback_storage.bucket}/*",
          "arn:aws:s3:::${aws_s3_bucket.etl-job.bucket}/*"  # Add this line for your etl-job bucket
        ]
      }
    ]
  })
}


resource "aws_s3_object" "export_feedback_script" {
  bucket = aws_s3_bucket.etl-job.bucket
  key    = "export_feedback.py"  # Path where the script will be stored in the bucket
  source = "${path.module}/../lambda/export_feedback.py"  # Path to the local file
  acl    = "private"  # Access control list
}

resource "aws_iam_role_policy" "glue_cloudwatch_logs_policy" {
  role = aws_iam_role.glue_service_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource": "arn:aws:logs:eu-west-3:${data.aws_caller_identity.current.account_id}:log-group:/aws-glue/*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role_policy" "glue_data_catalog_policy" {
  role = aws_iam_role.glue_service_role.id

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "glue:CreateDatabase",
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:CreateTable",
          "glue:UpdateTable"
        ],
        "Resource": [
          "arn:aws:glue:eu-west-3:${data.aws_caller_identity.current.account_id}:catalog",
          "arn:aws:glue:eu-west-3:${data.aws_caller_identity.current.account_id}:database/${aws_glue_crawler.dynamodb_feedback_crawler.database_name}",
           "arn:aws:glue:eu-west-3:${data.aws_caller_identity.current.account_id}:table/feedback_catalog/dynamodb_customerfeedback*"
        ]
      }
    ]
  })
}
