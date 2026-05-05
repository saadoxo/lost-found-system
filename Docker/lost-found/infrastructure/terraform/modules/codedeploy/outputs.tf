output "codedeploy_app_name"          { value = aws_codedeploy_app.ecs.name }
output "auth_green_tg_name"           { value = aws_lb_target_group.auth_green.name }
output "codedeploy_deployment_group"  { value = aws_codedeploy_deployment_group.auth.deployment_group_name }