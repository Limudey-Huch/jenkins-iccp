# Exercise 3 — Build, Test, Publish, From Scratch
**Difficulty:** ⭐⭐⭐☆ | **New concept:** none — this is the first exercise where *you* design the app and the Dockerfile, not just the pipeline

---

## Objective
Lesson 02 handed you a working app (Tic-Tac-Toe) with its logic already split from its UI, its Dockerfile already written, and its Jenkinsfile already structured. This exercise asks you to reproduce that same Build → Test → Publish pattern on an app **you build yourself, from nothing** — proving you understand *why* each piece exists, not just how to copy one that already works.

## Task
In a new folder (new repo, or a new subfolder of an existing one — your choice), write:

1. A tiny Python module with **pure, testable logic** — no I/O, no UI — of your own choosing. Something small is fine: a password-strength checker, a unit converter, a simple string validator, anything with at least 2–3 distinct behaviors worth testing.
2. At least **4 pytest tests** covering normal cases and at least one edge case / invalid-input case.
3. A `Dockerfile` that installs `pytest` and can run the tests inside the container, producing a JUnit XML report (`--junitxml=results.xml`).
4. A `Jenkinsfile` with the full pattern from Lesson 02: **Checkout → Build → Test → Publish**, including:
   - the `-v $WORKSPACE:/app -w /app` volume mount (so `results.xml` survives the container being removed)
   - `junit` in `post { always {...} }`
   - `archiveArtifacts` on the results file

Create the Jenkins job, run it, and confirm the Test Result report shows your tests.

## Constraints
- Don't copy `demo-app`'s `Dockerfile`/`Jenkinsfile` verbatim and just rename things — write them from the pattern, not from the file. If you get stuck on a specific line, that's fine — check the Hints, but try first.
- At least one of your tests must assert on an **error/invalid-input case** (e.g. `pytest.raises(ValueError)`), not just happy-path behavior.

<details>
<summary>Hint 1 — if you're stuck on the app idea</summary>

A "unit converter" is a safe, simple choice:
```python
def celsius_to_fahrenheit(c):
    return c * 9 / 5 + 32

def fahrenheit_to_celsius(f):
    return (f - 32) * 5 / 9

def validate_temperature(value, scale):
    if scale not in ("C", "F"):
        raise ValueError(f"Unknown scale: {scale}")
    return True
```
</details>

<details>
<summary>Hint 2 — the Dockerfile shape</summary>

```dockerfile
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install pytest
CMD ["pytest", "--junitxml=results.xml"]
```
</details>

<details>
<summary>Hint 3 — the Jenkinsfile shape</summary>

```groovy
pipeline {
    agent any
    environment {
        IMAGE_NAME = "myapp"
        IMAGE_TAG  = "${env.BUILD_NUMBER}"
    }
    stages {
        stage('Checkout') { steps { checkout scm } }
        stage('Build') {
            steps { sh 'docker build -t $IMAGE_NAME:$IMAGE_TAG .' }
        }
        stage('Test') {
            steps {
                sh 'docker run --rm -v $WORKSPACE:/app -w /app $IMAGE_NAME:$IMAGE_TAG pytest --junitxml=results.xml'
            }
            post { always { junit 'results.xml' } }
        }
        stage('Publish') {
            steps { archiveArtifacts artifacts: 'results.xml', fingerprint: true }
        }
    }
}
```
</details>

## Done when
- [ ] Your app's logic module has zero UI/network/filesystem dependencies
- [ ] At least 4 tests pass, including at least one that checks invalid input correctly raises
- [ ] The build is green, Test Result shows your test names, and `results.xml` appears under Build Artifacts
- [ ] You can explain, without looking it up, why the `-v $WORKSPACE:/app -w /app` flags are there
