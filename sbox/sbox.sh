#!/usr/bin/env bash

export thisDir=$(dirname $(readlink -f "$0"))
export tmp="/tmp/sbox"
export outerProxyPort=8888
httpSocketPath="/tmp/claude-http.sock"
innerProxyPort=3128

cleanup() {
  echo "goodbye tiny and outer sock cat"
  kill %1 %2 2>/dev/null
  sleep 0.1
  echo >> $tmp/tinyproxy.log
  jobs
}

mkdir -p $tmp
if [ ! -e $tmp/inner-socat-err.log ]; then
  touch $tmp/inner-socat-err.log
fi

echo "127.0.0.1 localhost" > $tmp/hosts
mapfile -t domains < "$thisDir/tinyproxy.filter"
for domain in "${domains[@]}"; do
  echo "$(dig +short $domain | head -n 1) $domain" >> $tmp/hosts
done

if ! systemctl is-active --quiet tinyproxy.service; then
    echo "⚠️  Error: tinyproxy.service is not running!"
    echo "Please start it manually with: sudo systemctl start tinyproxy.service"
    exit 1
fi

envsubst < $thisDir/tinyproxy.conf.in > $tmp/tinyproxy.conf
if ! cmp -s $tmp/tinyproxy.conf /etc/tinyproxy/tinyproxy.conf; then 
  echo "tinyproxy.conf stale.  Updating (sudo) ."
  sudo install -o root -g root -m 644 $tmp/tinyproxy.conf /etc/tinyproxy/tinyproxy.conf
  updated_tinyproxy='y'
fi
if ! cmp -s $thisDir/tinyproxy.filter /etc/tinyproxy/sbox.filter; then
  echo "Tinyproxy filter stale. Updating (sudo)."
  sudo install -o root -g root -m 644 $thisDir/tinyproxy.filter /etc/tinyproxy/sbox.filter
  updated_tinyproxy='y'
fi
if [ -v updated_tinyproxy ]; then
  sudo systemctl restart tinyproxy.service
  sudo -k
  echo "🔒 Sudo session cleared."
fi

# Use -v to see data. 
socat \
  UNIX-LISTEN:$httpSocketPath,fork,reuseaddr \
  TCP:localhost:$outerProxyPort,keepalive,keepidle=10,keepintvl=5,keepcnt=3 >$tmp/outer-socat.log 2>$tmp/outer-socat-err.log &

echo "Waiting for socat to create socket..."
until [ -e "$httpSocketPath" ]; do
  sleep 0.1
done

echo "Launching sandbox"
/usr/bin/bwrap \
  --die-with-parent \
  --new-session \
  --unshare-net \
  --unshare-pid \
  --ro-bind /usr /usr \
  --symlink /usr/lib64 /lib64 \
  --ro-bind /etc/alternatives etc/alternatives \
  --ro-bind /etc/ssl/certs /etc/ssl/certs \
  --ro-bind /lib /lib \
  --ro-bind $tmp/hosts /etc/hosts \
  --bind $tmp/inner-socat-err.log /var/log/socat-err.log \
  --ro-bind /bin /bin \
  --ro-bind $thisDir/../aliases.sh $thisDir/../aliases.sh \
  --bind    $HOME/.claude $HOME/.claude \
  --bind    $HOME/.claude.json $HOME/.claude.json \
  --ro-bind $HOME/.bashrc $HOME/.bashrc \
  --ro-bind $HOME/.espressif $HOME/.espressif \
  --bind $httpSocketPath $httpSocketPath \
  --bind $PWD $PWD \
  --setenv SANDBOX_RUNTIME 1 \
  --setenv TMPDIR /tmp/claude \
  --setenv NO_PROXY localhost\,127.0.0.1\,\:\:1\,\*.local\,.local\,169.254.0.0/16\,10.0.0.0/8\,172.16.0.0/12\,192.168.0.0/16 \
  --setenv no_proxy localhost\,127.0.0.1\,\:\:1\,\*.local\,.local\,169.254.0.0/16\,10.0.0.0/8\,172.16.0.0/12\,192.168.0.0/16 \
  --setenv HTTP_PROXY http\://localhost\:$innerProxyPort \
  --setenv HTTPS_PROXY http\://localhost\:$innerProxyPort \
  --setenv http_proxy http\://localhost\:$innerProxyPort \
  --setenv https_proxy http\://localhost\:$innerProxyPort \
  --setenv CLAUDE_CODE_HOST_HTTP_PROXY_PORT $innerProxyPort \
  --setenv NODE_USE_ENV_PROXY 1 \
  --dev /dev \
  --proc /proc \
  --chdir $PWD \
  -- /usr/bin/bash -c "
    socat TCP-LISTEN:$innerProxyPort,fork,reuseaddr UNIX-CONNECT:$httpSocketPath >/dev/null 2>/var/log/socat-err.log &
    trap \"echo goodbye inner sock cat; kill %1 2>/dev/null; exit\" EXIT
    \"$@\"" -- "$@"

# >/dev/null 2>&1

# -- /usr/bin/bash -c '
#     socat TCP-LISTEN:$innerProxyPort,fork,reuseaddr UNIX-CONNECT:$httpSocketPath >/dev/null 2>&1 &
#     trap "kill %1 2>/dev/null; exit" EXIT 
#     "$@"' -- "$@"

# apply-seccomp block-unix-sockets.bpf "$@"' -- "$@"

## Unused options
#  --ro-bind $HOME/.nvm/versions/node/v24.14.0 $HOME/.nvm/versions/node/v24.14.0 \
#  --ro-bind $HOME/.local/bin $HOME/.local/bin \
#  --bind $HOME/.npm/_logs $HOME/.npm/_logs \


cleanup
