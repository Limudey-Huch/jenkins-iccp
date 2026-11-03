# Lesson 02 — CI/CD with Jenkins: Build, Test, Publish
**Course:** Jenkins | **Institution:** ICCP | **Duration:** ~3 hours

---

## Learning Objectives
By the end of this lesson, students will be able to:
- Structure a Declarative Pipeline into meaningful `stages`
- Implement the three most common CI/CD jobs: **build** (incl. Docker image build), **test** (with JUnit reporting), and **publish** (artifacts + registry push)
- Use `post` blocks to react to success/failure/always conditions
- Understand the VM/agent prerequisites needed to build Docker images inside a pipeline

---

## Prerequisites: Docker on the Jenkins Agent

To build a Docker image from within a pipeline, Docker must be installed on whichever machine actually runs the `sh` steps (the Jenkins controller itself, or an agent node). Two common setups:

1. **Docker installed directly on the VM**, and the `jenkins` user added to the `docker` group:
   ```bash
   sudo usermod -aG docker jenkins
   sudo systemctl restart jenkins
   ```
2. **Docker-in-Docker (DinD) agent**, where the pipeline runs inside a container that itself has access to a Docker daemon (more advanced, common in containerized Jenkins setups).

For this course we use setup #1 — Docker installed on the same Ubuntu VM as Jenkins.

---

## 1. The Common CI/CD Jobs

| Stage | Purpose | Typical tools |
|---|---|---|
| **Build** | Compile code / build a Docker image | `docker build`, `make`, `mvn package`, `npm run build` |
| **Test** | Run automated tests, report results | `pytest`, `jest`, `mvn test` + `junit` step |
| **Publish / Deploy** | Store build output, push image, deploy | `archiveArtifacts`, `docker push`, `kubectl apply` |

---

## 2. A Complete Declarative Pipeline Example

```groovy
pipeline {
    agent any

    environment {
        IMAGE_NAME = "myapp"
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build') {
            steps {
                sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .'
            }
        }

        stage('Test') {
            steps {
                sh 'docker run --rm -v $WORKSPACE:/app -w /app $IMAGE_NAME:$IMAGE_TAG pytest --junitxml=results.xml'
            }
            post {
                always {
                    junit 'results.xml'
                }
            }
        }

        stage('Publish') {
            steps {
                archiveArtifacts artifacts: 'results.xml', fingerprint: true
                sh 'docker tag $IMAGE_NAME:$IMAGE_TAG myregistry.example.com/$IMAGE_NAME:$IMAGE_TAG'
                sh 'docker push myregistry.example.com/$IMAGE_NAME:$IMAGE_TAG'
            }
        }
    }

    post {
        success {
            echo "Build #${env.BUILD_NUMBER} succeeded."
        }
        failure {
            echo "Build #${env.BUILD_NUMBER} failed — check console output."
        }
        always {
            echo "Pipeline finished with status: ${currentBuild.currentResult}"
        }
    }
}
```

---

## 3. Breaking Down the Pieces

### `stages` / `stage`
Each `stage` is a logical phase shown as a distinct box in the Jenkins UI (Stage View), making it easy to see at a glance where a pipeline is spending time or failing.

### Building a Docker image
```groovy
sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .'
```
Tags the image with the Jenkins build number so every build produces a traceable, unique image.

### Running tests + publishing results
```groovy
sh 'docker run --rm -v $WORKSPACE:/app -w /app $IMAGE_NAME:$IMAGE_TAG pytest --junitxml=results.xml'
```
```groovy
post {
    always {
        junit 'results.xml'
    }
}
```
The `-v $WORKSPACE:/app -w /app` mount is required: without it, `results.xml` is written only *inside* the container's filesystem and is lost the moment `--rm` removes the container — the `junit` step would then fail to find the file on the Jenkins workspace. Mounting the workspace into the container means the test report lands back on the host, where `junit` can read it.

The `junit` step parses the JUnit XML report and shows pass/fail/skip counts and trends directly in the Jenkins UI, even if the test stage fails — that's why it's in `post { always { ... } }`.

### Archiving artifacts
```groovy
archiveArtifacts artifacts: 'results.xml', fingerprint: true
```
Saves files from the workspace as part of the build record, downloadable from the build page later.

### Publishing to a registry
```groovy
sh 'docker push myregistry.example.com/$IMAGE_NAME:$IMAGE_TAG'
```
In this lesson we push anonymously/locally for demonstration. **Lesson 03 covers how to do this securely with real registry credentials.**

### `post` conditions
| Block | Runs when |
|---|---|
| `success` | Pipeline (or stage) completed successfully |
| `failure` | Pipeline (or stage) failed |
| `always` | Runs regardless of outcome — cleanup, notifications, reporting |
| `unstable` | Completed but with test failures marked as unstable |

---

## 4. Discussion: Why This Structure Matters

- Splitting into `Build` / `Test` / `Publish` stages gives clear visual feedback on *where* a pipeline fails
- Running `junit` in `post { always }` ensures test reports show up even on failure — critical for debugging
- Tagging images with `BUILD_NUMBER` avoids the classic "latest" ambiguity problem and gives full traceability from a running container back to the exact commit/build that produced it

---

## References
- Declarative Pipeline syntax: https://www.jenkins.io/doc/book/pipeline/syntax/
- `junit` step: https://www.jenkins.io/doc/pipeline/steps/junit/
- `archiveArtifacts`: https://www.jenkins.io/doc/pipeline/steps/core/#archiveartifacts-archive-the-artifacts
- Docker Pipeline plugin: https://www.jenkins.io/doc/book/pipeline/docker/

---

## Instructor Notes
- Confirm Docker is installed and the `jenkins` user is in the `docker` group **before** class — this is the #1 blocker students hit.
- Have a small sample app with 2-3 trivial pytest/jest tests prepared, including one that intentionally fails, to demonstrate the `junit` report and `post` behavior.
- Mention that in Lesson 03 the same `docker push` line will be rewritten to use Jenkins Credentials instead of an open/anonymous registry.
