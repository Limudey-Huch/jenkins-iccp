output "bucket_name" {
  value = aws_s3_bucket.ci_artifacts.bucket
}

output "jenkins_access_key_id" {
  value = aws_iam_access_key.jenkins.id
}

output "jenkins_secret_access_key" {
  value     = aws_iam_access_key.jenkins.secret
  sensitive = true
}
