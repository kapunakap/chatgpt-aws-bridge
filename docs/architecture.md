# Architecture

## Mode A: direct OAuth

```text
ChatGPT
   │ OAuth 2.1
   ▼
AWS managed MCP Server
   │ IAM-authorized downstream calls
   ▼
AWS APIs
```

This is the preferred mode for a single AWS identity because AWS hosts the MCP server and the client can complete OAuth directly. There is no local daemon to maintain.

AWS currently hosts the managed server in:

- `us-east-1` at `https://aws-mcp.us-east-1.api.aws/mcp`
- `eu-central-1` at `https://aws-mcp.eu-central-1.api.aws/mcp`

The endpoint region is where the MCP endpoint is hosted. AWS operations can target other AWS regions as supported by the relevant API/tool parameters.

## Mode B: local SigV4 bridge

```text
ChatGPT
   │
   ▼
OpenAI Secure MCP Tunnel
   │ outbound only
   ▼
tunnel-client
   │ stdio
   ▼
mcp-proxy-for-aws
   │ SigV4 using local AWS credentials
   ▼
AWS managed MCP Server
   │
   ▼
AWS APIs
```

This mode is useful when ChatGPT needs to use one or more local AWS CLI credential profiles. `mcp-proxy-for-aws` signs requests with SigV4 and can expose an explicit allowlist of profiles.

## Authorization boundary

The AWS MCP Server does not replace IAM. Authenticated calls are evaluated by the downstream AWS service against the caller's existing IAM permissions and organization controls.

Managed MCP calls include context keys that policies can use for agent-specific restrictions:

- `aws:ViaAWSMCPService`
- `aws:CalledViaAWSMCP`

## Audit boundary

AWS documents CloudTrail audit visibility for API calls made through the managed AWS MCP Server. CloudWatch metrics are also available for the managed service.

## Threat model summary

The main risks are not the MCP protocol itself; they are over-privileged AWS identities, exposed long-lived credentials, accidental publication of tunnel secrets, and allowing an agent to reach production write credentials without sufficient guardrails.

The default posture should therefore be:

1. short-lived credentials;
2. least privilege;
3. read-only/default profile where practical;
4. explicit profile allowlists;
5. IAM conditions for MCP-specific restrictions;
6. CloudTrail review for sensitive actions;
7. no inbound public port for a local stdio process.
