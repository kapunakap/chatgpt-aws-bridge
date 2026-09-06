# Direct OAuth setup

Use this path for the simplest ChatGPT → AWS MCP connection.

## 1. Choose the AWS managed MCP endpoint

AWS currently documents:

```text
https://aws-mcp.us-east-1.api.aws/mcp
https://aws-mcp.eu-central-1.api.aws/mcp
```

Choose one endpoint for the MCP connection.

## 2. Allow AWS MCP OAuth sign-in

AWS provides the managed policy:

```text
arn:aws:iam::aws:policy/AWSMCPSignInOAuthAccessPolicy
```

Attach it to the IAM role or user that will authorize the MCP connection. Examples:

```bash
aws iam attach-role-policy \
  --role-name YOUR_ROLE_NAME \
  --policy-arn arn:aws:iam::aws:policy/AWSMCPSignInOAuthAccessPolicy
```

or:

```bash
aws iam attach-user-policy \
  --user-name YOUR_USER_NAME \
  --policy-arn arn:aws:iam::aws:policy/AWSMCPSignInOAuthAccessPolicy
```

Do not copy real role/user names into this repository.

This managed policy enables the OAuth authorization flow. It does not grant arbitrary downstream service access; your normal IAM permissions still determine what AWS API operations are allowed.

## 3. Add the MCP endpoint to ChatGPT

Create/connect a ChatGPT Personal MCP plugin/connection using the chosen AWS endpoint URL. UI labels can change over time; the durable configuration value is the AWS managed MCP URL.

Complete the AWS Sign-in flow when prompted.

## 4. Verify knowledge tools first

Ask:

```text
What AWS Regions are available?
```

This verifies that the MCP connection and knowledge tools are loaded.

## 5. Verify authenticated AWS API access

Run a harmless read appropriate to your account. Good acceptance tests include:

- caller identity (without pasting identifiers into public logs);
- list/describe operations on a non-sensitive service;
- a resource inventory read against a known non-production account.

Do not use a destructive API as the first acceptance test.

## 6. Add agent-specific IAM controls

Review:

- `aws:ViaAWSMCPService`
- `aws:CalledViaAWSMCP`

Use them to constrain MCP-originated requests where appropriate. See [security.md](security.md).

## Limitations

OAuth sessions are bound to a single AWS identity. AWS does not currently support per-call multi-profile switching in OAuth mode. Use the SigV4 path when you need that behavior.
