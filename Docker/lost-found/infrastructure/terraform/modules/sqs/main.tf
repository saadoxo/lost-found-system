resource "aws_sqs_queue" "item_created" {
  name                      = "${var.project}-item-created-${var.environment}"
  message_retention_seconds = 86400
  visibility_timeout_seconds = 60

  tags = var.common_tags
}

resource "aws_sqs_queue" "match_found" {
  name                      = "${var.project}-match-found-${var.environment}"
  message_retention_seconds = 86400
  visibility_timeout_seconds = 60

  tags = var.common_tags
}

resource "aws_sqs_queue" "item_created_dlq" {
  name                      = "${var.project}-item-created-dlq-${var.environment}"
  message_retention_seconds = 1209600

  tags = var.common_tags
}

resource "aws_sqs_queue_redrive_policy" "item_created" {
  queue_url = aws_sqs_queue.item_created.id
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.item_created_dlq.arn
    maxReceiveCount     = 3
  })
}