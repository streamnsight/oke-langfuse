"""Exercise real Terraform selection and the v4 shell flow without cloud builds."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / "modules/apps/langfuse/build_image"
MOCK = r'''#!/usr/bin/env python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["COMMAND_LOG"], "a") as log:
    log.write(json.dumps([name, args]) + "\n")
if name == "curl":
    print(json.dumps({"region":"us-chicago-1", "metadata":{"deploy_id":"test", "cluster_compartment_id":"test-compartment", "langfuse_helm_chart_version":os.environ.get("TEST_CHART", "2.2.4")}}))
elif name == "helm":
    if os.environ.get("HELM_FAIL"): sys.exit(1)
    print('appVersion: "' + os.environ.get("TEST_APP", "4.77.0") + '"')
elif name == "oci":
    if "raw-request" in args: print(json.dumps({"data":{"token":"test-token"}}))
    elif "ns" in args: print(json.dumps({"data":"namespace"}))
    elif "list" in args: print("null")
    else: print("{}")
elif name == "podman":
    if args[0] == "system": print(json.dumps({"version":{"OsArch":"linux/amd64"}}))
    elif args[0] == "login": sys.stdin.read()
    elif args[0] == "pull":
        repo = args[-1].rsplit("/", 1)[-1].split(":")[0]
        sys.exit(0 if repo in os.environ.get("CACHED_IMAGES", "").split(",") else 1)
elif name == "git":
    destination = pathlib.Path(args[-1])
    destination.mkdir()
elif name == "pnpm":
    if args[0] == "list":
        print(json.dumps([{"dependencies":{"openid-client":{"version":os.environ.get("OPENID_VERSION", "5.7.1")}}}]))
    elif args[0] == "patch":
        target = pathlib.Path(args[args.index("--edit-dir") + 1]) / "lib/helpers/request.js"
        target.parent.mkdir(parents=True)
        target.write_text("changed upstream layout" if os.environ.get("BAD_TRANSPORT") else "const http = require('http');\nconst https = require('https');\n")
    elif args[0] == "patch-commit":
        contents = (pathlib.Path(args[1]) / "lib/helpers/request.js").read_text()
        assert "const { http } = require('follow-redirects');" in contents
        assert "const { https } = require('follow-redirects');" in contents
'''


class ScriptSelection(unittest.TestCase):
    def select(self, version):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            shutil.copy(MODULE / "script_selection.tf", root)
            shutil.copytree(MODULE / "scripts", root / "scripts")
            return subprocess.run(["terraform", f"-chdir={root}", "console", "-no-color", f"-var=langfuse_helm_chart_version={version}"],
                                  input='jsonencode(file("${path.module}/scripts/${local.image_build_script}"))\n',
                                  capture_output=True, text=True)

    def test_chart_one_keeps_legacy_script(self):
        result = self.select("1.5.41")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(json.loads(result.stdout)), (MODULE / "scripts/build_langfuse_image.sh").read_text())

    def test_chart_two_uses_v4_script(self):
        result = self.select("2.2.4")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(json.loads(result.stdout)), (MODULE / "scripts/build_langfuse_image_v4.sh").read_text())

    def test_unknown_chart_major_is_rejected(self):
        result = self.select("3.0.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("require an explicit build-script mapping", result.stderr)


class V4Builder(unittest.TestCase):
    def build(self, **options):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            tools = root / "bin"
            tools.mkdir()
            for name in ("curl", "helm", "oci", "podman", "git", "pnpm"):
                path = tools / name
                path.write_text(MOCK)
                path.chmod(0o755)
            log = root / "commands.jsonl"
            env = dict(os.environ, PATH=f'{tools}:{os.environ["PATH"]}', COMMAND_LOG=str(log), **options)
            result = subprocess.run(["bash", str(MODULE / "scripts/build_langfuse_image_v4.sh")],
                                    cwd=root, env=env, capture_output=True, text=True)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            return result, calls

    def test_builds_and_pushes_application_version_with_redirect_patch(self):
        result, calls = self.build()
        self.assertEqual(result.returncode, 0, result.stderr)
        builds = [args for name, args in calls if name == "podman" and args[0] == "build"]
        self.assertEqual(len(builds), 2)
        for args in builds:
            self.assertIn(":4.77.0", args[args.index("-t") + 1])
            self.assertIn("NEXT_PUBLIC_BASE_PATH=/langfuse", args)
            self.assertIn("--platform=linux/amd64", args)
        self.assertEqual(len([1 for name, args in calls if name == "podman" and args[0] == "push"]), 2)
        self.assertTrue(any(name == "pnpm" and args[0] == "patch-commit" for name, args in calls))
        self.assertTrue(any(name == "git" and "v4.77.0" in args for name, args in calls))

    def test_cached_images_skip_source_and_build(self):
        result, calls = self.build(CACHED_IMAGES="langfuse,langfuse-worker")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(name in ("git", "pnpm") for name, _ in calls))
        self.assertFalse(any(name == "podman" and args[0] == "build" for name, args in calls))

    def test_cached_web_builds_only_worker(self):
        result, calls = self.build(CACHED_IMAGES="langfuse")
        self.assertEqual(result.returncode, 0, result.stderr)
        builds = [args for name, args in calls if name == "podman" and args[0] == "build"]
        self.assertEqual(len(builds), 1)
        self.assertIn("./worker/Dockerfile", builds[0])
        self.assertFalse(any(name == "pnpm" for name, _ in calls))

    def test_helm_failure_stops_before_registry_or_build(self):
        result, calls = self.build(HELM_FAIL="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(name in ("git", "oci", "podman") for name, _ in calls))

    def test_wrong_application_major_is_rejected(self):
        result, calls = self.build(TEST_APP="3.224.1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must resolve to a Langfuse v4 appVersion", result.stderr)
        self.assertFalse(any(name == "podman" for name, _ in calls))

    def test_wrong_chart_major_is_rejected(self):
        result, calls = self.build(TEST_CHART="1.5.41")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(name == "helm" for name, _ in calls))

    def test_changed_openid_major_stops_before_image_build(self):
        result, calls = self.build(OPENID_VERSION="6.0.0")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Review the patch before building", result.stderr)
        self.assertFalse(any(name == "podman" and args[0] == "build" for name, args in calls))

    def test_changed_transport_stops_before_image_build(self):
        result, calls = self.build(BAD_TRANSPORT="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("review redirect patch", result.stderr)
        self.assertFalse(any(name == "podman" and args[0] == "build" for name, args in calls))


if __name__ == "__main__":
    unittest.main()
