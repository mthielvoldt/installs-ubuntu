#!/bin/bash
# sandbox-outer.sh - Runs inside outer user NS (has CAP_SYS_ADMIN)
# Do not call directly.

set -euo pipefail
# enable job control 
set -m

# Launch inner net NS shell in background, to be brought FG soon.
unshare --net bash sandbox-inner.sh &

# Wait for inner shell to write its PID
count=0
while [[ ! -s "$INNER_PID_FILE" && $count -lt "5" ]]; do 
  echo "[sandbox] waiting for inner"
  sleep 0.1;
  count=$((count + 1))
done
if [[ $count -ge "5" ]]; then
  echo "[sandbox] inner not reporting PID - Aborting."
  kill -9 %1
  exit 1
fi

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

fg %1
kill "$SLIRP_PID" 2>/dev/null || true