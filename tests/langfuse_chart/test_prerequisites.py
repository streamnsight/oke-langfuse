"""Check chart-specific prerequisite ordering without changing a cluster."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "modules/apps/langfuse/helm_chart/scripts/install_langfuse_prerequisites.sh"
MOCK = '''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps([name, args]) + "\\n")
if os.environ.get("FAIL_PATTERN") and os.environ["FAIL_PATTERN"] in " ".join([name] + args):
    sys.exit(1)
'''


class PrerequisiteTests(unittest.TestCase):
    def run_script(self, chart, fail=""):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ("helm", "kubectl"):
                path = root / name
                path.write_text(MOCK)
                path.chmod(0o755)
            log = root / "commands.jsonl"
            env = dict(os.environ, PATH=f'{root}:{os.environ["PATH"]}',
                       COMMAND_LOG=str(log), FAIL_PATTERN=fail)
            result = subprocess.run(["bash", str(SCRIPT), chart], env=env,
                                    capture_output=True, text=True)
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, calls

    def test_chart_v1_does_not_touch_cluster(self):
        result, calls = self.run_script("1.5.41")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_v2_installs_operator_between_cert_and_clickhouse_checks(self):
        result, calls = self.run_script("2.2.4")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([name for name, _ in calls], ["kubectl", "kubectl", "helm", "kubectl", "kubectl"])
        self.assertIn("crd/certificates.cert-manager.io", calls[0][1])
        self.assertIn("deployment/cert-manager-webhook", calls[1][1])
        self.assertIn("--wait", calls[2][1])
        self.assertIn("0.0.8", calls[2][1])
        self.assertIn("crd/clickhouseclusters.clickhouse.com", calls[3][1])
        self.assertIn("crd/keeperclusters.clickhouse.com", calls[3][1])
        self.assertIn("app.kubernetes.io/instance=clickhouse-operator", calls[4][1])

    def test_unknown_major_stops_before_cluster_changes(self):
        result, calls = self.run_script("3.0.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(calls, [])

    def test_cert_failure_stops_before_install(self):
        result, calls = self.run_script("2.2.4", "crd/certificates.cert-manager.io")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 1)

    def test_install_failure_stops_before_ready_message(self):
        result, calls = self.run_script("2.2.4", "helm upgrade")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 3)
        self.assertNotIn("prerequisites are ready", result.stdout)

    def test_crd_failure_stops_before_operator_ready_check(self):
        result, calls = self.run_script("2.2.4", "crd/clickhouseclusters.clickhouse.com")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(len(calls), 4)


if __name__ == "__main__":
    unittest.main()
