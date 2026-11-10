# Walkthrough 03b — Security Scan + Real AWS Deploy (ECR/ECS)
In-class, instructor-led. Optional extension to Lesson 03 — do this after the main Credentials/S3 walkthrough. Uses a new app ([`demo-app/`](demo-app/), a jewelry order system — client + server + db) and new AWS infrastructure, kept separate from the S3/IAM work already done in this lesson.

## What this adds on top of the main Lesson 03 walkthrough
1. **OWASP Dependency-Check** — a new Jenkins plugin that scans `requirements.txt` for dependencies with known CVEs and can fail the build.
2. **Real multi-service AWS infrastructure** (ECR + ECS Fargate, via Terraform) instead of just one S3 bucket — client, server and db, each in their own container, each environment in its own VPC.
3. **Two separate least-privilege deploy identities** (`jenkins-deploy-dev`, `jenkins-deploy-prod`) instead of one.

---

## Prerequisites (before class)

1. **Install the OWASP Dependency-Check plugin**: Manage Jenkins → Plugins → Available plugins → "OWASP Dependency-Check" → Install.
2. **Configure the Dependency-Check tool**: Manage Jenkins → Tools → "Dependency-Check installations" → Add → name it exactly `OWASP-DC` (matches `odcInstallation` in the Jenkinsfiles) → check "Install automatically" → **Add Installer → "Install from github.com"** (this is the step that's easy to miss — without it, the tool has no actual binary and every run fails with `Couldn't find any executable in "null"`).
3. **Get a free NVD API key**: as of 2024, NIST requires one to download the CVE database at all — without it, the scan fails immediately with `Invalid API Key, length of 0`. Register at https://nvd.nist.gov/developers/request-an-api-key (instant, free, emailed to you). Add it to Jenkins as a **Secret text** credential, ID: `nvd-api-key`.
4. A **new GitHub repo** for this app (don't reuse `jenkins-pac` from Lessons 01/02) — e.g. `jewelry-orders`. Push the whole [`demo-app/`](demo-app/) folder to it as the repo root (same pattern as Lesson 02: `Jenkinsfile.dev`/`Jenkinsfile.prod` sit at the repo root alongside `client/`, `server/`, `scripts/`, `terraform/`).
5. AWS CLI and Terraform already configured on the VM (same as the main Lesson 03 walkthrough).

**If you already ran `terraform apply` for `dev`/`prod` before this note was added:** re-apply both — the deploy users' IAM policy picked up `ecr:BatchGetImage`, needed because modern Docker (BuildKit) attaches a provenance manifest to every push, which requires a read-back mid-push that the original push-only policy didn't allow.
```bash
cd dev && terraform apply
cd ../prod && terraform apply
```

**Also check your Jenkins build host's architecture before your first deploy:**
```bash
docker version --format '{{.Server.Arch}}'
```
If that prints `arm64` (common when Jenkins runs on an ARM-based host, e.g. an Apple Silicon Mac under virtualization), every image you build is ARM64-only — but Fargate defaults to `X86_64`, and the service will sit stuck with `runningCount: 0` forever, failing with `CannotPullContainerError: ... does not contain descriptor matching platform 'linux/amd64'`. The task definitions here already request ARM64 Fargate capacity (`runtime_platform` in `ecs.tf`) to match — if your build host is `amd64` instead, delete those `runtime_platform` blocks before applying. Either way, re-apply `dev` and `prod` after this change takes effect for the first time.

---

## Step 1 — Provision the shared ECR repos (once)

```bash
cd <path-to-jenkins-iccp>/lessons/03/demo-app/terraform/shared
terraform init
terraform apply
```

---

## Step 2 — Provision the dev environment

```bash
cd ../dev
terraform init
terraform apply
terraform output deploy_user_access_key_id
terraform output -raw deploy_user_secret_access_key
```

> **Explain:** this one `terraform apply` creates an entire isolated stack — VPC, subnet, 3 security groups, ECS cluster, Cloud Map namespace, Secrets Manager secret, the task execution role, and the `jenkins-deploy-dev` IAM user — all from one small root file that just calls `../modules/environment` with `environment = "dev"`. Worth opening [`terraform/modules/environment/`](demo-app/terraform/modules/environment/) and asking the class: why a module instead of just copy-pasting these files into a `prod/` folder too, the way we did with the Jenkinsfiles back in Walkthrough 02.5? (Answer: here the infrastructure *shape* is identical between environments — only values differ — so parameterizing with a module avoids maintaining the same 200+ lines twice. Contrast with the Jenkinsfiles, which have genuinely *different logic* per environment — that's still worth keeping as separate files.)

## Step 3 — Provision the prod environment

```bash
cd ../prod
terraform init
terraform apply
terraform output deploy_user_access_key_id
terraform output -raw deploy_user_secret_access_key
```

## Step 4 — Add both deploy credentials to Jenkins

Manage Jenkins → Credentials → add twice:
- Kind: **AWS Credentials**, ID: `aws-jewelry-dev-deploy` — Access Key ID / Secret from Step 2
- Kind: **AWS Credentials**, ID: `aws-jewelry-prod-deploy` — Access Key ID / Secret from Step 3

> **Explain:** notice these are *not* your personal AWS credentials, and not the same credential from the S3 demo earlier in this lesson. Each one is the narrow `jenkins-deploy-<env>` user Terraform just created — open `terraform/modules/environment/iam.tf` and walk through what it can and can't do. It can push to the 2 ECR repos and update ECS services in its own cluster only. It cannot create a VPC, cannot touch IAM, cannot read Secrets Manager, cannot see the other environment's cluster at all.

---

## Step 5 — Create the two Jenkins jobs

**`jewelry-dev`**
1. New Item → Pipeline → Pipeline script from SCM → Git → your new repo URL + `github-pat` (or a new PAT credential if this is a different GitHub account) → Branch `*/main`
2. **Script Path**: `Jenkinsfile.dev`

**`jewelry-prod`**
Same, but **Script Path**: `Jenkinsfile.prod`.

---

## Step 6 — Run dev: watch the security scan and the real deploy

1. Build Now on `jewelry-dev`.
2. Watch the stages: **Checkout → Build → Test → Security Scan → Push to ECR → Deploy to Dev**.
3. Open the **Security Scan** stage's result — the build should show a finding for `requests==2.19.1` (the intentionally old, vulnerable version pinned in `server/requirements.txt`) with its CVE ID and severity.

> **Explain:** this is the same "watch a failure happen correctly" pattern from Lesson 02's Walkthrough Step 3, just for a security finding instead of a failing test — the scan doesn't need to *block* the build to be useful (ours doesn't fail on it, just reports it), but ask the class: in a real pipeline, at what severity would you want this to fail the build outright, and why not always fail on any finding at all? (Hint: a zero-tolerance policy on every low-severity CVE in every transitive dependency would make most real-world pipelines un-buildable — the practical answer is almost always "fail above a chosen severity threshold, report everything else.")

4. Find the client's public IP (it changes every deploy — no load balancer in this lab). **Add `--region us-east-1` to every AWS CLI call below** — the VM's CLI default region is something else, and these commands silently return nothing against the wrong region:
   ```bash
   TASK_ARN=$(aws ecs list-tasks --cluster jewelry-dev-cluster --service-name client --region us-east-1 --query 'taskArns[0]' --output text)
   echo "Task ARN: $TASK_ARN"   # if this prints "None", the task isn't RUNNING yet (still Pending/pulling the image) — wait ~30-60s and re-run this line, don't continue yet

   ENI_ID=$(aws ecs describe-tasks --cluster jewelry-dev-cluster --tasks "$TASK_ARN" --region us-east-1 \
     --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' --output text)
   echo "ENI ID: $ENI_ID"

   aws ec2 describe-network-interfaces --network-interface-ids "$ENI_ID" --region us-east-1 \
     --query 'NetworkInterfaces[0].Association.PublicIp' --output text
   ```
   Run all three lines in the same shell session — each depends on the variable set by the one before it. The `echo` lines matter: if `$TASK_ARN` or `$ENI_ID` is empty or `None`, stop there and wait — an unquoted empty variable in the last command would silently drop the `--network-interface-ids` filter entirely and return the public IP of some *unrelated*, arbitrary network interface in the account, not an error. Quoting (`"$ENI_ID"`) is what turns that into a clear parameter-validation error instead. The last line, once everything checks out, prints the real public IP. (For prod, swap `jewelry-dev-cluster` for `jewelry-prod-cluster` in all three lines.)
5. Browse to `http://<that-ip>` — the jewelry order page, talking to a real server and a real Postgres database, both unreachable from the internet directly.

---

## Step 7 — Run prod: approval gate on top of everything else

1. Build Now on `jewelry-prod`.
2. Same stages run, including the security scan — then it **stops** at Approval.
3. Click **Deploy**.
4. Repeat the public-IP lookup against `jewelry-prod-cluster` / the `jewelry-prod` services, browse to it.

---

## Wrap-up question for the class
*"The `jenkins-deploy-dev` user's policy includes `ecr:GetAuthorizationToken` with `Resource: "*"`, even though every other statement in that same policy is scoped to specific ARNs. Why?"* (Expected answer: `GetAuthorizationToken` is an AWS API action that doesn't support resource-level permissions at all — it's always account/region-wide, regardless of how the policy is written. This is a real limit on how far least-privilege can go, imposed by the cloud provider's own IAM capabilities, not a mistake in the policy. The *next* statement down, which scopes the actual push actions to the two specific repo ARNs, is where the real restriction lives.)

---

## Cleanup

```bash
cd demo-app/terraform/prod && terraform destroy
cd ../dev && terraform destroy
cd ../shared && terraform destroy
```
Destroy `prod` and `dev` before `shared` — both reference the ECR repos via a `data` source, not by owning them, so order doesn't strictly matter for ECR, but destroying the environments first avoids leaving ECS services pointing at image tags you're about to delete.
