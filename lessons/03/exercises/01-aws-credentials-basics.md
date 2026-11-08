# Exercise 1 — AWS Credentials Basics
**Difficulty:** ⭐☆☆☆ | **New concept:** `withCredentials` + `AmazonWebServicesCredentialsBinding`, verifying masking yourself

---

## Objective
Practice the exact mechanism the main Lesson 03 walkthrough demonstrated — binding a Jenkins-stored AWS credential into a pipeline — without being walked through every line.

## Task
Create a new Pipeline job `ex1-aws-credentials-basics` (UI script, not SCM) that:

1. Uses the existing `aws-s3-demo-creds` credential (from the main walkthrough) inside a `withCredentials` block
2. Runs `aws sts get-caller-identity` and prints the result — confirms which IAM identity the pipeline is actually using
3. Creates a small local test file and uploads it to the bucket from `terraform output bucket_name`, under a key like `exercise1/test.txt`, using `aws s3 cp`

Run it, then open **Console Output** and confirm the secret access key never appears in plaintext anywhere in the log — even in the `aws sts get-caller-identity` output (which includes your IAM user's ARN, but never the key itself).

## Constraints
- Do **not** hardcode the access key or secret anywhere in the script — only `withCredentials` may reference them.
- The uploaded file's key must include `exercise1/` as a prefix, so it doesn't collide with other exercises writing to the same bucket.

<details>
<summary>Hint 1 — withCredentials syntax</summary>

```groovy
withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-s3-demo-creds']]) {
    sh 'aws sts get-caller-identity'
    sh 'echo "test upload from exercise 1" > test.txt'
    sh 'aws s3 cp test.txt s3://<BUCKET_NAME>/exercise1/test.txt'
}
```
</details>

<details>
<summary>Hint 2 — where do I get the bucket name?</summary>

```bash
cd <path-to-jenkins-iccp>/lessons/03/terraform
terraform output bucket_name
```
</details>

## Done when
- [ ] The job runs green
- [ ] `aws sts get-caller-identity` output is visible in the console, showing the `jenkins-s3-demo` IAM user's ARN
- [ ] `exercise1/test.txt` exists in the bucket (verify with `aws s3 ls s3://<BUCKET_NAME>/exercise1/` from your own terminal)
- [ ] You can point to where in the console output Jenkins would have masked the secret, if it had ever been printed
