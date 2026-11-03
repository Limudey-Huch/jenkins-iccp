# Exercise 3 — Pipeline as Code, with a Custom Script Path
**Difficulty:** ⭐⭐⭐☆ | **New concept:** Jenkinsfile in Git, non-root **Script Path**

---

## Objective
In the Lesson 01 walkthrough, the Jenkinsfile sat at the repo root and the job used the default Script Path (`Jenkinsfile`). In real repos, the pipeline definition is often tucked into a subfolder (`ci/Jenkinsfile`, `.jenkins/Jenkinsfile`, etc.) alongside other CI config. This exercise makes you configure that explicitly.

## Task
In your `jenkins-pac` repo (or any repo you control):

1. Create a new file at **`ci/Jenkinsfile`** (not at the repo root)
2. It should combine what you learned in Exercises 1 and 2:
   - A `checkout scm` stage
   - A choice parameter `TARGET` with at least 2 values of your choice
   - At least one stage that runs conditionally based on `TARGET`
3. Commit and push it
4. Create a Pipeline job `ex3-custom-script-path` using **Pipeline script from SCM**, pointing at your repo and branch, with **Script Path** set to `ci/Jenkinsfile` (not the default)

Run it with "Build with Parameters" and confirm it correctly checks out the repo and reads the Jenkinsfile from the subfolder.

## Constraints
- Don't put a `Jenkinsfile` at the repo root for this exercise — the whole point is configuring a non-default Script Path.
- If you leave Script Path as the default (`Jenkinsfile`), the job will fail to find your pipeline — that failure is expected if you forget this step; read the error message to confirm it's a "file not found"-type error, then fix the Script Path field.

<details>
<summary>Hint 1 — where is Script Path?</summary>

Job → **Configure** → **Pipeline** section → after choosing "Pipeline script from SCM" and filling in Git details, there's a **Script Path** field below the Branches field. Default is `Jenkinsfile`.
</details>

<details>
<summary>Hint 2 — combining checkout + parameters + when</summary>

```groovy
pipeline {
    agent any
    parameters {
        choice(name: 'TARGET', choices: ['app-a', 'app-b'], description: 'Which component to build')
    }
    stages {
        stage('Checkout') {
            steps { checkout scm }
        }
        stage('Build app-a') {
            when { expression { params.TARGET == 'app-a' } }
            steps { echo 'Building app-a...' }
        }
        stage('Build app-b') {
            when { expression { params.TARGET == 'app-b' } }
            steps { echo 'Building app-b...' }
        }
    }
}
```
</details>

## Done when
- [ ] `ci/Jenkinsfile` exists in your repo (not at the root)
- [ ] The job's Script Path field is explicitly set to `ci/Jenkinsfile`
- [ ] A build with each parameter value runs the correct conditional stage
- [ ] You can explain, in one sentence, what would happen if Script Path were left as the default
