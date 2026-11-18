# Walkthrough 04 — Multi-Repo Teams & Promoting to Production
In-class, instructor-led. Requires Lesson 03's Security Scan walkthrough to already be done — this lesson reuses its AWS infrastructure (`jewelry-dev-cluster`, `jewelry-prod-cluster`, the two ECR repos) and its two Jenkins credentials (`aws-jewelry-dev-deploy`, `aws-jewelry-prod-deploy`). Nothing new is provisioned in AWS here.

---

## Setup — create three GitHub repos

Create three **new**, empty GitHub repos: `jewelry-client`, `jewelry-server`, `jewelry-infra`. Push each folder from [`repos/`](repos/) as that repo's root:

```bash
cd <path-to-jenkins-iccp>/lessons/04/repos/jewelry-client
git init && git add . && git commit -m "Initial commit"
git branch -M main
git checkout -b dev
git remote add origin https://github.com/<your-org>/jewelry-client.git
git push -u origin main
git push -u origin dev
```
Repeat for `jewelry-server` and `jewelry-infra` (for `jewelry-infra`, only `main` is needed — the promotion pipeline doesn't use a `dev` branch).

**Before pushing**, open each repo's Jenkinsfile and replace `https://github.com/<your-org>/jewelry-infra.git` (in `jewelry-client/Jenkinsfile.dev` and `jewelry-server/Jenkinsfile.dev`) with your actual `jewelry-infra` repo URL.

**If you already ran `terraform apply` for Lesson 03's `dev`/`prod` stacks before this lesson's IAM update:** re-apply both, since the deploy users now also need `ecs:DescribeTaskDefinition` for Step 4 below.
```bash
cd <path-to-jenkins-iccp>/lessons/03/demo-app/terraform/dev && terraform apply
cd ../prod && terraform apply
```

---

## Step 1 — Create the two "dev" Jenkins jobs

**`client-dev`**
1. New Item → Pipeline → Pipeline script from SCM → Git → your `jewelry-client` repo URL + `github-pat` credential
2. **Branch Specifier**: `*/dev`
3. **Script Path**: `Jenkinsfile.dev`

**`server-dev`**
Same, pointing at `jewelry-server`, branch `*/dev`, Script Path `Jenkinsfile.dev`.

> **Explain:** notice both jobs build from each repo's `dev` branch, not `main` — `main` in each app repo represents "what's been promoted," while `dev` is where day-to-day feature work happens. This lesson doesn't wire up a pipeline on `main` at all; promotion happens through `jewelry-infra`'s pipeline instead, in Step 3.

---

## Step 2 — Simulate each team shipping a change to dev

1. In `jewelry-client`, on the `dev` branch, make a small visible change — e.g. edit the `<h1>` text in `index.html` — commit, push.
2. `client-dev` should build automatically if you've set up a trigger (Poll SCM, from Walkthrough 02.5), or click Build Now.
3. Open the build's Console Output and find the line `Deployed client tag <short-sha> to dev` — **write that tag down**.
4. In `jewelry-server`, on `dev`, make a small change to `orders_logic.py` (e.g. add a new catalog item) — commit, push, build `server-dev`, and again record the printed tag.
5. Browse to the dev client's current public IP (same `aws ecs list-tasks` / `describe-tasks` / `describe-network-interfaces` chain from Lesson 03) — confirm both changes are live in dev.

> **Explain:** this is two independent teams, working at their own pace, on their own repos, each deploying to dev the moment their own pipeline is green — no coordination needed between them yet. That's deliberate: fast, independent iteration in dev is exactly what you want. The coordination only happens at the *next* step, when someone decides to ship.

---

## Step 3 — Promote both tags to production, together

1. New Item → Pipeline → Pipeline script from SCM → Git → your `jewelry-infra` repo URL + `github-pat`, Branch `*/main`, **Script Path**: `Jenkinsfile.promote` → name the job `promote-to-prod`.
2. Build with Parameters → paste in the exact `CLIENT_TAG` and `SERVER_TAG` you recorded in Step 2.
3. Watch it run: Checkout → Resolve Image URIs → **Approval** (stops here) → click Deploy → Deploy to Prod.
4. Browse to the prod client's current public IP (same lookup, against `jewelry-prod-cluster`) — confirm **both** changes are now live in prod.

> **Explain:** no `docker build` stage ran in this pipeline at all — open the Console Output and point that out explicitly. Everything deployed to prod here was already built, already tested, and was already running in dev before this pipeline even started. Ask the class: what would happen if you typed in a `CLIENT_TAG` that was never actually pushed to ECR? (Answer: the `Deploy to Prod` stage would fail at `describe-task-definition`/`register-task-definition` with an image-not-found-style error from ECS when it tries to actually pull it — not silently deploy nothing.)

---

---

## Step 4 — Make `main` trigger promotion automatically

1. Create `client-main` (Pipeline script from SCM → `jewelry-client` → Branch Specifier `*/main` → Script Path `Jenkinsfile.main`) and `server-main` (same, in `jewelry-server`).
2. On `jewelry-client`, merge `dev` into `main` **as a fast-forward**, preserving the commit SHA:
   ```bash
   git checkout main
   git merge --ff-only dev
   git push origin main
   ```
   (If `--ff-only` refuses — "not possible to fast-forward" — it means `main` has diverged; that's a sign something was committed directly to `main` outside this flow. Reset the demo by making `main` match `dev` exactly, `git reset --hard dev`, only because this is a lab, not a real repo.)
3. Build `client-main` (or let a push trigger configured earlier fire it). Watch it: Checkout → Find Current Dev Server Tag → **Trigger Promotion**.
4. Open `promote-to-prod` — a new build should already be running there, started *by* `client-main`, paused at its own Approval step. Click Deploy there.
5. Confirm prod now runs this client commit, paired with whatever server tag was already live in dev.

> **Explain:** `build job: 'promote-to-prod', parameters: [...]` is Jenkins' mechanism for one pipeline to start another and pass data to it — this is exactly how real orgs wire "repo A's event" to "repo B's (or a shared repo's) pipeline" without the two repos needing to share a single Jenkinsfile. Ask the class: why does `client-main` look up the server's tag with a live `aws ecs describe-task-definition` call instead of, say, hardcoding it or asking a human to type it in? (Answer: it's the one tag nobody has to remember or communicate — "whatever's already safely running in dev" is always discoverable automatically, and it's correct by definition.)

---

## Wrap-up question for the class
*"The client and server teams deployed to dev independently, at different times, on different days even. What stops them from promoting two versions to prod that were never actually tested running together?"* (Expected answer: nothing in this specific lab does — this is a real, known limitation of per-service independent deployment. In practice, teams solve this with integration/contract tests run against the actual dev environment before promoting — e.g., API contract tests, or simply "smoke test the combination in dev immediately before you promote it" — not by rebuilding, but by testing the *already-deployed* combination before locking in those two tags for the promotion.)
