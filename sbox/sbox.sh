#!/usr/bin/env bash

export thisDir=$(dirname $(readlink -f "$0"))
export tmp=$thisDir/tmp
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

envsubst < $thisDir/tinyproxy.conf.in > $tmp/tinyproxy.conf 
tinyproxy -d -c $tmp/tinyproxy.conf &

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
  --ro-bind $HOME/installs/aliases.sh $HOME/installs/aliases.sh \
  --ro-bind $HOME/.nvm/versions/node/v24.14.0 $HOME/.nvm/versions/node/v24.14.0 \
  --ro-bind $HOME/.local/bin $HOME/.local/bin \
  --bind    $HOME/.local/share/claude $HOME/.local/share/claude \
  --bind    $HOME/.claude $HOME/.claude \
  --bind    $HOME/.claude.json $HOME/.claude.json \
  --ro-bind $HOME/.bashrc $HOME/.bashrc \
  --ro-bind $HOME/.espressif $HOME/.espressif \
  --ro-bind $thisDir/inner.sh $thisDir/inner.sh \
  --bind $HOME/.npm/_logs $HOME/.npm/_logs \
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


cleanup
