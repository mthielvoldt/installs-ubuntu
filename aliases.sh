# MGT Aliases below
MGT_ALIASES_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
export STPROG="$HOME/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/STM32_Programmer_CLI"
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
alias sbox="$MGT_ALIASES_DIR/sbox/sbox.sh"
alias tcom='curl https://httpbin.org/ip'
alias zephcomm='picocom /dev/ttyACM0 -b 115200'
alias stprog='./generate && $STPROG -c port=SWD -d build/combined.bin 0x08000000 -rst'
alias streset='$STPROG -c port=SWD -rst'
alias stflashassets='$STPROG -c port=SWD -d build/TSDHD-TSS013-1-assets.bin 0xA0000000 -el "$HOME/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/ExternalLoader/TSDHD-TSS013-1.stldr" -rst'
alias stflashassetsB='$STPROG -c port=SWD -d build/TSDHD-TSS013-1-assets.bin 0xA0380000 -el "$HOME/STMicroelectronics/STM32Cube/STM32CubeProgrammer/bin/ExternalLoader/TSDHD-TSS013-1.stldr" -rst'
alias batt='cat /sys/class/power_supply/BAT0/uevent'

export MGT_ALIASES=y
