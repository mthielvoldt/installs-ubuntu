# MGT Aliases below
alias saleae='~/Downloads/squashfs-root/Logic --no-sandbox'
alias lssubmodules='find -mindepth 1 -maxdepth 4 -type d -exec [ -d {}/.git ] \; -prune -print | tee /dev/tty | wc -l'
alias addsubmodules='find -mindepth 1 -maxdepth 4 -type d -exec [ -d {}/.git ] \; -prune -print \
  | while read -r MODULE_PATH; do 
    cd $MODULE_PATH
    MODULE_URL=$(git remote get-url $(git remote))
    cd - >/dev/null
    echo "git submodule add $MODULE_URL $MODULE_PATH"
  done '
alias zephcomm='picocom /dev/ttyACM0 -b 115200'
alias tcom='curl http://httpbin.org/ip'

export MGT_ALIASES=y
