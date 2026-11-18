# Lesson 04 — Multi-Repo Teams & Promoting to Production

## Why this lesson exists
Every previous lesson used **one repo** holding the whole app (`demo-app/`), with the Jenkinsfile and the application code living side by side. That's realistic for a small project — but most real organizations split ownership across teams, and each team owns its own repo:

- A **frontend team** owns the client
- A **backend team** owns the server
- A **DevOps/platform team** owns the infrastructure (Terraform) and the deploy tooling

This lesson simulates exactly that: three separate GitHub repos — [`jewelry-client`](repos/jewelry-client/), [`jewelry-server`](repos/jewelry-server/), [`jewelry-infra`](repos/jewelry-infra/) — reusing the same jewelry-orders app and AWS infrastructure from Lesson 03, just reorganized the way a real org would actually own it.

## The problem with how Lesson 03 did it
Lesson 03's `Jenkinsfile.dev` and `Jenkinsfile.prod` each independently **build and test their own code** from their own branch. That means dev and prod don't necessarily run the *same artifact* — if someone pushes directly to the `prod`-tracked branch, that's a brand new build, tested separately, potentially compiled from a slightly different state of the code than whatever was validated in dev. In a real incident, "it worked in dev" stops meaning anything once prod runs code that was never actually the thing you tested.

## This lesson's model: build once, promote the same artifact
1. The **client** and **server** teams each work on their own `dev` branch, in their own repo. Every push triggers that repo's own Jenkins pipeline: build the image, test it (server only), tag it with the **git commit's short SHA** — not a build number, not an environment name — and deploy it straight to the **dev** environment, automatically, continuously.
2. Tagging by commit SHA means the tag *is* the exact source code — there's no ambiguity about what's running.
3. When the team decides a particular combination of client + server (both already running and validated in dev) is ready to ship, someone runs a **separate, parameterized pipeline** — `jewelry-infra`'s `Jenkinsfile.promote` — passing in the exact two tags to promote.
4. That pipeline does **no building, no testing** — it only takes the images that already exist in ECR (built once, already proven in dev) and re-points the **prod** ECS services at them. Nothing new is compiled; nothing is rebuilt; the bytes running in prod are provably identical to what ran in dev.

This is the real-world practice usually called **"build once, deploy many"** or **promotion-based delivery** — the opposite of rebuilding separately per environment.

## Why three repos, one shared deploy script
`jewelry-client` and `jewelry-server` don't carry their own copy of the ECS deploy logic — their Jenkinsfiles check out `jewelry-infra` as a **second source** inside the same pipeline run, purely to use its `scripts/deploy_service.py`. This mirrors a common real pattern: a shared "platform tooling" repo that application repos pull in, rather than copy-pasting deploy logic into every app repo and letting the copies drift out of sync over time.

## Infrastructure isn't re-provisioned here
`jewelry-infra`'s `terraform/` folder is the **exact same Terraform** already applied in Lesson 03 — this lesson doesn't create new AWS resources. The point of including it in its own repo is organizational: in a real company, this code wouldn't live bundled inside an application's repo at all — it would be owned and version-controlled separately, by the team responsible for it. If you've already run `terraform apply` for Lesson 03's dev and prod stacks, there's nothing new to provision; `jewelry-infra`'s Jenkins job (`promote-to-prod`) only ever calls `deploy_service.py`, never `terraform apply`.

## Credentials reused from Lesson 03
Both the `aws-jewelry-dev-deploy` and `aws-jewelry-prod-deploy` Jenkins credentials, and the `github-pat` credential, are the same ones set up during Lesson 03's Security Scan walkthrough — nothing new to provision there either.

## Making `main` actually mean something: auto-triggering promotion
Everything above still leaves one gap: merging `dev` into `main` doesn't *do* anything by itself — nothing watches `main`. In a real org, a merge into `main` (usually via a reviewed Pull Request) is typically treated as "this is ready to ship," and often **does** automatically kick off the next step toward production — still gated by a human approval before anything actually deploys, but automatically *triggered*.

`Jenkinsfile.main` (in both `jewelry-client` and `jewelry-server`) implements exactly that:
1. It builds nothing.
2. It reads the commit SHA that's now on `main` — which, **if `dev` was merged into `main` with a fast-forward/rebase merge** (not squash, not a merge commit), is the *exact same SHA* that `Jenkinsfile.dev` already built, tested, tagged, and deployed to dev. No new artifact is created.
3. It looks up what the *other* service (server, if this is the client repo) is currently running in dev, via `aws ecs describe-task-definition`.
4. It triggers the shared `promote-to-prod` job (in `jewelry-infra`) with both tags — using Jenkins' `build job: '...', parameters: [...]` step, one pipeline starting another, across repos.

That job still stops at its own `input` Approval step before anything touches production — merging to `main` starts the promotion *conversation*, it doesn't bypass the gate.

**Why the merge strategy matters:** a squash merge or an ordinary merge commit creates a **brand-new commit SHA** on `main` that was never actually built or tagged in ECR — `Jenkinsfile.main` would hand `promote-to-prod` a tag that doesn't exist, and the deploy would fail when ECS tries to pull a non-existent image. Fast-forward (or rebase) merges keep the original commit's SHA intact, which is what makes "build once, promote the same artifact" actually hold true end to end.

See [`walkthrough.md`](walkthrough.md) for the full, in-class, step-by-step version of this.
