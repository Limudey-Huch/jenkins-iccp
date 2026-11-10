#!/usr/bin/env python3
"""
Deploys a new image to a running ECS Fargate service, without touching
Terraform:
  1. Reads whatever task definition the SERVICE is actually running right now
  2. Replaces just the image for the named container
  3. Registers a new task definition revision from that
  4. Updates the service to use it

Terraform owns the *shape* of the infrastructure (created once, manually, by
the instructor/student). This script is what the Jenkins pipeline actually
calls on every build to ship a new image — the two are deliberately separate,
so the narrow jenkins-deploy-<env> IAM user only ever needs
ecs:RegisterTaskDefinition / ecs:UpdateService / ecs:DescribeServices, never
permission to create or change the infrastructure itself.

Deliberately reads the task definition via `describe-services` (what the
service is *actually* running), not `describe-task-definition --task-definition
<family>` (the highest revision number ever registered in that family,
regardless of whether anything is using it). Those two are NOT the same the
moment two different things register revisions in the same family — Terraform
creating a revision once, and this script creating a new one on every deploy,
both bump the same family's revision counter independently. Reading "latest
in family" instead of "what the service runs" is how a Terraform-set field
(like `runtimePlatform`) silently gets lost forever: this script would keep
cloning forward from whatever the highest revision number happens to be,
which can easily be one of *its own* earlier outputs — never Terraform's.

Usage:
  python3 deploy_service.py --cluster <cluster> --service <service> \\
      --container <container-name> --image <new-image-uri>
"""
import argparse
import json
import subprocess

ALLOWED_REGISTER_KEYS = [
    "family",
    "containerDefinitions",
    "executionRoleArn",
    "taskRoleArn",
    "networkMode",
    "requiresCompatibilities",
    "cpu",
    "memory",
    "volumes",
    # Without this, every deploy silently dropped whatever Terraform set
    # here (e.g. ARM64), reverting new task definition revisions back to
    # Fargate's X86_64 default — a real bug, not a hypothetical one.
    "runtimePlatform",
]


def run_aws(args):
    result = subprocess.run(["aws"] + args, capture_output=True, text=True, check=True)
    return json.loads(result.stdout) if result.stdout.strip() else {}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cluster", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--container", required=True)
    parser.add_argument("--image", required=True)
    args = parser.parse_args()

    services = run_aws(["ecs", "describe-services", "--cluster", args.cluster, "--services", args.service])
    current_arn = services["services"][0]["taskDefinition"]
    print(f"Service '{args.service}' is currently running {current_arn}")

    current = run_aws(["ecs", "describe-task-definition", "--task-definition", current_arn])
    task_def = current["taskDefinition"]

    found = False
    for container in task_def["containerDefinitions"]:
        if container["name"] == args.container:
            container["image"] = args.image
            found = True
    if not found:
        raise SystemExit(f"No container named '{args.container}' in task definition '{current_arn}'")

    register_args = {k: task_def[k] for k in ALLOWED_REGISTER_KEYS if k in task_def}

    with open("new-task-def.json", "w") as f:
        json.dump(register_args, f)

    registered = run_aws(["ecs", "register-task-definition", "--cli-input-json", "file://new-task-def.json"])
    new_arn = registered["taskDefinition"]["taskDefinitionArn"]
    print(f"Registered {new_arn}")

    run_aws(
        [
            "ecs",
            "update-service",
            "--cluster",
            args.cluster,
            "--service",
            args.service,
            "--task-definition",
            new_arn,
        ]
    )
    print(f"Updated service '{args.service}' in cluster '{args.cluster}' to {new_arn}")


if __name__ == "__main__":
    main()
