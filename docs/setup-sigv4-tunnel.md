# SigV4 + OpenAI Secure MCP Tunnel setup

Use this path when direct OAuth is insufficient, especially for explicit local profiles or cross-account workflows.

Direct OAuth is intentionally a single-identity connection. Multi-profile switching requires `mcp-proxy-for-aws` in SigV4 mode.

## 1. Prerequisites

Install:

- AWS CLI 2.32.0 or newer;
- `uv` / `uvx`;
- `tunnel-client`;
- macOS `launchd` if you want the included persistence example.

Use short-lived AWS credentials where possible.

## 2. Authenticate AWS CLI profiles

Each profile that ChatGPT may use must already have valid local AWS credentials. ChatGPT does not perform an AWS SSO/browser login on behalf of a profile.

For an SSO profile:

```bash
aws sso login --profile YOUR_PROFILE
```

For other credential providers, use their normal local login/refresh flow (for example `aws login` where applicable).

Verify one profile without involving MCP:

```bash
./scripts/verify-aws-auth.sh --profile YOUR_PROFILE
```

The script suppresses caller identity values and only reports success/failure.

For multiple profiles, authenticate/refresh each profile before starting the tunnel.

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

Using the CLI flag:

```bash
uvx mcp-proxy-for-aws==1.6.4 \
  https://aws-mcp.eu-central-1.api.aws/mcp \
  --profile prod-readonly dev staging \
  --metadata AWS_REGION=YOUR_DEFAULT_REGION
```

or using the environment variable:

```bash
export AWS_MCP_PROXY_PROFILES="prod-readonly dev staging"
```

The first profile is the default. Only listed profiles are exposed to the MCP client. Prefer a read-only default profile.

When multi-profile mode is active, the proxy adds an `aws_profile` parameter to the authenticated AWS MCP tools that support it. A tool call that omits `aws_profile` uses the first/default profile. A call with an allowlisted `aws_profile` uses that profile's credentials. A non-allowlisted value must be rejected by the proxy.

This is profile selection, not credential creation: expired SSO/login credentials still need to be refreshed locally.

## 5. Configure tunnel-client

For one profile, copy:

```bash
cp config/aws-sigv4.yaml.example \
  "$HOME/.config/tunnel-client/aws-mcp.yaml"
```

For multiple profiles, copy the dedicated example instead:

```bash
cp config/aws-sigv4-multiprofile.yaml.example \
  "$HOME/.config/tunnel-client/aws-mcp.yaml"
```

Then restrict permissions:

```bash
chmod 600 "$HOME/.config/tunnel-client/aws-mcp.yaml"
```

Edit only the private copy. Keep all real profile names, tunnel runtime secrets, and account-specific values outside Git when they reveal private environment structure.

In the multi-profile example, replace `YOUR_DEFAULT_PROFILE` and `YOUR_SECONDARY_PROFILE` with local AWS CLI profile names. Add more names before `--metadata` if needed. The first name remains the default profile.

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

For a single profile:

```bash
./scripts/verify-setup.sh \
  --profile YOUR_PROFILE \
  --tunnel-config "$HOME/.config/tunnel-client/aws-mcp.yaml" \
  --launch-label com.example.aws-mcp-tunnel \
  --health-url-file "$HOME/.config/tunnel-client/aws-mcp-health.url"
```

For multiple profiles, repeat `--profile` once per allowlisted profile:

```bash
./scripts/verify-setup.sh \
  --profile prod-readonly \
  --profile dev \
  --profile staging \
  --tunnel-config "$HOME/.config/tunnel-client/aws-mcp.yaml" \
  --launch-label com.example.aws-mcp-tunnel \
  --health-url-file "$HOME/.config/tunnel-client/aws-mcp-health.url"
```

The verifier checks AWS authentication for every supplied profile, the LaunchAgent, and tunnel health. Both `/healthz` and `/readyz` should succeed.

## 8. Final ChatGPT acceptance

Local AWS CLI and health checks do not prove the end-to-end path. From ChatGPT, perform:

1. an AWS documentation query;
2. confirm the live proxied tool schema exposes `aws_profile` on `run_script` and other current authenticated tools where upstream supports it;
3. a harmless authenticated read with no `aws_profile` and prove it used the intended default profile;
4. a harmless read with an explicitly allowlisted secondary `aws_profile` and prove it used the intended second account/identity;
5. a negative test using a profile not in the allowlist and confirm it is rejected.

Do not commit account IDs, ARNs, access keys, session tokens, SSO cache data, or other credentials as acceptance evidence.

Do not mark the bridge complete based only on local CLI success.
