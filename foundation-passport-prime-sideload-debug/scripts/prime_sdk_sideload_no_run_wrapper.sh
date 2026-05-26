#!/usr/bin/env bash
set -euo pipefail

app_dir="${1:?usage: prime_sdk_sideload_no_run_wrapper.sh /path/to/app /mount/path}"
mount_path="${2:?usage: prime_sdk_sideload_no_run_wrapper.sh /path/to/app /mount/path}"

export PATH="$HOME/.foundation/sdk/current/bin:$HOME/.foundation/sdk/bin:$PATH"
cd "$app_dir"
exec "$HOME/.foundation/sdk/current/bin/foundation" sideload --mount-path "$mount_path" --no-run
