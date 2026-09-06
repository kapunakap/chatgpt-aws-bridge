# Security policy

This repository contains reference configuration and documentation only. It must remain safe to publish publicly.

## Never commit

- AWS access keys or secret access keys;
- AWS session/security tokens;
- SSO cache files or browser authorization artifacts;
- `~/.aws/config` or `~/.aws/credentials` from a real machine;
- account IDs, role ARNs, user ARNs, bucket names, private endpoints, or other environment-specific identifiers unless deliberately public;
- OpenAI Secure MCP Tunnel runtime secrets, API keys, tunnel IDs, or credential-bearing URLs;
- private keys or certificates.

## Reporting a vulnerability

If you find a security problem in this repository itself, report it privately to the repository owner rather than posting credentials or exploit details in a public issue.

For vulnerabilities in AWS services or the official Agent Toolkit for AWS, use AWS's official vulnerability reporting process.
