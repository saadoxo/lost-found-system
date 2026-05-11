output "match_notifications_arn" { value = aws_sns_topic.match_notifications.arn }
output "system_alerts_arn"       { value = aws_sns_topic.system_alerts.arn }