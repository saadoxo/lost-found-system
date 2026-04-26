output "images_bucket_name" { value = aws_s3_bucket.images.bucket }
output "images_bucket_arn"  { value = aws_s3_bucket.images.arn }
output "images_dr_bucket_arn" { value = aws_s3_bucket.images_dr.arn }
