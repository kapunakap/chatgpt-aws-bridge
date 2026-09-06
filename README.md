# chatgpt-aws-bridge

A secret-safe reference setup for using the **AWS MCP Server** from ChatGPT.

This repository does **not** reimplement AWS MCP. It documents and packages the ChatGPT-specific integration, security boundaries, verification, and optional local SigV4 bridge around AWS's managed MCP server.

## Recommended architecture: direct OAuth

As of July 2026, AWS supports OAuth 2.1 for web MCP clients, including ChatGPT.com. For a single AWS identity, this is the simplest path:

```text
ChatGPT
   │ OAuth 2.1
   ▼
AWS managed MCP Server
   │
   ▼
AWS APIs
```

No local proxy or public inbound port is required.

## Advanced architecture: SigV4 + Secure MCP Tunnel

Use this when you need local AWS CLI credentials, explicit AWS profiles, or multi-account/profile switching in one ChatGPT session:

```text
ChatGPT
   │
   ▼
OpenAI Secure MCP Tunnel
   │ outbound tunnel
   ▼
tunnel-client
   │ stdio
   ▼
mcp-proxy-for-aws
   │ SigV4
   ▼
AWS managed MCP Server
   │
   ▼
AWS APIs
```

The proxy signs requests with your existing AWS credentials. The AWS MCP Server adds MCP-specific IAM context keys and forwards requests to downstream AWS services, where your normal IAM permissions remain authoritative.

## Why this repo exists

