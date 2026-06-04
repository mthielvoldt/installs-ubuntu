# MGT Aliases below
alias addsubmodules='find -mindepth 1 -maxdepth 4 -type d -exec [ -d {}/.git ] \; -prune -print \
  | while read -r MODULE_PATH; do 
    cd $MODULE_PATH
    MODULE_URL=$(git remote get-url $(git remote))
    cd - >/dev/null
    echo "git submodule add $MODULE_URL $MODULE_PATH"
  done '
alias arduino='~/Downloads/arduino-ide_2.3.8_Linux_64bit/arduino-ide'
alias lssubmodules='find -mindepth 1 -maxdepth 4 -type d -exec [ -d {}/.git ] \; -prune -print | tee /dev/tty | wc -l'
alias saleae='~/Downloads/squashfs-root/Logic --no-sandbox'
alias sbox='~/installs/sbox/sbox.sh'
alias tcom='curl https://httpbin.org/ip'
alias zephcomm='picocom /dev/ttyACM0 -b 115200'

export MGT_ALIASES=y
