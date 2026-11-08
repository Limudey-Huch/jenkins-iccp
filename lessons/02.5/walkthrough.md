# Walkthrough 02.5 — Two Environments, One Multibranch Pipeline
In-class, instructor-led. Optional extension — do this after the main Lesson 02 walkthrough (Build/Test/Publish) is done and working. Kept in its own `02.5` folder on purpose, so it doesn't touch anything already built and demoed in Lesson 02 (the `main` branch and the `demo-app-pipeline` job stay exactly as they are).

## The idea
Real teams don't deploy every commit straight to production. A common pattern: a **dev** environment that updates automatically on every push (fast feedback), and a **prod** environment that only deploys when a human deliberately approves it.

We split this by **branch** — `dev` and `prod`, each with its own `Jenkinsfile` at the root — and manage both with **a single Multibranch Pipeline job**, the same job type from Lesson 01's `demo-multibranch`. One job, one scan, both environments discovered and built automatically.

This is a nice full-circle moment: Lesson 01's Multibranch demo had **one shared Jenkinsfile** that behaved differently per branch via `when { branch ... }` (Exercise 4). Here it's the opposite — each branch carries its **own, completely different** Jenkinsfile — and Multibranch handles both patterns exactly the same way: it just builds whatever `Jenkinsfile` it finds on each branch.

---

## Important: run the git steps from wherever you actually have GitHub push access

This folder (`lessons/02.5/demo-app/`) holds just the two template files — `Jenkinsfile.dev` and `Jenkinsfile.prod`. Copy their contents in when you create each branch, from your real `demo-app` working copy (the one connected to `github-pat` / the `jenkins-pac` remote — wherever `git push origin main` has been working for you so far). Replace `<path-to-jenkins-iccp>` below with wherever you placed this course folder on your machine.

---

## Step 1 — Create the `dev` branch

```bash
cd <path-to-jenkins-iccp>/lessons/02/demo-app
git checkout main
git pull origin main
git checkout -b dev
cp <path-to-jenkins-iccp>/lessons/02.5/demo-app/Jenkinsfile.dev ./Jenkinsfile
git add Jenkinsfile
git commit -m "Dev environment pipeline: auto-deploy, port 5001"
git push origin dev
```

Everything else (`game_logic.py`, `web_app.py`, `Dockerfile`, etc.) comes along automatically from `main` — only `Jenkinsfile` is different on this branch.

## Step 2 — Create the `prod` branch

```bash
git checkout main
git checkout -b prod
cp <path-to-jenkins-iccp>/lessons/02.5/demo-app/Jenkinsfile.prod ./Jenkinsfile
git add Jenkinsfile
git commit -m "Prod environment pipeline: manual approval gate, port 5000"
git push origin prod
git checkout main
```

The last command leaves your working copy exactly where Lesson 02 left it.

---

## Step 3 — Look at what's different between the two Jenkinsfiles

Open `Jenkinsfile.dev` and `Jenkinsfile.prod` (in `lessons/02.5/demo-app/`) side by side:

| | `Jenkinsfile.dev` | `Jenkinsfile.prod` |
|---|---|---|
| Image/container name | `myapp-dev` / `tictactoe-dev` | `myapp-prod` / `tictactoe-prod` |
| Host port | `5001` | `5000` |
| Before deploy | straight to `Deploy to Dev` | an `Approval` stage (`input` step) blocks until a human clicks **Deploy** |
| Trigger | none declared | none declared |

> **Explain:** notice *neither* file has a `triggers {}` block. Under a Multibranch job, you don't declare per-branch polling — the job itself scans **all** its branches on one shared schedule and builds whichever ones changed. The only real difference between dev and prod here is what's *inside* the pipeline (the `Approval` gate), not how often Jenkins checks for changes. Ask the class: does an automatic scan of the `prod` branch feel risky? (Answer: no — the scan only *starts* the build; the `input` step still stops it before anything deploys. Automatic discovery and automatic *deployment* are two different things.)

---

## Step 4 — Create one Multibranch Pipeline job for both

1. Dashboard → **New Item** → name `demo-app-envs` → **Multibranch Pipeline** → OK
2. **Branch Sources** → **Add source** → **Git** → same repository URL as `demo-app-pipeline` → credential `github-pat` → Save
3. Jenkins scans the repo and creates a sub-job per branch that has a `Jenkinsfile` at its root — you should see **`main`**, **`dev`**, and **`prod`** all appear.

> **Explain:** `main` gets picked up too, since it also has a root `Jenkinsfile` (the Lesson 02 one, no deploy stage). That's fine — it's a separate, independent sub-job from `demo-app-pipeline`, just reading the same file. It shows that Multibranch doesn't care *which* branches "belong" to it; it discovers anything with a Jenkinsfile and builds it with whatever that branch's file says.

4. **Scan Multibranch Pipeline Triggers**: in the job's Configure page, make sure **"Periodically if not otherwise run"** is checked with a short interval (e.g. 1–2 minutes), so new commits on `dev`/`prod` get picked up without you clicking Scan Now every time.

---

## Step 5 — Watch `dev` build and deploy automatically

1. Inside `demo-app-envs`, click into the **`dev`** sub-job → **Build Now** once (first run always needs a manual kick).
2. It runs Checkout → Build → Test → **Deploy to Dev** straight through, no stop.
3. Browse to `http://<VM_IP>:5001` — the game is running.
4. Now make a trivial change on the `dev` branch (e.g. edit the page title in `web_app.py`), commit, push to `dev` — wait for the next scan (or click **Scan Multibranch Pipeline Now** on the parent job to force it) — `dev`'s sub-job should rebuild and redeploy on its own.

---

## Step 6 — Watch `prod` build and stop for approval

1. Inside `demo-app-envs`, click into the **`prod`** sub-job → **Build Now**.
2. It runs Checkout → Build → Test — then **stops** at the `Approval` stage, showing "Paused for Input" with a **Deploy** button right there in the build view.
3. Click **Deploy**.
4. The `Deploy to Prod` stage runs. Browse to `http://<VM_IP>:5000` — the prod container, now running.

> **Explain:** `input` pauses execution and waits for a human click (or an API call) before continuing — the real mechanism production pipelines use for manual approval gates, regardless of what started the build (a manual click here, or an automatic scan on `dev`).

---

## Step 7 — See both running side by side

```bash
docker ps --filter "name=tictactoe"
```
Both `tictactoe-dev` (port 5001) and `tictactoe-prod` (port 5000) run simultaneously on the same VM, built from two different branches, managed by **one** Multibranch job — one automatic end-to-end, one gated behind a human click.

---

## Wrap-up question for the class
*"If you fix a bug in `game_logic.py`, what do you actually have to do to get that fix running in both dev and prod?"* (Expected answer: since the app code is shared via Git history but each environment lives on its own branch, you fix it on one branch — say `main` or `dev` — then **merge or cherry-pick that commit into the other branch(es)** too. A fix doesn't automatically apply everywhere just by committing once — that's the real cost of the per-branch pattern, worth weighing against the isolation it buys you.)
