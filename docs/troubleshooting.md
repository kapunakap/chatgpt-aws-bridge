# Troubleshooting

## ChatGPT loads no AWS MCP tools

Check:

1. the configured MCP endpoint URL;
2. whether the OAuth flow completed or the local SigV4 bridge is ready;
3. whether the connection/plugin was reloaded after configuration changes;
4. the chosen endpoint is one of AWS's currently supported managed MCP regions.

Start with a knowledge query such as:

```text
What AWS Regions are available?
```

## OAuth sign-in returns access denied

Verify the authorizing IAM identity has the AWS-managed policy required for AWS MCP OAuth sign-in:

```text
AWSMCPSignInOAuthAccessPolicy
```

Also check organization-level restrictions and OAuth-specific AWS Sign-in controls.

## AWS API calls return AccessDenied

The AWS MCP Server uses your existing downstream AWS permissions. Check:

- IAM identity policies;
- permission boundaries;
- SCPs;
- resource policies;
- MCP-specific conditions using `aws:ViaAWSMCPService` or `aws:CalledViaAWSMCP`.

Do not try to fix this with deprecated `aws-mcp:*` IAM actions.

## `ExpiredTokenException`

Refresh the credential source.

For `aws login`:

```bash
aws login
```

For IAM Identity Center/SSO:

```bash
aws sso login --profile YOUR_PROFILE
```

Then rerun:

```bash
./scripts/verify-aws-auth.sh --profile YOUR_PROFILE
```

## SigV4 failures / request signature errors

Check system clock accuracy. SigV4 is time-sensitive.

Also confirm:

- the intended profile is active;
- credentials are not expired;
- the proxy endpoint is correct;
- `AWS_REGION` is valid;
- the local proxy is using the intended credential provider chain.

## Multi-profile name is rejected

The proxy only exposes profiles configured at startup through `--profile` or `AWS_MCP_PROXY_PROFILES`. A profile existing in `~/.aws/config` is not enough by itself.

Restart the local proxy/tunnel after changing the allowlist.

## Tunnel health is live but not ready

`/healthz` only proves the daemon is alive. `/readyz` is the stronger signal.

Inspect the local tunnel logs and verify the stdio child process can launch. Common causes:

- wrong absolute path to `uvx`;
- expired AWS credentials;
- invalid profile name;
- malformed private YAML;
- launchd using an old configuration loaded before your edit.

After editing the private tunnel config, restart the exact LaunchAgent:

```bash
./scripts/restart-tunnel.sh com.example.aws-mcp-tunnel
```

## Local tests pass but ChatGPT still fails

Do not equate CLI success with plugin success. Verify the entire path from ChatGPT itself. The final acceptance must include a real AWS MCP tool call initiated from ChatGPT.
