"""Run the registry bootstrap with isolated paths and mocked package commands."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / "modules/oke/cloud_init_script/scripts/docker-credential-helper-init.sh"


class CliBootstrapTest(unittest.TestCase):
    def run_bootstrap(self, major, *, installed=False, fail_install=False):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "bin").mkdir()
            (root / "os-release").write_text(f'ID="ol"\nVERSION_ID="{major}.0"\n')
            source = SCRIPT.read_text().replace("/etc/os-release", str(root / "os-release"))
            for path in ("/usr/local/bin", "/var/lib/kubelet", "/root/.docker"):
                source = source.replace(path, str(root / path.lstrip("/")))
            (root / "bootstrap.sh").write_text(source)
            commands = {
                "oci": '#!/bin/bash\n[ -f "$TEST_ROOT/installed" ]\n',
                "dnf": '''#!/bin/bash
printf '%s\\n' "$*" >> "$TEST_ROOT/packages"
[ "$FAIL_INSTALL" = 0 ] || exit 1
case "$*" in
  "-y install oraclelinux-developer-release-el$TEST_MAJOR") ;;
  "-y install $TEST_CLI_PACKAGE") touch "$TEST_ROOT/installed" ;;
  *) exit 1 ;;
esac
''',
            }
            for name, content in commands.items():
                command = root / "bin" / name
                command.write_text(content)
                command.chmod(0o755)
            login = root / "usr/local/bin/docker_login.sh"
            login.parent.mkdir(parents=True)
            login.write_text('#!/bin/bash\ntouch "$TEST_ROOT/login-called"\n')
            login.chmod(0o755)
            if installed:
                (root / "installed").touch()
            env = dict(os.environ, PATH=f'{root / "bin"}:{os.environ["PATH"]}',
                       TEST_ROOT=str(root), TEST_MAJOR=str(major),
                       TEST_CLI_PACKAGE="python39-oci-cli" if major == 9 else "python36-oci-cli",
                       FAIL_INSTALL="1" if fail_install else "0")
            result = subprocess.run(["bash", str(root / "bootstrap.sh")], env=env,
                                    capture_output=True, text=True)
            packages = (root / "packages").read_text() if (root / "packages").exists() else ""
            return result, packages, (root / "login-called").exists()

    def test_ol9_installs_cli_before_login(self):
        result, packages, logged_in = self.run_bootstrap(9)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("python39-oci-cli", packages)
        self.assertTrue(logged_in)

    def test_ol8_installs_cli_before_login(self):
        result, packages, logged_in = self.run_bootstrap(8)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("python36-oci-cli", packages)
        self.assertNotIn("el9", packages)
        self.assertTrue(logged_in)

    def test_existing_cli_skips_install(self):
        result, packages, logged_in = self.run_bootstrap(9, installed=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(packages, "")
        self.assertTrue(logged_in)

    def test_install_failure_prevents_login(self):
        result, _, logged_in = self.run_bootstrap(9, fail_install=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(logged_in)

    def test_unsupported_release_prevents_install(self):
        result, packages, logged_in = self.run_bootstrap(10)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(packages, "")
        self.assertFalse(logged_in)


if __name__ == "__main__":
    unittest.main()
