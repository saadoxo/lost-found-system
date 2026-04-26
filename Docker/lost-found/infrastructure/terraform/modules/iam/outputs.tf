output "ecs_node_instance_profile_arn" { value = aws_iam_instance_profile.ecs_node.arn }
output "ecs_task_role_arn"             { value = aws_iam_role.ecs_task.arn }
output "ecs_task_execution_role_arn"   { value = aws_iam_role.ecs_task_execution.arn }
