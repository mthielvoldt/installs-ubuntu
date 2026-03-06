#/bin/bash

set -euo pipefail

ls -la $INNER_PID_FILE
echo $$ > $INNER_PID_FILE
echo "nameserver 10.0.2.3" > /tmp/slirp-resolv.conf

# Wait for slirp to signal ready
while [ ! -s "$SLIRP_READY" ]; do 
  echo "[sandbox] waiting for slirp"
  sleep 0.1;
done
echo "[sandbox] Network ready, starting sandbox..."
echo "COMMAND $COMMAND"

bwrap \
  --ro-bind /usr /usr \
  --symlink usr/lib64 /lib64 \
  --ro-bind /etc/ssl/certs /etc/ssl/certs \
  --ro-bind /tmp/slirp-resolv.conf /etc/resolv.conf \
  --dev /dev \
  --proc /proc \
  --tmpfs /tmp \
  --share-net \
  --die-with-parent \
  --  $COMMAND "$@"
