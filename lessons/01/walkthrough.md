# Walkthrough 01 — UI Pipeline vs. Pipeline as Code
In-class, instructor-led. Go through each step live, run it in front of the class, and pause at every **"Explain:"** box to talk through the concept before moving on.

---

## Setup (before class)
- Jenkins running (`./install_jenkins.sh install`)
- A sample Git repo (GitHub/GitLab) the students can see, initially **without** a Jenkinsfile

---

## Step 1 — Create a Pipeline job via the UI

1. Dashboard → **New Item** → name it `demo-ui-pipeline` → type **Pipeline** → OK
2. Scroll to **Pipeline** section → Definition: **Pipeline script**
3. Paste:
   ```groovy
   pipeline {
       agent any
       stages {
           stage('Hello') {
               steps {
                   echo 'Hello from a UI-defined pipeline!'
               }
           }
       }
   }
   ```
4. Save → **Build Now** → open Console Output

> **Explain:** Where is this script actually stored? (Answer: inside Jenkins' own `config.xml` for this job — not in Git, not visible to anyone browsing the repo.)

---

## Step 2 — Change the pipeline and lose history

1. Go back to **Configure**, add a second stage, save, build again.
2. Ask the class: *"Can anyone tell me what the pipeline looked like yesterday, or who made this change?"*

> **Explain the gap:** no diff, no blame, no PR review, no rollback — this is the core weakness of UI-defined pipelines.

---

## Step 3 — Add a Jenkinsfile to the repo (Pipeline as Code)

1. In the sample repo, create `Jenkinsfile` at the root:
   ```groovy
   pipeline {
       agent any
       stages {
           stage('Checkout') {
               steps { checkout scm }
           }
           stage('Hello') {
               steps { echo 'Hello from a Jenkinsfile stored in Git!' }
           }
       }
   }
   ```
2. Commit and push.
3. Dashboard → **New Item** → name it `demo-scm-pipeline` → type **Pipeline**
4. Pipeline section → Definition: **Pipeline script from SCM** → SCM: Git → paste repo URL → branch `main` → script path `Jenkinsfile`
5. Save → **Build Now**

> **Explain:** Jenkins just checked out the repo and read the pipeline definition *from the commit it checked out*. The pipeline is now versioned exactly like application code.

---

## Step 4 — Show reproducibility

1. Make a small change to the `Jenkinsfile` (e.g., add an `echo` line), commit, push.
2. Build the job again → show the new behavior.
3. `git log --oneline Jenkinsfile` in the repo → show the change is in history with a commit message and author.

> **Explain the difference vs. Step 2:** every pipeline change now has a commit, an author, and (in a real team) a PR review — directly answering the question from Step 2.

---

## Step 5 — Multibranch Pipeline

1. Create a new branch in the repo (`feature/test-branch`), tweak the `Jenkinsfile` slightly, push.
2. Dashboard → **New Item** → name it `demo-multibranch` → type **Multibranch Pipeline**
3. Branch Sources → Git → repo URL → Save
4. Watch Jenkins scan the repo and auto-create a sub-job for **each branch** that has a `Jenkinsfile`.
5. Delete the `feature/test-branch` branch in the repo → re-scan → show Jenkins automatically removes the corresponding job.

> **Explain:** this is how real teams avoid manually creating a Jenkins job per feature branch — Jenkins mirrors the repo's branch structure automatically.

---

## Step 6 — Class discussion: the comparison table

Put the comparison table from `lesson.md` on screen and ask the class, for each row, *"which approach wins, and why?"* before revealing the answer.

| Aspect | UI Pipeline Script | Jenkinsfile in SCM |
|---|---|---|
| Version control | ❌ | ✅ |
| Code review | ❌ | ✅ |
| Reproducibility | ❌ | ✅ |
| Setup speed | ✅ (fastest) | slightly slower |
| Multibranch support | ❌ | ✅ |

---

## Wrap-up question for the class
*"If I asked you to set up CI for a brand-new side project you're hacking on alone tonight, which approach would you use — and why might that answer change once a second developer joins?"*