AWS already maintains the official [Agent Toolkit for AWS](https://github.com/aws/agent-toolkit-for-aws). This repo focuses on the missing operational layer for ChatGPT users:

- a minimal ChatGPT-oriented setup path;
- secure defaults and IAM guardrails for agent actions;
- a reproducible SigV4/tunnel-client path when OAuth is not enough;
- multi-profile guidance for dev/staging/prod or cross-account workflows;
- secret-safe config templates;
- local health/auth verification scripts;
- an explicit end-to-end acceptance checklist.

## Choose a mode

| Need | Recommended mode |
|---|---|
| One AWS identity from ChatGPT | Direct OAuth |
| No local process | Direct OAuth |
| Multiple AWS CLI profiles in one session | SigV4 + tunnel-client |
| Cross-account/profile switching per tool call | SigV4 + tunnel-client |
| Existing local AWS SSO / `aws login` credentials | SigV4 + tunnel-client |

AWS documents two managed MCP endpoints:

- US East (N. Virginia): `https://aws-mcp.us-east-1.api.aws/mcp`
- Europe (Frankfurt): `https://aws-mcp.eu-central-1.api.aws/mcp`

## Quick start: direct OAuth

1. Give the IAM role or user permission to authorize AWS MCP OAuth. AWS currently provides the managed policy:

   ```text
   arn:aws:iam::aws:policy/AWSMCPSignInOAuthAccessPolicy
   ```

2. In ChatGPT, create/connect an MCP Personal plugin using one of the AWS managed MCP endpoint URLs above.
3. Complete the AWS Sign-in OAuth flow in the browser.
4. Start with a harmless documentation test:

   ```text
   What AWS Regions are available?
   ```

5. Then verify authenticated API access with a read-only request appropriate to your account.

OAuth does **not** grant extra AWS permissions. Existing IAM policies, SCPs, permission boundaries, resource policies, and other controls still govern what the MCP can do.

See [docs/setup-oauth.md](docs/setup-oauth.md).

## Quick start: SigV4 + tunnel-client

Prerequisites:

- AWS CLI 2.32.0 or newer;
- valid AWS CLI credentials (`aws login`, SSO, or another supported provider);
- `uvx` from Astral `uv`;
- `mcp-proxy-for-aws` pinned to a known version;
- `tunnel-client`;
- an OpenAI Secure MCP Tunnel / Personal plugin configuration.

First verify AWS credentials outside the tunnel:

```bash
./scripts/verify-aws-auth.sh --profile YOUR_PROFILE
```

Copy the secret-safe example outside the repository:

```bash
mkdir -p "$HOME/.config/tunnel-client"
cp config/aws-sigv4.yaml.example \
  "$HOME/.config/tunnel-client/aws-mcp.yaml"
chmod 600 "$HOME/.config/tunnel-client/aws-mcp.yaml"
```

Edit only the private copy. Keep all tunnel runtime secrets outside Git.

The example launches:

```text
uvx mcp-proxy-for-aws==1.6.4 <AWS_MCP_ENDPOINT>
```

with an explicit AWS profile and default AWS Region.

See [docs/setup-sigv4-tunnel.md](docs/setup-sigv4-tunnel.md).

## Multi-profile support

AWS MCP's SigV4 proxy can expose an allowlisted set of AWS CLI profiles and add an `aws_profile` parameter to authenticated tool calls. This enables per-call switching without restarting the MCP client.

Example:

```text
AWS_MCP_PROXY_PROFILES="prod-readonly dev staging"
```

Use a read-only profile as the default when practical. Only explicitly listed profiles are available to the agent.

OAuth does not currently support per-call multi-profile switching.

## IAM guardrails

AWS managed MCP requests carry global condition context keys:

- `aws:ViaAWSMCPService` = `true` when a request passed through an AWS managed MCP server;
- `aws:CalledViaAWSMCP` = the specific MCP service principal, such as `aws-mcp.amazonaws.com`.

These keys let you apply controls specifically to agent/MCP traffic without changing direct human CLI access.

This repo includes two intentionally small policy examples:

- [examples/iam/deny-all-via-mcp.json](examples/iam/deny-all-via-mcp.json)
- [examples/iam/deny-s3-deletes-via-aws-mcp.json](examples/iam/deny-s3-deletes-via-aws-mcp.json)

Treat them as examples, not universal production policies. Test IAM changes in non-production first.

See [docs/security.md](docs/security.md).

## Verification

### Repository checks

```bash
./scripts/check-repo.sh
```

### AWS credential check

```bash
./scripts/verify-aws-auth.sh --profile YOUR_PROFILE
```

The script calls `aws sts get-caller-identity` but suppresses account/ARN output.

### Local tunnel health

```bash
./scripts/health-check.sh \
  --url-file "$HOME/.config/tunnel-client/aws-mcp-health.url"
```

### Full local SigV4 setup check

```bash
./scripts/verify-setup.sh \
  --profile YOUR_PROFILE \
  --tunnel-config "$HOME/.config/tunnel-client/aws-mcp.yaml" \
  --launch-label com.example.aws-mcp-tunnel \
  --health-url-file "$HOME/.config/tunnel-client/aws-mcp-health.url"
```

Local checks are necessary but **not sufficient**. Final acceptance requires a real tool call from ChatGPT through the configured AWS MCP connection.

## End-to-end acceptance

Do not call the setup complete until all applicable gates pass:

1. ChatGPT loads the AWS MCP tools.
2. Documentation search succeeds.
3. An authenticated, harmless AWS API read succeeds.
4. The returned data is clearly from the intended AWS identity/account without exposing identifiers in logs or screenshots.
5. If using SigV4 multi-profile mode, an explicitly allowlisted secondary profile works and a non-allowlisted profile is rejected.
6. CloudTrail provides audit visibility for AWS API actions performed through the MCP path.
7. No secrets are present in the repository.

### Live acceptance record — 2026-09-06

A real ChatGPT.com connection was validated against the AWS managed MCP Server using **direct OAuth**:

- AWS MCP knowledge/documentation search succeeded;
- an authenticated `STS GetCallerIdentity` read succeeded through the live AWS MCP connection;
- account and principal identifiers were redacted before evidence was reported;
- the authenticated identity matched the account and principal recorded by the corresponding ChatGPT AWS-MCP OAuth authorization event;
- CloudTrail recorded the MCP-driven `GetCallerIdentity` call with `aws-mcp.amazonaws.com` attribution;
- the live authenticated tool schema did not expose an `aws_profile` parameter, so SigV4 multi-profile positive/negative tests were not applicable to this OAuth validation.

The SigV4/tunnel path remains documented for users who need local profiles or cross-account switching, but it was not the transport used by this acceptance run.

## Important tool note

AWS deprecated `aws___call_aws` on July 15, 2026 and scheduled its removal after August 31, 2026. As of September 6, 2026, the live ChatGPT AWS MCP surface rejects that tool as removed. Use `aws___run_script` for authenticated AWS operations and the other current AWS MCP tools as appropriate.

## Security boundaries

- Never commit AWS access keys, session tokens, SSO caches, credential files, or tunnel secrets.
- Never commit live `~/.aws/config` or `~/.aws/credentials` files.
- Keep private tunnel YAML and secret-reference files at mode `0600`.
- Use short-lived credentials where possible.
- Prefer a read-only/default profile and narrowly scoped write-capable profiles.
- Use `aws:ViaAWSMCPService` / `aws:CalledViaAWSMCP` guardrails where appropriate.
- Review CloudTrail for sensitive MCP-driven actions.
- Do not expose a local stdio MCP process directly to the public Internet.

## Repository layout

```text
chatgpt-aws-bridge/
├── README.md
├── LICENSE
├── SECURITY.md
├── .gitignore
├── .github/workflows/ci.yml
├── config/
│   └── aws-sigv4.yaml.example
├── launchd/
│   └── com.example.aws-mcp-tunnel.plist.example
├── examples/iam/
│   ├── deny-all-via-mcp.json
│   └── deny-s3-deletes-via-aws-mcp.json
├── scripts/
│   ├── check-prerequisites.sh
│   ├── verify-aws-auth.sh
│   ├── health-check.sh
│   ├── restart-tunnel.sh
│   ├── verify-setup.sh
│   ├── secret-scan.sh
│   └── check-repo.sh
└── docs/
    ├── architecture.md
    ├── setup-oauth.md
    ├── setup-sigv4-tunnel.md
    ├── security.md
    └── troubleshooting.md
```

## Upstream sources

- AWS Agent Toolkit: https://github.com/aws/agent-toolkit-for-aws
- AWS MCP Server setup: https://docs.aws.amazon.com/agent-toolkit/latest/userguide/getting-started-aws-mcp-server.html
- Multi-profile support: https://docs.aws.amazon.com/agent-toolkit/latest/userguide/multi-account-access.html
- IAM integration: https://docs.aws.amazon.com/agent-toolkit/latest/userguide/security_iam_service-with-iam.html
- Tool reference: https://docs.aws.amazon.com/agent-toolkit/latest/userguide/understanding-mcp-server-tools.html

## License

MIT. See [LICENSE](LICENSE).
