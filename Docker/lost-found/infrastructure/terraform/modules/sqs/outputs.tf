output "item_created_queue_url" { value = aws_sqs_queue.item_created.url }
output "item_created_queue_arn" { value = aws_sqs_queue.item_created.arn }
output "match_found_queue_url"  { value = aws_sqs_queue.match_found.url }
output "match_found_queue_arn"  { value = aws_sqs_queue.match_found.arn }