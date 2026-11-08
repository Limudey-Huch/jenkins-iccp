# Exercise 4 — One Credential Per Branch
**Difficulty:** ⭐⭐⭐⭐ | **New concept:** combining environments-per-branch (Walkthrough 02.5) with per-environment AWS credentials

---

## Objective
Walkthrough 02.5 gave each environment its own branch and its own Jenkinsfile. This exercise adds the piece 02.5 didn't need: each environment's Jenkinsfile referencing a **different Jenkins credential ID**, so you practice the full shape of what you saw in the Security Scan walkthrough (`jenkins-deploy-dev` vs `jenkins-deploy-prod`) — without needing to provision any new AWS infrastructure to do it.

> **Simplification, on purpose:** in the Security Scan demo, `jenkins-deploy-dev` and `jenkins-deploy-prod` are genuinely different IAM users with different permissions, created by Terraform. Creating a second real IAM user isn't needed to practice *this* skill, so here you'll register the **same** existing AWS keys under a **second credential ID** in Jenkins — you're practicing the pipeline-side pattern (different branch → different credential ID), not re-provisioning AWS. The Done-when checklist asks you to explain this distinction.

## Task
1. In any repo you control (reuse `jenkins-pac`, or a new one), create two **new** branches — name them `cred-dev` and `cred-prod` (not `dev`/`prod`, to avoid clashing with Walkthrough 02.5's branches if you did that one in the same repo).
2. In Jenkins, add a **second** credential: Kind "AWS Credentials", using the **same** Access Key ID / Secret as `aws-s3-demo-creds`, but with a different ID — e.g. `aws-s3-demo-creds-prod`.
3. On `cred-dev`, commit a root `Jenkinsfile` that uploads a file to `s3://<BUCKET_NAME>/cred-exercise/dev/` using credential `aws-s3-demo-creds`.
4. On `cred-prod`, commit a **different** root `Jenkinsfile` that uploads to `s3://<BUCKET_NAME>/cred-exercise/prod/` using credential `aws-s3-demo-creds-prod`, and add an `Approval` stage (`input` step) before the upload — same gate pattern as Walkthrough 02.5's prod Jenkinsfile.
5. Create two Jenkins jobs (or one Multibranch Pipeline, your choice — see Walkthrough 02.5 for both patterns), one pinned to each branch.
6. Run both. Confirm `cred-dev` uploads immediately; `cred-prod` stops for approval first.

## Constraints
- The two Jenkinsfiles must reference **different credential IDs** — don't reuse `aws-s3-demo-creds` in both.
- The S3 key prefix must differ between the two (`cred-exercise/dev/` vs `cred-exercise/prod/`) so you can tell which pipeline wrote what, just by looking at the bucket.

<details>
<summary>Hint 1 — the dev Jenkinsfile shape</summary>

```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Upload') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-s3-demo-creds']]) {
                    sh '''
                        echo "dev upload" > file.txt
                        aws s3 cp file.txt s3://<BUCKET_NAME>/cred-exercise/dev/file.txt
                    '''
                }
            }
        }
    }
}
```
</details>

<details>
<summary>Hint 2 — the prod Jenkinsfile shape</summary>

Same as above, but swap the credential ID and S3 prefix, and add before the upload stage:
```groovy
stage('Approval') {
    steps {
        input message: "Upload to the prod prefix?", ok: "Upload"
    }
}
```
</details>

<details>
<summary>Hint 3 — how do I add a credential with the same keys under a new ID?</summary>

Manage Jenkins → Credentials → System → Global credentials → Add Credentials → Kind: AWS Credentials → paste the **same** Access Key ID / Secret Access Key you used for `aws-s3-demo-creds` (check `terraform output` again if you don't have them handy) → set **ID** to `aws-s3-demo-creds-prod`.
</details>

## Done when
- [ ] `cred-dev`'s pipeline runs straight through and a file lands under `cred-exercise/dev/` in the bucket
- [ ] `cred-prod`'s pipeline stops at Approval, and only after clicking Deploy does a file land under `cred-exercise/prod/`
- [ ] You can explain the difference between what you just built and the real `jenkins-deploy-dev`/`jenkins-deploy-prod` setup from the Security Scan walkthrough — specifically, that here both credentials are secretly the *same* IAM identity under two Jenkins-side IDs, while there they're two genuinely different IAM users with different permissions
