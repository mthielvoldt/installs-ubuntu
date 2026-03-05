#!/bin/bash
# sandbox-inner.sh - Runs inside inner net NS
# Do not call directly.

set -euo pipefail

# Enter a new net NS and re-exec this script's body
# (called via unshare from sandbox-outer.sh)
unshare --net bash -c '
  echo $$ > "$INNER_PID_FILE"

  # Wait for slirp to signal ready
  while [ ! -s "$SLIRP_READY" ]; do sleep 0.1; done
  echo "[sandbox] Network ready, starting sandbox..."

  exec bwrap \
    --ro-bind / / \
    --dev /dev \
    --proc /proc \
    --tmpfs /tmp \
    --tmpfs /run \
    --ro-bind "$RESOLV_CONF" /etc/resolv.conf \
    --share-net \
    --new-session \
    --die-with-parent \
    -- $COMMAND
'