# Walkthrough 03 — Credentials, Least Privilege & AWS
In-class, instructor-led. This walkthrough deliberately does the *wrong* thing first (safely, with a throwaway secret) before fixing it — seeing a leak happen is far more memorable than being told not to leak.

---

## Setup (before class)
- Provision the throwaway IAM user and S3 bucket **as code** with the Terraform config committed at [`lessons/03/terraform`](terraform/) — not by clicking through the AWS Console. Replace `<path-to-jenkins-iccp>` below with wherever you placed this course folder on your machine:
  ```bash
  cd <path-to-jenkins-iccp>/lessons/03/terraform
  terraform init
  terraform apply
  terraform output bucket_name
  terraform output jenkins_access_key_id
  terraform output -raw jenkins_secret_access_key
  ```
  `main.tf` defines the IAM policy inline (least privilege: `s3:PutObject` on one bucket only) — see the file itself rather than retyping the JSON here.
- Install the **AWS Credentials** plugin before class: **Manage Jenkins → Plugins → Available plugins → "AWS Credentials" → Install**. It is not part of the suggested-plugins set installed during Lesson 01's setup wizard, and without it "AWS Credentials" won't appear as a Kind when adding a credential.
- Run `terraform destroy` after class to remove the IAM user and bucket.
- If no AWS access is available in the classroom, substitute Docker Hub (username/token) — the credentials-handling lesson is identical, just swap the binding type.

---

## Step 1 — Leak a secret on purpose (safely)

1. Create a Pipeline job `demo-leak` with Pipeline script:
   ```groovy
   pipeline {
       agent any
       environment {
           AWS_SECRET_ACCESS_KEY = 'THROWAWAY-DEMO-SECRET-VALUE'
       }
       stages {
           stage('Oops') {
               steps {
                   sh 'echo "Using secret: $AWS_SECRET_ACCESS_KEY"'
               }
           }
       }
   }
   ```
2. Run it → open Console Output → the secret is printed **in plain text**.

> **Explain:** this is exactly how real secrets leak — a hardcoded value plus a debug `echo` left in the pipeline. Anyone with "read console log" permission (often a wide group) now has the secret.

---

## Step 2 — Add the secret to the Credentials Store properly

1. **Manage Jenkins → Credentials → System → Global credentials → Add Credentials**
2. Kind: **AWS Credentials**, ID: `aws-s3-demo-creds`, paste the Access Key ID / Secret Access Key from the Terraform outputs.
3. Save.

> **Explain the scopes dropdown** while it's on screen: Global vs. System vs. folder-scoped. Ask: *"If only one folder/project needs this, why would we ever pick Global?"* (This class scopes it Global for simplicity — folder scoping is a real feature worth describing, even without a hands-on demo of it today.)

---

## Step 3 — Use `withCredentials` and compare the console log

1. Create a Pipeline job `demo-credentials-masked`:
   ```groovy
   pipeline {
       agent any
       stages {
           stage('Use Secret Correctly') {
               steps {
                   withCredentials([[
                       $class: 'AmazonWebServicesCredentialsBinding',
                       credentialsId: 'aws-s3-demo-creds'
                   ]]) {
                       sh 'echo "Using secret: $AWS_SECRET_ACCESS_KEY"'
                   }
               }
           }
       }
   }
   ```
2. Run it → open Console Output → the value now shows as `****`.

> **Explain the difference vs. Step 1:** same `echo` command, same environment variable name — the only change is that the secret came from `withCredentials` instead of a hardcoded string. Jenkins masks *any* value it recognizes as a bound credential, anywhere it appears in the log.

---

## Step 4 — Real external call: upload to S3, then hit the least-privilege wall

1. In the same job, add two more stages:
   ```groovy
   stage('Publish to S3') {
       steps {
           withCredentials([[
               $class: 'AmazonWebServicesCredentialsBinding',
               credentialsId: 'aws-s3-demo-creds'
           ]]) {
               sh '''
                   echo "build artifact from Jenkins build #${BUILD_NUMBER}" > artifact.txt
                   aws s3 cp artifact.txt s3://<BUCKET_NAME_FROM_TERRAFORM_OUTPUT>/builds/${BUILD_NUMBER}/artifact.txt
               '''
           }
       }
   }

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
2. Run it → **Publish to S3** succeeds; confirm with `aws s3 ls s3://<BUCKET_NAME>/builds/` from a shell with your own (admin) credentials.
3. **Try Something Forbidden** fails with `AccessDenied: ... not authorized to perform: s3:ListAllMyBuckets`.

> **Explain:** that `AccessDenied` is the Terraform IAM policy doing exactly its job — the credential works for its one approved action (`s3:PutObject` on one bucket) and nothing else, so even if it leaked, the blast radius is tiny. This is least privilege enforced by AWS itself, not just a policy document nobody reads.

---

## Wrap-up question for the class
*"Suppose this Jenkins controller gets fully compromised tomorrow. Looking at what we just built — the IAM policy scoped to one action on one bucket — what's the actual worst-case damage an attacker could do with this specific credential?"*

(Expected answer: upload a file to that one bucket — nothing else. No listing, no reading, no deleting, no other AWS service.)
