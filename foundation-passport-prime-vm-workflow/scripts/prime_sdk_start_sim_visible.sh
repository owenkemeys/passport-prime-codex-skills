#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: prime_sdk_start_sim_visible.sh /path/to/run-sim-visible.sh [app-id]

Starts nested Weston for Foundation Passport Prime simulator review, maximizes
the Weston host window through Openbox, then runs the supplied simulator wrapper
inside the Foundation SDK Nix shell.

Use after the user has approved the build/restart/test loop, unless they already
asked for the full loop in their prompt.

Environment:
  DISPLAY              X display to use, default :0
  XDG_RUNTIME_DIR      runtime dir, default /run/user/$(id -u)
  WAYLAND_SOCKET       Weston socket name, default wayland-1
  WESTON_WIDTH         initial Weston width before maximize, default 1600
  WESTON_HEIGHT        initial Weston height before maximize, default 900
USAGE
}

run_wrapper="${1:-}"
app_id="${2:-}"
if [ -z "$run_wrapper" ] || [ "$run_wrapper" = "-h" ] || [ "$run_wrapper" = "--help" ]; then
  usage
  exit 2
fi

display="${DISPLAY:-:0}"
runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
wayland_socket="${WAYLAND_SOCKET:-wayland-1}"
weston_width="${WESTON_WIDTH:-1600}"
weston_height="${WESTON_HEIGHT:-900}"
log_path="${FOUNDATION_SIM_LOG:-$HOME/foundation-sim.log}"

pkill -f "foundation sim" 2>/dev/null || true
pkill -f "/keyos/simulator/" 2>/dev/null || true
if [ -n "$app_id" ]; then
  pkill -f "target/apps/$app_id/app.elf" 2>/dev/null || true
fi
pkill -f "weston --backend=x11-backend.so" 2>/dev/null || true
sleep 1

mkdir -p "$HOME/.config"
cat > "$HOME/.config/weston.ini" <<'CFG'
[core]
idle-time=0

[shell]
locking=false
background-color=0xff3a3a3a
CFG

DISPLAY="$display" XDG_RUNTIME_DIR="$runtime_dir" nohup weston \
  --backend=x11-backend.so \
  --socket="$wayland_socket" \
  --width="$weston_width" \
  --height="$weston_height" \
  --idle-time=0 \
  > "$HOME/weston.log" 2>&1 &
sleep 2

# Weston is a normal Openbox/X11 window here. Maximize that host window, just
# like clicking its titlebar maximize button; do not use `weston --fullscreen`,
# which can leave a stale small compositor viewport inside a large black area.
if command -v xdotool >/dev/null 2>&1; then
  weston_window=""
  for _ in {1..20}; do
    weston_window="$(DISPLAY="$display" xdotool search --onlyvisible --class "Weston Compositor" 2>/dev/null | head -n 1 || true)"
    [ -n "$weston_window" ] && break
    sleep 0.25
  done

  if [ -n "$weston_window" ]; then
    eval "$(DISPLAY="$display" xdotool getwindowgeometry --shell "$weston_window")"
    title_x=$((X + WIDTH / 2))
    title_y=$((Y - 30))
    [ "$title_y" -lt 10 ] && title_y=10
    DISPLAY="$display" xdotool mousemove "$title_x" "$title_y" click --repeat 2 --delay 100 1
    sleep 1
  fi
fi

rm -f "$log_path"
source /etc/profile.d/nix.sh
cd "$HOME/.foundation/sdk/current"

nohup nix develop --command "$run_wrapper" > "$log_path" 2>&1 &
sim_pid="$!"
echo "$sim_pid" > "${log_path%.log}.pid"
