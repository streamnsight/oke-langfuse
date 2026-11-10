const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const assert = require('node:assert/strict');
const helper = path.join(__dirname, 'node_modules/openid-client/lib/helpers/request.js');
const patched = process.argv.includes('--patched');
const original = fs.readFileSync(helper, 'utf8');
if (patched) {
  fs.writeFileSync(helper, original.replace("const http = require('http');", "const { http } = require('follow-redirects');").replace("const https = require('https');", "const { https } = require('follow-redirects');"));
}
// Load the altered transport into this process only, then restore the file.
let Issuer;
try { ({ Issuer } = require('openid-client')); }
finally { if (patched) fs.writeFileSync(helper, original); }
const hits = [];
const server = http.createServer((req, res) => {
  hits.push(req.url);
  const base = `http://127.0.0.1:${server.address().port}`;
  if (req.url === '/.well-known/openid-configuration') {
    res.writeHead(302, {Location: base + '/metadata'}); res.end();
  } else {
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({issuer: base, authorization_endpoint: base + '/authorize', token_endpoint: base + '/token', jwks_uri: base + '/jwks', response_types_supported: ['code'], subject_types_supported: ['public'], id_token_signing_alg_values_supported: ['RS256']}));
  }
});
server.listen(0, '127.0.0.1', async () => {
  try {
    let succeeded = false, error;
    try { await Issuer.discover(`http://127.0.0.1:${server.address().port}/.well-known/openid-configuration`); succeeded = true; }
    catch (e) { error = e.message; }
    assert.equal(succeeded, patched);
    console.log(JSON.stringify({package: 'openid-client@5.7.1', patched, succeeded, error, hits}));
  } catch (e) { console.error(e); process.exitCode = 1; }
  finally { server.close(); }
});
