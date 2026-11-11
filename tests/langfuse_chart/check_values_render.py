"""Check OKE images and gateway access with local chart 1.x and 2.x archives."""
import re
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

import yaml

ROOT = Path(__file__).resolve().parents[2]
VALUES = ROOT / "modules/apps/langfuse/helm_chart/values.template.yaml"
SUBSTITUTIONS = {
    "REGION": "us-chicago-1", "TENANCY_NAMESPACE": "example", "DEPLOY_ID": "test",
    "LANGFUSE_PROTOCOL": "https", "LANGFUSE_HOSTNAME": "langfuse.example.invalid",
    "REDIS_HOSTNAME": "redis.example.invalid", "LANGFUSE_OBJECT_STORAGE_BUCKET": "test",
}


def render(chart, values, directory):
    path = directory / "values.yaml"
    path.write_text(yaml.safe_dump(values))
    result = subprocess.run(["helm", "template", "langfuse", str(chart), "--namespace", "langfuse",
                             "-f", str(path), "--set", "clickhouse.crdCheck=false"],
                            capture_output=True, text=True, check=True)
    return [doc for doc in yaml.safe_load_all(result.stdout) if doc]


def image_names(value):
    if isinstance(value, dict):
        for key, item in value.items():
            if key == "image" and isinstance(item, str):
                yield item
            else:
                yield from image_names(item)
    elif isinstance(value, list):
        for item in value:
            yield from image_names(item)


if len(sys.argv) != 3:
    raise SystemExit("Usage: python3 check_values_render.py chart-1.x.tgz chart-2.x.tgz")

with tempfile.TemporaryDirectory() as directory:
    for major, argument in enumerate(sys.argv[1:], 1):
        chart = Path(argument).resolve()
        with tarfile.open(chart) as archive:
            metadata = yaml.safe_load(archive.extractfile("langfuse/Chart.yaml").read())
        assert metadata["version"].startswith(f"{major}.")
        substitutions = dict(SUBSTITUTIONS, LANGFUSE_IMAGE_TAG="3.224.1" if major == 1 else "4.77.0")
        text = re.sub(r"\$\{([^}]+)\}", lambda match: substitutions[match[1]], VALUES.read_text())
        values = yaml.safe_load(text)
        rendered = render(chart, values, Path(directory))
        gateway_workloads = set()
        for doc in rendered:
            if doc["kind"] == "Deployment" and doc["metadata"]["name"] in ("langfuse-web", "langfuse-worker"):
                containers = doc["spec"]["template"]["spec"]["containers"]
                entries = [env for env in containers[0].get("env", [])
                           if env["name"] == "LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST"]
                assert entries == [{"name": "LANGFUSE_LLM_CONNECTION_WHITELISTED_HOST", "value": "oci-genai-gateway"}]
                pod = doc["spec"]["template"]["spec"]
                assert pod["serviceAccountName"] == "langfuse"
                assert pod["automountServiceAccountToken"] is True
                env = containers[0]["env"]
                for name, value in {
                    "LANGFUSE_USE_OCI_NATIVE_OBJECT_STORAGE": "true",
                    "LANGFUSE_OCI_AUTH_TYPE": "workload_identity",
                }.items():
                    assert [item for item in env if item["name"] == name] == [{"name": name, "value": value}]
                for kind in ("EVENT_UPLOAD", "MEDIA_UPLOAD", "BATCH_EXPORT"):
                    name = f"LANGFUSE_S3_{kind}_ENDPOINT"
                    assert [item for item in env if item["name"] == name] == [{
                        "name": name, "value": "https://objectstorage.us-chicago-1.oraclecloud.com"}]
                    assert not any(item["name"] in (
                        f"LANGFUSE_S3_{kind}_ACCESS_KEY_ID", f"LANGFUSE_S3_{kind}_SECRET_ACCESS_KEY")
                        for item in env)
                assert not any("langfuse-s3" in str(item) for item in env)
                gateway_workloads.add(doc["metadata"]["name"])
        assert gateway_workloads == {"langfuse-web", "langfuse-worker"}
        if major == 1:
            # These are v2-specific keys; adding them must not change v1 images.
            del values["clickhouse"]["cluster"]
            del values["clickhouse"]["keeper"]
            baseline = render(chart, values, Path(directory))
            assert sorted(image_names(rendered)) == sorted(image_names(baseline))
        else:
            expected = {"ClickHouseCluster": "docker.io/clickhouse/clickhouse-server",
                        "KeeperCluster": "docker.io/clickhouse/clickhouse-keeper"}
            found = set()
            for doc in rendered:
                if doc["kind"] in expected:
                    assert doc["spec"]["containerTemplate"]["image"]["repository"] == expected[doc["kind"]]
                    found.add(doc["kind"])
            assert found == set(expected)
        print(f'Chart {metadata["version"]}: image, gateway allowlist and OCI workload identity checks passed.')
