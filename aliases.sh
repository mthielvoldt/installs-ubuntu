alias lssubmodules='find -mindepth 1 -maxdepth 4 -type d -exec [ -d {}/.git ] \; -prune -print | tee | wc -l'
alias addsubmodules='find -mindepth 1 -maxdepth 4 -type d -exec [ -d {}/.git ] \; -prune -print \
  | while read -r MODULE_PATH; do 
    cd $MODULE_PATH
    MODULE_URL=$(git remote get-url $(git remote))
    cd - >/dev/null
    echo "git submodule add $MODULE_URL $MODULE_PATH"
  done '

alias zephcomm='picocom /dev/ttyACM0 -b 115200'

export MGT_ALIASES=y
