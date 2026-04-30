output "auth_service_name" { value = aws_ecs_service.auth.name }
output "item_service_name" { value = aws_ecs_service.item.name }
output "log_group_name"    { value = aws_cloudwatch_log_group.ecs.name }