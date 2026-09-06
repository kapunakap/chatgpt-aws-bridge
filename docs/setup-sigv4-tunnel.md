# SigV4 + OpenAI Secure MCP Tunnel setup

Use this path when direct OAuth is insufficient, especially for explicit local profiles or cross-account workflows.

## 1. Prerequisites

Install:

- AWS CLI 2.32.0 or newer;
- `uv` / `uvx`;
- `tunnel-client`;
- macOS `launchd` if you want the included persistence example.

Use short-lived AWS credentials where possible.

## 2. Authenticate AWS CLI

Examples:

```bash
aws login
```

or for an existing SSO profile:

```bash
aws sso login --profile YOUR_PROFILE
```

Verify without involving MCP:

```bash
./scripts/verify-aws-auth.sh --profile YOUR_PROFILE
```

The script suppresses caller identity values and only reports success/failure.

## 3. Verify proxy startup manually

Resolve `uvx`:

```bash
command -v uvx
```

For a single profile:

```bash
AWS_PROFILE=YOUR_PROFILE \
uvx mcp-proxy-for-aws==1.6.4 \
  https://aws-mcp.eu-central-1.api.aws/mcp \
  --metadata AWS_REGION=YOUR_DEFAULT_REGION
```

This is a foreground stdio process. Stop it after confirming it initializes.

## 4. Multi-profile mode

AWS supports an explicit profile allowlist in `mcp-proxy-for-aws`.

Using a CLI flag:

```bash
uvx mcp-proxy-for-aws==1.6.4 \
  https://aws-mcp.eu-central-1.api.aws/mcp \
  --profile prod-readonly dev staging
```

or an environment variable:

```bash
export AWS_MCP_PROXY_PROFILES="prod-readonly dev staging"
```

The first profile is the default. Only listed profiles are exposed to the MCP client. Prefer a read-only default profile.

## 5. Configure tunnel-client

Copy:

```bash
cp config/aws-sigv4.yaml.example \
  "$HOME/.config/tunnel-client/aws-mcp.yaml"
chmod 600 "$HOME/.config/tunnel-client/aws-mcp.yaml"
```

Edit the private file and replace only local placeholders. Never commit the resulting file.

For multi-profile mode, adapt the command so the proxy receives the explicit profile allowlist. Keep real profile names outside this public repository if they reveal environment/account structure.

## 6. Optional launchd persistence

Copy:

```bash
cp launchd/com.example.aws-mcp-tunnel.plist.example \
  "$HOME/Library/LaunchAgents/com.example.aws-mcp-tunnel.plist"
```

Edit paths, then validate:

```bash
plutil -lint "$HOME/Library/LaunchAgents/com.example.aws-mcp-tunnel.plist"
```

Load it using your normal launchd workflow.

After changing the private tunnel YAML, restart the exact LaunchAgent:

```bash
./scripts/restart-tunnel.sh com.example.aws-mcp-tunnel
```

## 7. Verify local readiness

```bash
./scripts/health-check.sh \
  --url-file "$HOME/.config/tunnel-client/aws-mcp-health.url"
```

Both `/healthz` and `/readyz` should succeed.

## 8. Final ChatGPT acceptance

Local AWS CLI and health checks do not prove the end-to-end path. From ChatGPT, perform:

1. an AWS documentation query;
2. an authenticated harmless API read;
3. if using multiple profiles, one read with the default profile and one with an explicitly allowlisted secondary profile;
4. a negative test using a profile not in the allowlist.

Do not mark the bridge complete based only on local CLI success.
