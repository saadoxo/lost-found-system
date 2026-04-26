output "cluster_name"    { value = aws_ecs_cluster.main.name }
output "cluster_arn"     { value = aws_ecs_cluster.main.arn }
output "ecs_node_sg_id"  { value = aws_security_group.ecs_node.id }
output "asg_name"        { value = aws_autoscaling_group.ecs.name }
