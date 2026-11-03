# Walkthrough 02 — Build, Test, Publish
In-class, instructor-led. Build a real pipeline incrementally, stage by stage, running it after every change so students see immediate feedback.

---

## Setup (before class)
- Jenkins + Docker installed on the same VM, `jenkins` user in the `docker` group
- A tiny sample app repo prepared with:
  - A trivial `app.py` (or any language)
  - 2 passing tests + **1 intentionally failing test** (kept disabled until Step 4)
  - A `Dockerfile`

---

## Step 1 — Build stage only

1. Create a Multibranch or SCM Pipeline job pointing at the sample repo.
2. `Jenkinsfile` v1:
   ```groovy
   pipeline {
       agent any
       stages {
           stage('Checkout') {
               steps { checkout scm }
           }
           stage('Build') {
               steps {
                   sh 'docker build -t myapp:$BUILD_NUMBER .'
               }
           }
       }
   }
   ```
3. Run it → show the Stage View with one green box → `docker images` on the VM to show the tagged image exists.

> **Explain:** why tag with `$BUILD_NUMBER` instead of `latest`? Ask the class what breaks if every build overwrites `latest`.

---

## Step 2 — Add the Test stage

1. Extend the `Jenkinsfile`:
   ```groovy
   stage('Test') {
       steps {
           sh 'docker run --rm -v $WORKSPACE:/app -w /app myapp:$BUILD_NUMBER pytest --junitxml=results.xml'
       }
       post {
           always {
               junit 'results.xml'
           }
       }
   }
   ```
2. Run it → open the build page → show the **Test Result** link and trend graph.

> **Explain the `post { always }` placement:** ask *"what happens to this report if a test fails?"* — then prove it in the next step.

---

## Step 3 — Watch a failure happen correctly

1. Enable the intentionally-failing test in the sample repo, push.
2. Run the pipeline again → the **Test** stage goes red, the whole pipeline is marked failed.
3. Click into **Test Result** anyway → show the report is still there, clearly marking which test failed.

> **Explain the difference:** without `post { always }`, a failing test stage would skip the `junit` step entirely and the team would lose visibility into *which* test broke. This is the single most common mistake in real pipelines.

3. Disable the failing test again, push, rerun to get back to green before continuing.

---

## Step 4 — Add the Publish stage

1. Extend the `Jenkinsfile`:
   ```groovy
   stage('Publish') {
       steps {
           archiveArtifacts artifacts: 'results.xml', fingerprint: true
           sh 'docker tag myapp:$BUILD_NUMBER myregistry.example.com/myapp:$BUILD_NUMBER'
           sh 'docker push myregistry.example.com/myapp:$BUILD_NUMBER'
       }
   }
   ```
   (If no real registry is reachable in the classroom, swap the push for a local registry container, or skip the push line and just show `archiveArtifacts`.)
2. Run it → open the build page → download the archived `results.xml` from the UI to prove it's retrievable later.

> **Explain the difference: artifact vs. image.** `archiveArtifacts` stores a file *inside Jenkins' own build record* (tied to that build number forever). A Docker image push sends the image to an *external* registry, independent of Jenkins. Ask the class which one you'd use for a compiled `.jar` vs. a deployable container.

---

## Step 5 — Full pipeline + post block

1. Add the top-level `post` block:
   ```groovy
   post {
       success { echo "Build #${env.BUILD_NUMBER} succeeded." }
       failure { echo "Build #${env.BUILD_NUMBER} failed — check console output." }
       always  { echo "Pipeline finished with status: ${currentBuild.currentResult}" }
   }
   ```
2. Run once green, then re-enable the failing test and run once red — show both messages appearing in the console log.

> **Explain the four `post` conditions** (`success`, `failure`, `always`, `unstable`) and ask the class where they'd plug in a Slack notification (hint: `failure`, so people aren't spammed on every green build).

---

## Wrap-up question for the class
*"If the Test stage and the Publish stage were reversed in order, what would go wrong?"* (Expected answer: you'd publish a broken image before knowing the tests failed.)
