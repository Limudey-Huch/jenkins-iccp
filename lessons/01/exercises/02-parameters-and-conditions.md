# Exercise 2 — Parameters & Conditional Stages
**Difficulty:** ⭐⭐☆☆ | **New concept:** build parameters, conditional stage execution with `when`

---

## Objective
Pipelines aren't just linear scripts — they can take input at build time and change behavior based on it. This is the first step toward pipelines that behave differently per environment (dev/staging/prod) without duplicating code.

## Task
Create a new Pipeline job `ex2-parameterized-pipeline` (still UI script, not SCM yet) that:

1. Declares a **choice parameter** named `ENVIRONMENT` with values `dev`, `staging`, `prod`
2. Has a stage called **"Deploy"** that only runs **when `ENVIRONMENT` is `prod`**, and echoes something like `Deploying to PRODUCTION — this is irreversible!`
3. Has a stage called **"Build"** that always runs, regardless of the parameter

Run the job twice: once with `ENVIRONMENT=dev` (the Deploy stage should be **skipped**, shown greyed out in Stage View) and once with `ENVIRONMENT=prod` (Deploy stage should **run**).

## Constraints
- Use the `parameters {}` block at the top of the pipeline, not a `properties()` step.
- Use `when { expression { ... } }` or `when { equals ... }` — look up the Pipeline syntax docs (**Pipeline Syntax** link in the job's sidebar) if you're not sure of the exact form.

<details>
<summary>Hint 1 — declaring the parameter</summary>

```groovy
pipeline {
    agent any
    parameters {
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target environment')
    }
    stages {
        ...
    }
}
```
</details>

<details>
<summary>Hint 2 — conditional stage</summary>

```groovy
stage('Deploy') {
    when {
        expression { params.ENVIRONMENT == 'prod' }
    }
    steps {
        echo 'Deploying to PRODUCTION — this is irreversible!'
    }
}
```
</details>

<details>
<summary>Hint 3 — where did the parameter go?</summary>

Once a job has a `parameters {}` block and you build it once, Jenkins stops showing a plain "Build Now" button and switches to **"Build with Parameters"** — look for that link instead.
</details>

## Done when
- [ ] Job has a choice parameter `ENVIRONMENT` with 3 values
- [ ] A build with `ENVIRONMENT=dev` shows the Deploy stage **skipped**
- [ ] A build with `ENVIRONMENT=prod` shows the Deploy stage **executed**, with the echo visible in Console Output
