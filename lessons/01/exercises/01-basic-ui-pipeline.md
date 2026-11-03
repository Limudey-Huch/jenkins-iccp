# Exercise 1 — Basic UI Pipeline
**Difficulty:** ⭐☆☆☆ | **New concept:** multi-stage Declarative Pipeline, written directly in the UI

---

## Objective
Get comfortable with the basic shape of a Declarative Pipeline — `agent`, `stages`, `stage`, `steps` — without worrying about Git yet.

## Task
Create a new **Pipeline** job called `ex1-basic-pipeline`, with a **Pipeline script** (not from SCM) that has **at least 3 stages**:

1. A stage that prints the hostname of the machine the build ran on
2. A stage that prints the current date and time
3. A stage that prints the currently logged-in OS user running the build

Run the job and confirm all 3 stages show up as separate boxes in the Stage View, and that the Console Output shows the expected values for your VM.

## Constraints
- Don't just copy the Lesson 01 walkthrough's script verbatim — use **different shell commands** than `uname -a` / `date` (for example: `hostname`, `whoami`, `id`).
- All 3 stages must be named differently and reflect what they actually do.

<details>
<summary>Hint 1 — pipeline skeleton</summary>

```groovy
pipeline {
    agent any
    stages {
        stage('...') {
            steps {
                sh '...'
            }
        }
        // two more stages
    }
}
```
</details>

<details>
<summary>Hint 2 — useful shell commands</summary>

`hostname`, `whoami`, `date`, `id`, `pwd` all work as plain `sh` steps, e.g. `sh 'hostname'`.
</details>

## Done when
- [ ] Job `ex1-basic-pipeline` exists and is a **Pipeline** job (not Freestyle)
- [ ] It has 3+ stages, each doing something different
- [ ] A build is green and the Console Output shows real output from each stage
