"""Run secret provisioning with fake CLIs; native OCI must need no S3 keys."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NativeOCISecrets(unittest.TestCase):
    def test_provisioning_never_requests_s3_credentials(self):
        with tempfile.TemporaryDirectory() as directory:
            home = Path(directory)
            binary = home / "bin"
            binary.mkdir()
            # Every output here is synthetic. No cloud or Kubernetes calls occur.
            oci = binary / "oci"
            oci.write_text('''#!/usr/bin/env python3
import base64, os, pathlib, sys
args = sys.argv[1:]
with open(os.environ["CALL_LOG"], "a") as log:
    log.write("oci " + " ".join(args) + "\\n")
if "create-kubeconfig" in args:
    config = pathlib.Path(args[args.index("--file") + 1])
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text("# fake config\\n" * 30)
elif "secret-bundle" in args:
    print(base64.b64encode(b"fake-value").decode())
elif "vault" in args:
    print("fake-secret-id")
else:
    print("fake-certificate")
''')
            kubectl = binary / "kubectl"
            kubectl.write_text('''#!/usr/bin/env python3
import os, sys
with open(os.environ["CALL_LOG"], "a") as log:
    log.write("kubectl " + " ".join(sys.argv[1:]) + "\\n")
sys.exit(1 if sys.argv[1] == "get" else 0)
''')
            # The deployment runs on Linux; use a no-op sed for macOS portability.
            sed = binary / "sed"
            sed.write_text("#!/bin/sh\nexit 0\n")
            for path in (oci, kubectl, sed):
                path.chmod(0o755)
            log = home / "calls.log"
            env = dict(os.environ, HOME=str(home), PATH=f"{binary}:{os.environ['PATH']}",
                       CALL_LOG=str(log), CLUSTER_ID="fake-cluster", REGION="fake-region",
                       COMPARTMENT_ID="fake-compartment", SECRETS_STORE_VAULT_ID="fake-vault",
                       DEPLOY_ID="fake-deploy", PSQL_OCID="fake-postgres")
            subprocess.run(["bash", str(ROOT / "modules/apps/langfuse/helm_chart/scripts/create_oke_secrets.sh")],
                           cwd=home, env=env, check=True, capture_output=True, text=True)
            calls = log.read_text()
            self.assertNotIn("S3", calls)
            self.assertNotIn("langfuse-s3", calls)
            for name in ("langfuse", "langfuse-idcs", "langfuse-postgres-cert", "langfuse-postgres"):
                self.assertIn(f"create secret generic {name} ", calls)


if __name__ == "__main__":
    unittest.main()
