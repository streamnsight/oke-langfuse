# Langfuse image builds

`langfuse_helm_chart_version` selects the source script automatically:

| Helm chart | Langfuse application | Source script |
| --- | --- | --- |
| 1.x | v3 | `scripts/build_langfuse_image.sh` (existing builder) |
| 2.x | v4 | `scripts/build_langfuse_image_v4.sh` |

Unsupported chart majors are rejected rather than silently assigned to a builder.
The root module passes its chart-version setting to this module. OCI DevOps still
receives the selected content as `build_langfuse_image.sh`, so the artifact path,
command spec and remote entry point stay stable.

The v4 script checks that builder metadata specifies chart 2.x and resolves a
v4 `appVersion` from that chart. That application version drives the source tag
and both OCIR image tags; the chart version is not used as an application tag.
The script preserves upstream dependency patches, checks the resolved
`openid-client` major and transport layout before patching, and keeps the
`/langfuse` build-time base path. Existing images are reused per component.

The v4 source installation uses the builder's Node/pnpm tooling, which must
satisfy the selected application's engines. Root builder setup currently
installs Node 24. A full v4 image build and IDCS/browser validation remain
required before declaring the v4 deployment supported.

Run the isolated tests from the repository root:

```sh
python3 tests/langfuse_build/test_build_scripts.py
```

These execute the Terraform selector and shell control flow with mocked OCI,
Helm, Git, pnpm and Podman commands. They do not build or publish real images.
