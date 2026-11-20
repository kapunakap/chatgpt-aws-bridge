# SigV4 + OpenAI Secure MCP Tunnel setup

Choose this path when ChatGPT must use local AWS CLI credentials or switch accounts per tool call. Direct OAuth cannot expose `aws_profile`.

## 1. Prerequisites

Install AWS CLI 2.32.0+, `uv` / `uvx`, and `tunnel-client`; macOS `launchd` is optional for persistence. Use short-lived credentials and least-privilege profiles.

Verify the local requirements:

```bash
./scripts/check-prerequisites.sh sigv4
```

## 2. Log in and verify local profiles

For an AWS Sign-in (`aws login`) profile:

```bash
aws login --profile YOUR_READONLY_PROFILE
```

For IAM Identity Center / SSO:

```bash
aws sso login --profile YOUR_SECONDARY_PROFILE
```

Verify each one independently:

```bash
./scripts/verify-aws-auth.sh --profile YOUR_READONLY_PROFILE
./scripts/verify-aws-auth.sh --profile YOUR_SECONDARY_PROFILE
```

The check makes an STS `GetCallerIdentity` request but prints only success or failure, never account IDs or ARNs. Run it separately for every profile you intend to allowlist.

## 3. Choose a private tunnel configuration

Use the existing **single-profile** template when you need one identity:

```bash
mkdir -p "$HOME/.config/tunnel-client"
cp config/aws-sigv4.yaml.example "$HOME/.config/tunnel-client/aws-mcp.yaml"
chmod 600 "$HOME/.config/tunnel-client/aws-mcp.yaml"
```

For **two or more profiles**, use the new dedicated template instead:

```bash
mkdir -p "$HOME/.config/tunnel-client"
cp config/aws-sigv4-multi-profile.yaml.example "$HOME/.config/tunnel-client/aws-mcp.yaml"
chmod 600 "$HOME/.config/tunnel-client/aws-mcp.yaml"
```

Edit **only** that private file. Replace the control-plane placeholders, the absolute path to `uvx` (`command -v uvx`), the default region, and every `YOUR_*_PROFILE` placeholder. Keep tunnel keys, profile names, and AWS credentials outside the repository.

The multi-profile command starts the pinned AWS proxy with:

```text
--profile YOUR_READONLY_PROFILE YOUR_SECONDARY_PROFILE
```

The first profile is the default. Extra profiles are available only when explicitly listed. The command unsets inherited `AWS_MCP_PROXY_PROFILES` and `AWS_PROFILE`, so they cannot silently override this allowlist. If you prefer the environment form, AWS also supports `AWS_MCP_PROXY_PROFILES="PROFILE_ONE PROFILE_TWO"`; that variable takes precedence over CLI flags.

**Do not** use `--skip-auth` or widen IAM policies to make switching work.

## 4. Optional manual startup test

Run the proxy in the foreground to inspect initialization, then stop it:

```bash
uvx mcp-proxy-for-aws==1.6.4 \
  https://aws-mcp.eu-central-1.api.aws/mcp \
  --profile YOUR_READONLY_PROFILE YOUR_SECONDARY_PROFILE \
  --metadata AWS_REGION=YOUR_DEFAULT_REGION
```

For single-profile mode, pass one profile. Configure a region for each profile or pass `AWS_REGION` as needed.

## 5. Start the tunnel

Copy the launchd example if you use macOS persistence:

```bash
cp launchd/com.example.aws-mcp-tunnel.plist.example \
  "$HOME/Library/LaunchAgents/com.example.aws-mcp-tunnel.plist"
```

Edit local paths, then validate:

```bash
plutil -lint "$HOME/Library/LaunchAgents/com.example.aws-mcp-tunnel.plist"
```

Load the LaunchAgent using your normal workflow. After editing the **profile allowlist** in the private YAML, restart the tunnel:

```bash
./scripts/restart-tunnel.sh com.example.aws-mcp-tunnel
```

Changing the profile list requires reinitializing the proxy. Switching among already allowed profiles does **not** require a restart.

## 6. Verify every configured profile and tunnel health

**Single profile (backward compatible):**

```bash
./scripts/verify-setup.sh \
  --profile YOUR_PROFILE \
  --tunnel-config "$HOME/.config/tunnel-client/aws-mcp.yaml" \
  --launch-label com.example.aws-mcp-tunnel \
  --health-url-file "$HOME/.config/tunnel-client/aws-mcp-health.url"
```

**Multiple profiles:** pass the **entire allowlist in the same order as the private YAML**, not just the default:

```bash
./scripts/verify-setup.sh \
  --profile YOUR_READONLY_PROFILE \
  --profile YOUR_SECONDARY_PROFILE \
  --require-distinct-accounts \
  --tunnel-config "$HOME/.config/tunnel-client/aws-mcp.yaml" \
  --launch-label com.example.aws-mcp-tunnel \
  --health-url-file "$HOME/.config/tunnel-client/aws-mcp-health.url"
```

Each profile is authenticated independently. The optional `--require-distinct-accounts` flag verifies that all supplied profiles resolve to **different accounts**, without printing or storing identities. Omit that flag if you intentionally use multiple roles in the same AWS account. Add `--region YOUR_DEFAULT_REGION` when needed.

The script does **not** parse arbitrary tunnel YAML to discover profiles: the supplied `--profile` arguments must match the configured allowlist. This local check validates AWS CLI credentials, launchd, and `/healthz` and `/readyz`; it does not establish that ChatGPT is using this connection.

## 7. Refresh credentials

The proxy picks up refreshed credentials for existing profiles on subsequent calls:

```bash
aws login --profile YOUR_PROFILE
# or
aws sso login --profile YOUR_PROFILE
./scripts/verify-aws-auth.sh --profile YOUR_PROFILE
```

You should not need to restart just to refresh an expired session. If you **add or remove profiles**, edit the private allowlist and restart the tunnel; then reload the ChatGPT MCP connection so its tool schemas reflect the change.

## 8. End-to-end ChatGPT acceptance (required)

Connect ChatGPT to the **Secure MCP Tunnel / SigV4 connection**, not the old direct OAuth connection. Then verify:

1. ChatGPT loads the proxied AWS MCP tools and `run_script` (plus supported authenticated tools) exposes `aws_profile`. If absent, check for an OAuth connection or a single-profile/stale proxy.
2. A harmless AWS API read succeeds with `aws_profile` omitted (the first/default profile).
3. A harmless read succeeds using `aws_profile="YOUR_SECONDARY_PROFILE"`.
4. Both reads reach the **intended distinct accounts**; compare identifiers privately, without adding them to a public issue, PR, or log.
5. A call with a **non-allowlisted** profile is rejected by the proxy.
6. CloudTrail records MCP-driven AWS API activity with expected attribution (see [security.md](security.md)).
7. Confirm no tokens, account IDs, ARNs, live profile names, or tunnel secrets have been committed.

Do not mark the issue complete on the basis of local CLI success or documentation alone.
