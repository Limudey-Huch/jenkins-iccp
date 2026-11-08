#!/usr/bin/env python3
"""
Deploys a new image to a running ECS Fargate service, without touching
Terraform:
  1. Reads the current task definition
  2. Replaces just the image for the named container
  3. Registers a new task definition revision
  4. Updates the service to use it

Terraform owns the *shape* of the infrastructure (created once, manually, by
the instructor/student). This script is what the Jenkins pipeline actually
calls on every build to ship a new image — the two are deliberately separate,
so the narrow jenkins-deploy-<env> IAM user only ever needs
ecs:RegisterTaskDefinition / ecs:UpdateService / ecs:DescribeServices, never
permission to create or change the infrastructure itself.

Usage:
  python3 deploy_service.py --cluster <cluster> --service <service> \\
      --family <family> --container <container-name> --image <new-image-uri>
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
]


def run_aws(args):
    result = subprocess.run(["aws"] + args, capture_output=True, text=True, check=True)
    return json.loads(result.stdout) if result.stdout.strip() else {}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cluster", required=True)
    parser.add_argument("--service", required=True)
    parser.add_argument("--family", required=True)
    parser.add_argument("--container", required=True)
    parser.add_argument("--image", required=True)
    args = parser.parse_args()

    current = run_aws(["ecs", "describe-task-definition", "--task-definition", args.family])
    task_def = current["taskDefinition"]

    found = False
    for container in task_def["containerDefinitions"]:
        if container["name"] == args.container:
            container["image"] = args.image
            found = True
    if not found:
        raise SystemExit(f"No container named '{args.container}' in task definition '{args.family}'")

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
