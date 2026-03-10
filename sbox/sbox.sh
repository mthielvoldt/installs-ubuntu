#!/usr/bin/env bash

## initializeLinuxNetworkBridge
httpSocketPath="/tmp/claude-http.sock"
outerProxyPort=8888
innerProxyPort=3128

cleanup() {
  echo "Picking up socks left by tiny and the sock cat."
  kill %1 %2 2>/dev/null
  sleep 0.1
  echo >> tmp/tinyproxy.log
  jobs
}

mkdir -p tmp
envsubst < tinyproxy.conf.in > tmp/tinyproxy.conf 
tinyproxy -d -c tmp/tinyproxy.conf &

# Use -v to see data. 
socat \
  UNIX-LISTEN:$httpSocketPath,fork,reuseaddr \
  TCP:localhost:$outerProxyPort,keepalive,keepidle=10,keepintvl=5,keepcnt=3 &

# --new-session \

/usr/bin/bwrap \
  --die-with-parent \
  --unshare-net \
  --unshare-pid \
  --ro-bind /usr /usr \
  --symlink /usr/lib64 /lib64 \
  --ro-bind /etc/alternatives etc/alternatives \
  --ro-bind /etc/ssl/certs /etc/ssl/certs \
  --ro-bind /bin /bin \
  --ro-bind $HOME/.local $HOME/.local \
  --ro-bind $HOME/.bashrc $HOME/.bashrc \
  --bind $HOME/.npm/_logs $HOME/.npm/_logs \
  --bind $HOME/.claude $HOME/.claude \
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
  --dev /dev \
  --proc /proc \
  --chdir $PWD \
  -- /usr/bin/bash -c "/usr/bin/bash -c '
    socat TCP-LISTEN:$innerProxyPort,fork,reuseaddr UNIX-CONNECT:$httpSocketPath >/dev/null 2>&1 &
    trap \"kill %1 2>/dev/null; exit\" EXIT
    /home/mike/repos/play/sandbox-runtime/vendor/seccomp/x64/apply-seccomp /home/mike/repos/play/sandbox-runtime/vendor/seccomp/x64/unix-block.bpf 
    /usr/bin/bash -c bash'"

cleanup
## The following are options used in 