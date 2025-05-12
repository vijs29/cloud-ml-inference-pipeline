provider "aws" {
  region = "us-west-2"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "event_data_bucket" {
  bucket        = "ml-inference-events-${random_id.suffix.hex}"
  force_destroy = true
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_s3_write" {
  name = "lambda-s3-write"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:PutObject"],
        Resource = "${aws_s3_bucket.event_data_bucket.arn}/*"
      }
    ]
  })
}

resource "aws_lambda_function" "event_ingestor" {
  function_name = "event-ingestor"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  filename      = "./../src/lambda_function_payload.zip"
  memory_size   = 128
  timeout       = 3

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.event_data_bucket.bucket
    }
  }
}

resource "aws_apigatewayv2_api" "api" {
  name          = "event-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id             = aws_apigatewayv2_api.api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.event_ingestor.invoke_arn
  integration_method = "POST"
  connection_type    = "INTERNET"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /ingest"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}

# ✅ SNS topic and email subscription
resource "aws_sns_topic" "s3_alerts" {
  name = "s3-alerts"
}

variable "alert_email" {
  description = "Email address to receive SNS alerts"
  type        = string
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.s3_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}


# ✅ CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "ingestion_dashboard" {
  dashboard_name = "ml-ingestion-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        x = 0,
        y = 0,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.event_ingestor.function_name ],
            [ ".", "Errors", ".", "." ],
            [ ".", "Duration", ".", "." ]
          ],
          view = "timeSeries",
          stacked = false,
          region = "us-west-2",
          title = "Lambda: Invocations / Errors / Duration"
        }
      },
      {
        type = "metric",
        x = 0,
        y = 6,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/ApiGateway", "4XXError", "ApiId", aws_apigatewayv2_api.api.id ],
            [ ".", "5XXError", ".", "." ],
            [ ".", "Latency", ".", "." ]
          ],
          view = "timeSeries",
          stacked = false,
          region = "us-west-2",
          title = "API Gateway: 4XX / 5XX / Latency"
        }
      },
      {
        type = "metric",
        x = 0,
        y = 12,
        width = 12,
        height = 6,
        properties = {
          metrics = [
            [ "AWS/S3", "TotalRequestLatency", "BucketName", aws_s3_bucket.event_data_bucket.bucket, "FilterId", "AllRequests" ],
            [ ".", "4xxErrors", ".", ".", ".", "." ],
            [ ".", "5xxErrors", ".", ".", ".", "." ]
          ],
          view = "timeSeries",
          stacked = false,
          region = "us-west-2",
          title = "S3 Request Metrics: Latency / 4xx / 5xx"
        }
      }
    ]
  })
}

# ✅ Alarms now send notifications to SNS
resource "aws_cloudwatch_metric_alarm" "s3_high_latency" {
  alarm_name          = "High-S3-Request-Latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "TotalRequestLatency"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Average"
  threshold           = 500
  alarm_description   = "Triggered when S3 latency exceeds 500ms"
  dimensions = {
    BucketName = aws_s3_bucket.event_data_bucket.bucket
    FilterId   = "AllRequests"
  }
  alarm_actions = [aws_sns_topic.s3_alerts.arn]
  ok_actions    = [aws_sns_topic.s3_alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "s3_5xx_errors" {
  alarm_name          = "S3-5xx-Errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "5xxErrors"
  namespace           = "AWS/S3"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  alarm_description   = "Triggered when S3 returns any 5xx errors"
  dimensions = {
    BucketName = aws_s3_bucket.event_data_bucket.bucket
    FilterId   = "AllRequests"
  }
  alarm_actions = [aws_sns_topic.s3_alerts.arn]
  ok_actions    = [aws_sns_topic.s3_alerts.arn]
}

output "api_url" {
  value = aws_apigatewayv2_stage.default.invoke_url
}
