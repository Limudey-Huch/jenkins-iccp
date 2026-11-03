# Lesson 01 — Working with Jenkins: UI Pipelines vs. Pipeline as Code
**Course:** Jenkins | **Institution:** ICCP | **Duration:** ~3 hours

---

## Learning Objectives
By the end of this lesson, students will be able to:
- Navigate the Jenkins UI and understand its core concepts (Jobs, Builds, Workspace, Executors)
- Create a Pipeline job directly in the UI by pasting Pipeline script
- Understand Pipeline as Code (Jenkinsfile) and why it's the recommended approach
- Set up a Multibranch Pipeline that automatically picks up a Jenkinsfile from SCM
- Compare both approaches and decide when to use each

---

## 1. Jenkins UI Fundamentals

### Key Concepts
- **Job / Project** — a configured unit of work in Jenkins (Freestyle, Pipeline, Multibranch Pipeline, etc.)
- **Build** — a single execution of a job, with its own number, console log, and status
- **Workspace** — the directory on the agent where a build's files live during execution
- **Executor** — a slot on a node (controller or agent) that can run one build at a time
- **Node/Agent** — a machine (or container) that runs builds; the controller itself can also run builds

### Tour of the UI
- Dashboard → list of jobs
- New Item → create a job (choose "Pipeline" type)
- Job page → Build Now, Build History, Console Output, Configure
- Manage Jenkins → Plugins, Credentials, System Configuration, Nodes

**Demo:** open Jenkins at `http://<vm-ip>:8080`, walk through New Item → Pipeline, and the job configuration page.

---

## 2. Approach A — Pipeline Script via the UI

Create a new **Pipeline** job, and in the "Pipeline" section choose **Pipeline script**, pasting a Declarative Pipeline directly into the text box (no SCM, no file).

```groovy
pipeline {
    agent any

    stages {
        stage('Hello') {
            steps {
                echo 'Hello from a UI-defined pipeline!'
            }
        }
        stage('Build Info') {
            steps {
                sh 'uname -a'
                sh 'date'
            }
        }
    }
}
```

**Characteristics:**
- Fast to set up, good for demos and quick experiments
- The pipeline definition is stored only inside Jenkins' own config (`config.xml`), not in a repo
- Not version-controlled — no history, no code review, no diffing across changes
- A single person editing it in the UI can silently break the pipeline for everyone

---

## 3. Approach B — Pipeline as Code (Jenkinsfile in SCM)

Instead of pasting the script into the UI, the same Declarative Pipeline lives in a file named `Jenkinsfile` at the root of the project's Git repository. The Jenkins job is configured with **Pipeline script from SCM**, pointing at the repo and branch.

```groovy
// Jenkinsfile
pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        stage('Hello') {
            steps {
                echo 'Hello from a Jenkinsfile stored in Git!'
            }
        }
        stage('Build Info') {
            steps {
                sh 'uname -a'
                sh 'date'
            }
        }
    }
}
```

**Characteristics:**
- Versioned alongside the application code — full history, diffs, pull request review
- Reproducible: checking out an old commit gives you the exact pipeline that ran at that time
- Enables **Multibranch Pipeline**: Jenkins scans the repo and auto-creates a job per branch/PR that contains a `Jenkinsfile`

### Multibranch Pipeline (concept)
- Job type: **Multibranch Pipeline**
- Jenkins periodically scans the repository (or is triggered via webhook)
- For every branch (or PR) containing a `Jenkinsfile`, Jenkins automatically creates/updates a sub-job
- Deleting a branch automatically removes its Jenkins job
- This is the standard pattern for real-world CI: no manual job creation per feature branch

---

## 4. Comparing the Two Approaches

| Aspect | Pipeline Script (UI) | Pipeline as Code (Jenkinsfile in SCM) |
|---|---|---|
| Version control | ❌ No (lives in Jenkins config) | ✅ Yes (lives in Git) |
| Code review | ❌ No | ✅ Yes (via PR) |
| Reproducibility | ❌ Tied to current Jenkins state | ✅ Tied to a specific commit |
| Setup speed | ✅ Fastest, good for demos | Slightly more setup (needs a repo) |
| Multibranch support | ❌ No | ✅ Yes |
| Recommended for | Quick tests, learning, prototyping | Real projects, teams, production CI/CD |

**Takeaway:** Pipeline Script via the UI is a great way to learn Pipeline syntax quickly, but Pipeline as Code (Jenkinsfile + Multibranch Pipeline) is the production standard — it treats your CI/CD definition as code, with the same rigor as the application itself.

---

## References
- Jenkins Pipeline syntax: https://www.jenkins.io/doc/book/pipeline/syntax/
- Pipeline as Code: https://www.jenkins.io/doc/book/pipeline/getting-started/#defining-a-pipeline-in-scm
- Multibranch Pipeline: https://www.jenkins.io/doc/book/pipeline/multibranch/

---

## Instructor Notes
- Use `install_jenkins.sh install` on a fresh Ubuntu VM before class to have a clean Jenkins instance ready.
- Have a sample GitHub (or GitLab) repo prepared in advance with a `Jenkinsfile` at the root, so students don't lose class time writing one from scratch.
- Good moment to introduce the "Blue Ocean" or classic console output view to show build logs live.
