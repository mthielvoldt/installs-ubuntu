# Unused options from Anthropic's sandbox-runtime (SRT)
https://github.com/anthropic-experimental/sandbox-runtime v0.0.39

## Extracted how?
- Add to src/sandbox/linux-sandbox-utils.tx: 
    "logForDebugging(`Sandbox Linux] wrappedCommand ${wrappedCommand}`)" 
    before line: "return wrappedCommand"
- npm install
- npm run build
- cd dist
- export SRT_DEBUG=1
- cli.js bash

## Options
```
--bind /tmp/claude-socks.sock /tmp/claude-socks.sock \
--tmpfs /etc/ssh/ssh_config.d \
--setenv ALL_PROXY socks5h\://localhost\:1080 \
--setenv all_proxy socks5h\://localhost\:1080 \
--setenv FTP_PROXY socks5h\://localhost\:1080 \
--setenv ftp_proxy socks5h\://localhost\:1080 \
--setenv RSYNC_PROXY localhost\:1080 \
--setenv GRPC_PROXY socks5h\://localhost\:1080 \
--setenv grpc_proxy socks5h\://localhost\:1080 \
--setenv CLAUDE_CODE_HOST_SOCKS_PROXY_PORT 46465 \
--setenv DOCKER_HTTP_PROXY http\://localhost\:3128 \
--setenv DOCKER_HTTPS_PROXY http\://localhost\:3128 \
--setenv CLOUDSDK_PROXY_TYPE https \
--setenv CLOUDSDK_PROXY_ADDRESS localhost \
--setenv CLOUDSDK_PROXY_PORT 3128 \
```

## Unused sandboxed command line
```
socat TCP-LISTEN:1080,fork,reuseaddr UNIX-CONNECT:/tmp/claude-socks.sock >/dev/null 2>&1 &
```
