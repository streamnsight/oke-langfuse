# Langfuse v4 OIDC compatibility probe

A standalone research probe for the exact `openid-client` dependency resolved
by Langfuse v4.78.0. It starts a local HTTP discovery endpoint that responds
with a 302 redirect; no real IdP, credentials, browser or cloud resources are used.

```sh
cd tests/probes/langfuse-v4-oidc
npm ci --ignore-scripts --no-audit --no-fund
npm test
```

Expected baseline: stock `openid-client@5.7.1` rejects 302 discovery; replacing
its native transports with `follow-redirects` succeeds. The second process
loads that transport change and restores the dependency file immediately.
Run the probe sequentially in its own dependency directory.

These assertions capture the current compatibility finding. They do not
validate the full Langfuse image, token POST redirects, cross-host redirects,
JWKS, userinfo, or an actual Oracle IDCS sign-in.
