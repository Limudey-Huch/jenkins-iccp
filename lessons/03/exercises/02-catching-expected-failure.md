# Exercise 2 — Catching an Expected Failure
**Difficulty:** ⭐⭐☆☆ | **New concept:** `script { try/catch }` — handling a failure *on purpose*, without failing the whole build

---

## Objective
You've already seen `aws s3 ls` fail with `AccessDenied` when using the scoped `jenkins-s3-demo` credential — that's least privilege working correctly, not a bug. This exercise asks: what if you *want* to demonstrate that failure as part of a pipeline, without the whole build turning red over an error you expected and intended?

## Task
Extend (or copy) `ex1-aws-credentials-basics` into a new job `ex2-catching-expected-failure` that adds a stage:

1. Inside `withCredentials` (same `aws-s3-demo-creds`), attempt `aws s3 ls` (list all buckets — forbidden by this credential's policy)
2. Wrap the attempt in a Groovy `try`/`catch` inside a `script {}` block
3. On failure, `echo` a clear message like `"Expected AccessDenied — least privilege confirmed"` instead of letting the stage fail
4. The overall pipeline should finish **green**, even though the AWS call inside it genuinely failed

## Constraints
- Don't just swallow *any* exception silently — the `catch` block must actually print something explaining what happened and why it was expected.
- The stage should still be **visibly distinguishable** in Stage View from a normal successful stage — add an `echo` in both the success and failure paths so the Console Output makes it obvious which branch ran.

<details>
<summary>Hint 1 — the try/catch pattern</summary>

```groovy
stage('Prove Least Privilege') {
    steps {
        withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws-s3-demo-creds']]) {
            script {
                try {
                    sh 'aws s3 ls'
                    echo 'Unexpected: the list succeeded — the policy may be too permissive!'
                } catch (Exception e) {
                    echo 'Expected AccessDenied — least privilege confirmed.'
                }
            }
        }
    }
}
```
</details>

<details>
<summary>Hint 2 — why `script {}`?</summary>

Declarative Pipeline's `steps {}` block only allows a fixed set of steps directly — plain Groovy control flow like `try`/`catch` isn't one of them. `script {}` is the escape hatch that lets you drop into full Scripted Pipeline syntax for just the parts that need it.
</details>

## Done when
- [ ] The job is green overall
- [ ] The Console Output clearly shows the `aws s3 ls` command failing with `AccessDenied`
- [ ] Immediately after, the console shows your own "expected failure" message, not a raw stack trace as the last thing printed
- [ ] You can explain, in one sentence, why this pattern is dangerous if used carelessly (hint: a `try/catch` that swallows *every* exception can hide a real, unexpected bug just as easily as an expected one)
