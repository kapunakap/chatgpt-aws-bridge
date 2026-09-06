# Security

## Principle 1: IAM remains authoritative

AWS MCP does not bypass IAM. Downstream AWS services authorize requests using the caller's existing permissions and applicable organization controls.

Start with the smallest permissions needed. A broad administrator identity is a poor default for an AI agent.

## Principle 2: distinguish MCP-originated requests

AWS managed MCP servers add context keys that can be used in IAM policies and service control policies:

```text
aws:ViaAWSMCPService
aws:CalledViaAWSMCP
```

For the general AWS MCP Server, the service principal value is:

```text
aws-mcp.amazonaws.com
```

This enables controls that only apply to MCP-driven actions.

## Principle 3: use explicit Deny for hard guardrails

An explicit IAM/SCP Deny is stronger than relying on prompt instructions such as "never delete production data".

The included examples demonstrate:

- a kill switch that denies all managed-MCP-originated AWS actions;
- an S3-specific delete guardrail for requests via the AWS MCP Server.

They are intentionally narrow examples. Production policies should be reviewed against your actual services and resources.

## Principle 4: short-lived credentials

Prefer temporary credentials from AWS Sign-in, IAM Identity Center/SSO, or assumed roles instead of long-lived IAM user access keys.

Never commit:

- `AWS_ACCESS_KEY_ID`;
- `AWS_SECRET_ACCESS_KEY`;
- `AWS_SESSION_TOKEN`;
- SSO cache files;
- real AWS config/credentials files;
- Secure MCP Tunnel secrets.

## Principle 5: profile allowlists

In SigV4 multi-profile mode, configure only the profiles the agent needs. AWS MCP Proxy exposes only explicitly configured profiles.

A useful pattern is:

```text
prod-readonly   # default
staging-write
dev-write
```

Avoid making a highly privileged production write profile the default.

## Principle 6: audit

Review CloudTrail for MCP-driven AWS API actions. Use CloudWatch/CloudTrail alerting for sensitive operations when appropriate.

## Important bypass consideration

MCP-specific IAM condition keys only apply when a request actually passes through an AWS managed MCP server. If an agent also has a general shell/terminal tool with AWS credentials, it may be able to call AWS directly through the CLI/SDK and bypass MCP-specific conditions.

Treat the whole client/tool environment as part of the security boundary.

## Public repository hygiene

Run:

```bash
./scripts/secret-scan.sh
```

before publishing changes. The scan is deliberately conservative but cannot guarantee that a repository contains no secrets. Review diffs manually as well.
