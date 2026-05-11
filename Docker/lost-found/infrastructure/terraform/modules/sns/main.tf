resource "aws_sns_topic" "match_notifications" {
  name = "${var.project}-match-notifications-${var.environment}"
  tags = var.common_tags
}

resource "aws_sns_topic" "system_alerts" {
  name = "${var.project}-system-alerts-${var.environment}"
  tags = var.common_tags
}

resource "aws_sns_topic_subscription" "sqs_match_found" {
  topic_arn = aws_sns_topic.match_notifications.arn
  protocol  = "sqs"
  endpoint  = var.match_found_queue_arn
}

# Allow the match-notifications SNS topic to send messages to the match_found SQS queue
resource "aws_sqs_queue_policy" "match_found_sns" {
  queue_url = var.match_found_queue_url

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSNSPublish"
        Effect    = "Allow"
        Principal = { Service = "sns.amazonaws.com" }
        Action    = "sqs:SendMessage"
        Resource  = var.match_found_queue_arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.match_notifications.arn
          }
        }
      }
    ]
  })
}