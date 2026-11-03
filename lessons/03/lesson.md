# Lesson 03 — Jenkins Security & Working with an External Provider (AWS)
**Course:** Jenkins | **Institution:** ICCP | **Duration:** ~3 hours

---

## Learning Objectives
By the end of this lesson, students will be able to:
- Explain core Jenkins security concepts: Credentials Store, secret masking, least privilege
- Configure basic Role/Matrix-based security in Jenkins
- Store AWS credentials securely using the Jenkins Credentials Store
- Use those credentials in a pipeline to upload an artifact to S3 and/or push a Docker image to ECR
- Understand why "credentials management" — not the API call itself — is the real security lesson here

---

## 1. Why Security Matters in CI/CD

A Jenkins controller typically holds the keys to everything: source code access, cloud provider credentials, registry tokens, deployment access. A pipeline that leaks a secret into its console log, or a job misconfigured with excessive permissions, can turn a CI server into the easiest path to compromising production.

**Core principle for this lesson:** the external API call (AWS, in our case) is almost incidental — the real skill is handling the credentials that authenticate to it *correctly*.

---

## 2. Jenkins Credentials Store

### What it is
A built-in, encrypted store (backed by Jenkins' own encryption keys on disk) for secrets: usernames/passwords, secret text, SSH keys, and cloud-provider credential types (including AWS Access Key/Secret Key).

### Where to configure it
**Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials**

### Credential Scopes
| Scope | Meaning |
|---|---|
| **Global** | Usable by any job on the controller |
| **System** | Usable only by Jenkins itself (not by jobs) — e.g., agent connection secrets |
| **Folder-scoped** | Usable only by jobs inside a specific folder — preferred for least privilege |

**Best practice:** scope credentials to the narrowest folder/job that actually needs them, instead of defaulting to Global.

### Secret Masking
When a credential is referenced via `withCredentials` (see below), Jenkins automatically masks its value in the console log, replacing it with `****`. This only works if the secret is accessed through the Credentials binding mechanism — **never** `echo`, `sh "echo $SECRET"`, or hardcode a secret directly in a `Jenkinsfile`, since both defeat masking and get committed to Git history.

### Prerequisite: the AWS Credentials plugin
The "suggested plugins" set installed during the initial Jenkins setup wizard (Lesson 01's install) does **not** include the **AWS Credentials** plugin. Without it, "AWS Credentials" will not appear as a Kind option when adding a credential, and `AmazonWebServicesCredentialsBinding` will fail. Install it first: **Manage Jenkins → Plugins → Available plugins → search "AWS Credentials" → Install**.

---

## 3. Least Privilege & Basic Access Control

- **Matrix-based security** (Manage Jenkins → Security → Authorization) lets you grant specific permissions (Job/Build, Job/Configure, Credentials/View, etc.) per user or group, instead of "everyone is admin."
- **Folder-scoped credentials + folder-scoped permissions** together mean a developer who can trigger builds in a "frontend" folder has no visibility into AWS credentials scoped to a "backend-deploy" folder.
- **Rule of thumb:** a pipeline/job should have access to exactly the credentials it needs to do its job — nothing more.

---

## 4. Hands-On: Storing AWS Credentials

### Provisioning the IAM user and bucket as code
Rather than clicking through the AWS Console, this lesson provisions the throwaway IAM user and S3 bucket with Terraform, committed to this course's materials at [`lessons/03/terraform`](terraform/). Run it from the Jenkins VM (it already has `aws-cli` and `terraform` configured):

```bash
cd ~/00_devops_course_iccp/jenkins-iccp/lessons/03/terraform
terraform init
terraform plan
terraform apply
```

`terraform apply` creates:
- An S3 bucket (public access blocked) — see `main.tf`'s `aws_s3_bucket.ci_artifacts`
- An IAM user `jenkins-s3-demo` with **one** attached policy (`aws_iam_user_policy.jenkins_s3_put_only`) that allows **only** `s3:PutObject` into that one bucket — no listing, no deleting, no other service. This is the least-privilege policy in practice, defined as code instead of a manual IAM Console click-through.

Retrieve the values you'll paste into Jenkins:
```bash
terraform output bucket_name
terraform output jenkins_access_key_id
terraform output -raw jenkins_secret_access_key
```

### Adding the credential in Jenkins
1. Go to **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**
2. Kind: **AWS Credentials**
3. Enter:
   - **ID:** a name you'll reference in the Jenkinsfile (e.g. `aws-s3-demo-creds`)
   - **Access Key ID** / **Secret Access Key:** the two Terraform outputs above
4. Save

---

## 5. Using AWS Credentials in a Pipeline

### Option A — Upload a build artifact to S3

```groovy
pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'echo "build output" > artifact.txt'
            }
        }

        stage('Publish to S3') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws-s3-demo-creds'
                ]]) {
                    sh '''
                        aws s3 cp artifact.txt s3://<BUCKET_NAME_FROM_TERRAFORM_OUTPUT>/builds/${BUILD_NUMBER}/artifact.txt
                    '''
                }
            }
        }
    }
}
```

`withCredentials` injects `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as environment variables **only for the duration of that block**, and Jenkins masks them in the console log automatically.

### Verifying the least-privilege boundary
Add one more stage using the same credential, but attempting an action the IAM policy does **not** grant:
```groovy
stage('Try Something Forbidden') {
    steps {
        withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-s3-demo-creds'
        ]]) {
            sh 'aws s3 ls'
        }
    }
}
```
This fails with `AccessDenied: ... not authorized to perform: s3:ListAllMyBuckets` — concrete proof that the Terraform policy's scope is enforced by AWS itself, not just documented intent.

### Option B — Push a Docker image to ECR

```groovy
stage('Push to ECR') {
    steps {
        withCredentials([[
            $class: 'AmazonWebServicesCredentialsBinding',
            credentialsId: 'aws-s3-demo-creds'
        ]]) {
            sh '''
                aws ecr get-login-password --region us-east-1 \
                    | docker login --username AWS --password-stdin 123456789012.dkr.ecr.us-east-1.amazonaws.com

                docker tag myapp:${BUILD_NUMBER} 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:${BUILD_NUMBER}
                docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/myapp:${BUILD_NUMBER}
            '''
        }
    }
}
```

This follows directly from the `docker push` step introduced in Lesson 02 — the only change is that the registry login now uses securely-stored AWS credentials instead of an open/anonymous registry.

---

## 6. What NOT to Do (Common Mistakes)

| Mistake | Why it's dangerous |
|---|---|
| Hardcoding `AWS_SECRET_ACCESS_KEY` in the `Jenkinsfile` | Committed to Git history forever, visible to anyone with repo read access |
| Using a long-lived IAM user with `AdministratorAccess` | One compromised Jenkins job = full AWS account compromise |
| `sh "echo $AWS_SECRET_ACCESS_KEY"` for "debugging" | Defeats Jenkins' automatic secret masking, leaks the secret to the build log |
| Credentials scoped as Global when only one folder needs them | Violates least privilege — every job on the controller can use them |

---

## References
- Jenkins Credentials: https://www.jenkins.io/doc/book/using/using-credentials/
- Matrix Authorization Strategy plugin: https://plugins.jenkins.io/matrix-auth/
- AWS Credentials plugin: https://plugins.jenkins.io/aws-credentials/
- IAM least privilege: https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html#grant-least-privilege

---

## Instructor Notes
- Run `terraform apply` in [`lessons/03/terraform`](terraform/) before class (or live, as part of the lesson) to provision the throwaway IAM user and bucket — don't use personal/root AWS credentials. Run `terraform destroy` after class to avoid leaving the IAM user and bucket around.
- Install the **AWS Credentials** plugin (Manage Jenkins → Plugins) before trying to add a credential of Kind "AWS Credentials" — it is not part of the suggested-plugins set from Lesson 01's install.
- Emphasize the console log masking live: run a build and show that the secret value never appears in the log, even though `withCredentials` injected it.
- Run the "Try Something Forbidden" stage (`aws s3 ls`) to get a real `AccessDenied` — this is the most convincing proof of least privilege in the whole lesson.
- Folder-scoped credentials (Section 3) are a real Jenkins feature worth explaining conceptually, but this lesson does not include a hands-on folder-scoping exercise — if time allows, it's a natural bonus extension (create two folders, scope the credential to one, show the other folder's job can't see it).
- If AWS access isn't available in the training environment, this lesson can be adapted 1:1 to Docker Hub (registry login) or GitHub (API token) — the credentials-handling lesson is identical regardless of provider.
