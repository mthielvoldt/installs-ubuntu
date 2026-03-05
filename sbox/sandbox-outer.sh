#!/bin/bash
# sandbox-outer.sh - Runs inside outer user NS (has CAP_SYS_ADMIN)
# Do not call directly.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Launch inner net NS shell in background
bash "$SCRIPT_DIR/sandbox-inner.sh" &

# Wait for inner shell to write its PID
while [ ! -s "$INNER_PID_FILE" ]; do sleep 0.1; done
INNER_PID=$(cat "$INNER_PID_FILE")
echo "[sandbox] Inner net NS PID: $INNER_PID"

# Launch slirp from here — we are in host net NS so slirp
# has outbound connectivity, but CAP_SYS_ADMIN lets it
# attach to the inner net NS
slirp4netns \
  --configure \
  --mtu=65520 \
  --disable-host-loopback \
  --ready-fd=9 \
  "$INNER_PID" tap0 9>>"$SLIRP_READY" &
SLIRP_PID=$!

wait
kill "$SLIRP_PID" 2>/dev/null || true