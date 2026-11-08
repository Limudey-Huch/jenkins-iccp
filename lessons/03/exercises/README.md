# Lesson 03 — Exercises

Four small, independent exercises reinforcing the core skills from this lesson: the AWS Credentials plugin, least privilege, the Build/Test/Publish pattern, and environments-per-branch. They're deliberately **separate from the Security Scan / ECR-ECS demo** (`walkthrough-security-scan.md`) — no new AWS infrastructure to provision here, just the IAM user / S3 bucket / credential already set up for the main Lesson 03 walkthrough.

| # | Exercise | New concept added | Builds on |
|---|---|---|---|
| 1 | [AWS Credentials Basics](01-aws-credentials-basics.md) | `withCredentials` + `AmazonWebServicesCredentialsBinding`, masking | Lesson 03 main walkthrough |
| 2 | [Catching an Expected Failure](02-catching-expected-failure.md) | `script { try/catch }` — handling a failure on purpose, without failing the build | Exercise 1 |
| 3 | [Build, Test, Publish From Scratch](03-build-test-publish-from-scratch.md) | Applying Lesson 02's pattern to a brand-new, tiny app you write yourself | Lesson 02 |
| 4 | [One Credential Per Branch](04-one-credential-per-branch.md) | Environments-per-branch (Walkthrough 02.5) combined with per-environment AWS credentials | Walkthrough 02.5, Exercise 1 |

Do them in order — each one assumes you're comfortable with what the previous one taught. All four reuse the IAM user, S3 bucket, and `aws-s3-demo-creds` Jenkins credential from the main Lesson 03 walkthrough — make sure that's already provisioned (`terraform apply` in `lessons/03/terraform`) and the credential exists before starting.
