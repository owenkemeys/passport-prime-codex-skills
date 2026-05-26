#!/usr/bin/env bash
set -euo pipefail

app_dir="${1:?usage: prime_sdk_build_wrapper.sh /path/to/app}"

export PATH="$HOME/.foundation/sdk/current/bin:$HOME/.foundation/sdk/bin:$PATH"
cd "$app_dir"
exec "$HOME/.foundation/sdk/current/bin/foundation" build
