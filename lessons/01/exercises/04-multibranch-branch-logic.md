# Exercise 4 — Multibranch Pipeline with Branch-Specific Logic
**Difficulty:** ⭐⭐⭐⭐ | **New concept:** Multibranch Pipeline + behavior that changes based on **which branch** is building

---

## Objective
This is the capstone of Lesson 01: combine Pipeline as Code, parameters/conditionals, and Multibranch into one realistic setup — a pipeline that behaves differently on `main` than it does on a feature branch, entirely automatically, with no manual job creation per branch.

## Task
Back at the **repo root** this time (Multibranch Pipeline always uses the default `Jenkinsfile` path per branch, so put it back there):

1. Write a `Jenkinsfile` with:
   - A `Checkout` stage
   - A `Build` stage that **always** runs, on every branch
   - A `Deploy` stage that runs **only on `main`** (use `when { branch 'main' }`, Declarative Pipeline's built-in branch condition — simpler than the `params` approach from Exercise 2)
   - A `Lint / Extra Checks` stage that runs **only on branches starting with `feature/`** (use `when { branch pattern: "feature/.*", comparator: "REGEXP" }`)
2. Commit this to `main` and push
3. Create (or reuse) a **Multibranch Pipeline** job pointing at the repo
4. Create a new branch `feature/ex4-test`, push it with the same Jenkinsfile unchanged
5. Let Jenkins scan and build both branches

## Expected result
- The `main` sub-job's build: **Build** + **Deploy** stages run, **Lint / Extra Checks** is skipped
- The `feature/ex4-test` sub-job's build: **Build** + **Lint / Extra Checks** stages run, **Deploy** is skipped

## Constraints
- Both branches must use the **exact same Jenkinsfile content** — the different behavior must come entirely from the `when { branch ... }` conditions reading `env.BRANCH_NAME`, not from different file contents per branch.
- Don't manually create a job for the feature branch — if Jenkins doesn't pick it up automatically after a scan, that's a bug in your setup to debug, not something to work around manually.

<details>
<summary>Hint 1 — full Jenkinsfile skeleton</summary>

```groovy
pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Build') {
            steps { echo "Building branch ${env.BRANCH_NAME}" }
        }
        stage('Deploy') {
            when { branch 'main' }
            steps { echo 'Deploying from main...' }
        }
        stage('Lint / Extra Checks') {
            when { branch pattern: "feature/.*", comparator: "REGEXP" }
            steps { echo 'Running extra checks on feature branch...' }
        }
    }
}
```
</details>

<details>
<summary>Hint 2 — branch not showing up?</summary>

Multibranch jobs don't poll instantly. Use **Scan Multibranch Pipeline Now** in the job's sidebar to force an immediate scan after pushing a new branch, rather than waiting for the periodic scan interval.
</details>

<details>
<summary>Hint 3 — `env.BRANCH_NAME`</summary>

This variable is only populated automatically in Multibranch Pipeline jobs (and `checkout scm` based SCM jobs with a defined branch) — it's how the Jenkinsfile running on `feature/ex4-test` "knows" its own branch name without you passing anything explicitly.
</details>

## Done when
- [ ] Same Jenkinsfile content exists on both `main` and `feature/ex4-test`
- [ ] `main`'s build ran Deploy but not Lint
- [ ] `feature/ex4-test`'s build ran Lint but not Deploy
- [ ] You can explain why this scales better than Exercise 2's parameter-based approach when you have many feature branches
