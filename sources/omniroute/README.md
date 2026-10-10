# OmniRoute container

Upstream is pinned to `v3.8.1` in `vars.sh`; patches are applied in filename order before the container build.

## Claude Code client version

Patch `0009-add-claude-client-version-override.patch` backports the runtime version override from upstream `v3.8.51` (commit `c1e30b7676`, issue #12417), with `2.1.181` as the default instead of the newer upstream pin.

`CLAUDE_CODE_CLIENT_VERSION=2.1.182` overrides the advertised version without rebuilding the image. The setting is read at request time and applies to native Claude OAuth messages, bootstrap, quota requests, and CC-compatible bridge User-Agent and billing blocks. Container environment changes require recreating the container.

The patch also connects the configured CC bridge `inject_billing_header` operations to the live executor path before body signing; `v3.8.1` otherwise only runs them in the separate signed-request helper. Bridge billing normalization depends on that pipeline being enabled. Other prompt-transform operations are not newly enabled by this backport.

Unset, empty, or unsafe values fall back to `2.1.181`. The upstream safe-token validation is retained: 1–32 ASCII letters, digits, dots, underscores, or hyphens, starting with a letter or digit. An explicit billing-transform `version` still takes precedence over the environment.

`CLAUDE_CODE_VERSION` is an exported pin, not an environment setting. The backport retains the existing SDK versions and billing suffix algorithms; it does not install or upgrade the Claude Code CLI, or add `CLAUDE_CODE_CLIENT_BUILD_REVISION` support. Other provider-specific identity profiles are unchanged.
