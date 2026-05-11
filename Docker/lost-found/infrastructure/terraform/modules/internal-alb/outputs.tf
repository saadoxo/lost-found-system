output "internal_alb_dns"         { value = aws_lb.internal.dns_name }
output "internal_alb_arn"         { value = aws_lb.internal.arn }
output "internal_listener_arn"    { value = aws_lb_listener.internal_http.arn }
output "internal_alb_sg_id"       { value = aws_security_group.internal_alb.id }