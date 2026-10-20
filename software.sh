#!/bin/bash
set -e

echo "Installing system software.  Press:
  'a' for apt utilities (tree...)
  'A' Arduino
  'b' build tools
  'c' cmake
  'C' Chrome browser
  'd' for Dropbox
  'D' for Docker Desktop
  'g' git (latest)
  'h' home mods
  'L' Claude
  'n' node.js v24 (to change node version, edit NODE_VERSION)
  's' ssh key
  'u' for user/udev setup (groups)
  'v' for Visual Studio Code
"
# Read single character (-n 1) silently (-s), without Enter (-r), 
# into the 'confirm' variable.
read -n 1 -r -s confirm
echo ""
if [[ "$confirm" == "" ]] ; then
    echo "Aborting. Nothing Installed."
    exit 0
fi

CALL_DIR=$(pwd)
SCRIPT_DIR=$( cd -- $( dirname $0 ) &> /dev/null && pwd )
APT_SOURCES_DIR="/etc/apt/sources.list.d"
KEYRING_DIR="/usr/share/keyrings"

export DPKG_ARCH=$(dpkg --print-architecture)
# Get the version code of this ubuntu (bionic, focal, jammy, noble)
. /etc/os-release
export VERSION_CODENAME
export NODE_VERSION=24

# -- User/udev setup --
if [ "$confirm" == "u" ]; then
    if [[ $USER == "root" ]]; then
        echo "Script run as root.  Restart as your normal user."
        exit -1
    fi

    if [[ $(groups) != *"dialout"* ]]; then
        sudo usermod -a -G dialout $USER
        user_modified="y"
    fi

    if [[ $(groups) != *"tinyproxy"* ]]; then
        sudo usermod -a -G tinyproxy $USER
        user_modified="y"
    fi
    
    if [ -d "$HOME/STMicroelectronics/STM32Cube/STM32CubeProgrammer" ]; then
        echo -e "[software.sh] Installing STM32 rules to /etc/udev/rules.d..."
        sudo install -o root -g root -m 644 -t /etc/udev/rules.d \
            $HOME/STMicroelectronics/STM32Cube/STM32CubeProgrammer/Drivers/rules/*.rules
    fi

    if [[ $user_modified == "y" ]]; then
        echo "User added to groups, re-login required.";
    fi
fi

# -- Generic utilities from apt --
if [ "$confirm" == "a" ]; then
    echo -e "\n[software.sh] Installing apt utilities..."
    sudo apt update
    sudo apt install tree python3-venv mpv curl libcap-dev ripgrep tinyproxy rclone
    # ripgrep: faster recursive grep, doesn't search .gitignore'd files. 
    # libcap-dev: bubblewrap compile dependency
    # slirp4netns: for making host networks available to a sandbox
    # bubblewrap: for sandboxing
    # mpv: a performant movie player with wayland compatability
    # tinyproxy: an http proxy, used in sbox
    
    if [[ ! -f /etc/apparmor.d/bwrap ]]; then
        echo "[software.sh] Creating appArmor profiles..."
        sudo install -D -o root -g root -m 644 -t /etc/apparmor.d apparmor.d/*
        echo "[software.sh] Reloading apparmor service..."
        sudo systemctl reload apparmor
    fi
fi

# Arduino
if [ "$confirm" == "A" ]; then
    if find $HOME/Downloads -maxdepth 1 -type d -name "arduino-ide*" | grep -q .; then 
        echo -e "\n[software.sh] Arduino ide already installed"
    else
        DEST_DIR=$HOME/Downloads
        echo -e "\n[software.sh] Downloading Arduino IDE to $DEST_DIR"
        ARDUINO_NAME=arduino-ide_2.3.8_Linux_64bit
        ARDUINO_ZIP="$DEST_DIR/arduino-cli.zip"
        echo -e "\n[software.sh] Installing arduino cli..."
        wget -O $ARDUINO_ZIP https://downloads.arduino.cc/arduino-ide/$ARDUINO_NAME.zip
        unzip $ARDUINO_ZIP -d $DEST_DIR
        mv $DEST_DIR/$ARDUINO_NAME/chrome-sandbox{,.original}
        sudo cp -p /opt/google/chrome/chrome-sandbox $DEST_DIR/$ARDUINO_NAME/
        rm $ARDUINO_ZIP
    fi
fi

# -- Create ~/bin if not there --
if [ "$confirm" == "h" ]; then
    if [ ! -d "$HOME/bin" ]; then
        echo -e "\n[software.sh] Creating ~/bin"
        mkdir -p "$HOME/bin"
        export PATH="$HOME/bin:$PATH"
    fi
    if [[ ! $MGT_ALIASES ]]; then
        echo -e "\n[software.sh] Adding 'source $SCRIPT_DIR/aliases.sh' to ~/.bashrc"
        echo -e "\n# MGT Aliases\nsource $SCRIPT_DIR/aliases.sh" >> ~/.bashrc
    fi
fi

# -- Dropbox --
if [ "$confirm" == "d" ]; then
    
    if [ ! -d "$HOME/.dropbox-dist" ]; then
        echo -e "\n[software.sh] Installing Dropbox daemon into ~/.dropbox-dist/ ..."
        cd $HOME
        wget -O - "https://www.dropbox.com/download?plat=lnx.x86_64" | tar xzf -
        cd $CALL_DIR
    else
        echo -e "\n[software.sh] Dropbox already installed."
    fi

    if [ ! -f "$HOME/.config/systemd/user/dropbox.service" ]; then
        echo -e "\n[software.sh] Creating systemd user service, and starting daemon..."
        cp dropbox.service $HOME/.config/systemd/user/
    	echo -e "\n[software.sh] Drdopbox will ask you to sign in if it's the first time."
    	systemctl --user daemon-reload
        systemctl --user enable dropbox.service
        systemctl --user start dropbox.service
    fi    
fi

# -- Git from ppa (because github hosted runner ubuntu-latest has the latest git, apt does not.)
if [ "$confirm" == "g" ]; then
    echo -e "\n[software.sh] Installing git from PPA..."
    sudo add-apt-repository ppa:git-core/ppa
    sudo apt update
    sudo apt install git
    git config --global user.email "mthielvoldt@gmail.com"
    git config --global user.name "Mike Thielvoldt"
fi

# -- Ssh key (for github) --
if [ "$confirm" == "s" ]; then
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        echo -e "\n[software.sh] Generating ssh key for mthielvoldt@gmail.com to ~/.ssh"
        ssh-keygen -t ed25519 -C "mthielvoldt@gmail.com" -N "" -f "$HOME/.ssh/id_ed25519"
        cat ~/.ssh/id_ed25519.pub
        read -p "[software.sh] Add above line to: https://github.com/settings/ssh/new Then press Enter to continue..."
    fi
fi

# -- Native Build from apt --
if [ "$confirm" == "b" ]; then
    echo -e "\n[software.sh] Installing build tools..."
    sudo apt install build-essential
fi

# -- Visual Studio Code --
if [ "$confirm" == "v" ]; then

    if [[ ! -f "$KEYRING_DIR/microsoft.gpg" ]]; then
        echo -e "\n[software.sh] Adding microsoft.gpg to keyrings"
        wget -O - https://packages.microsoft.com/keys/microsoft.asc \
            | gpg --dearmor > microsoft.gpg
        sudo install -D -o root -g root -m 644 microsoft.gpg $KEYRING_DIR/microsoft.gpg
        rm -f microsoft.gpg
    fi
    
    if [ ! -f $APT_SOURCES_DIR/vscode.sources ]; then
        echo -e "\n[software.sh] Installing vscode.sources"
        sudo install -D -o root -g root -m 644 apt-sources/vscode.sources $APT_SOURCES_DIR/vscode.sources
    fi
    
    sudo apt install apt-transport-https
    sudo apt update
    sudo apt install code

    cp $SCRIPT_DIR/settings/vscode-settings.json $HOME/.config/Code/User/settings.json
    
    xargs -n 1 code --install-extension < vscode-extensions.txt
fi

# -- Docker Desktop --
if [ "$confirm" == "D" ]; then
    if [[ ! -f "$KEYRING_DIR/docker.asc" ]]; then
        echo -e "\n[software.sh] Adding docker.asc to keyrings"
        mkdir -p tmp
        wget -O tmp/docker.asc https://download.docker.com/linux/ubuntu/gpg 
        sudo install -D -o root -g root -m 644 tmp/docker.asc $KEYRING_DIR/docker.asc
    fi
    if [[ ! -f "$APT_SOURCES_DIR/docker.sources" ]]; then
        echo -e "\n[software.sh] Installing docker.sources"
        envsubst < apt-sources/docker.sources.in > /tmp/docker.sources
        sudo install -D -o root -g root -m 644 /tmp/docker.sources $APT_SOURCES_DIR/docker.sources
    fi
    mkdir -p ~/installs/deb
    wget -O ~/installs/deb/docker-desktop-amd64.deb "https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"
    sudo apt-get update
    sudo apt install ~/installs/deb/docker-desktop-amd64.deb
fi

# -- Node.js --
# Use nvm instead of apt so we can `npm install -g` without being root.
# Also, it really seems the ecosystem wants to be able to run multiple node versions.
if [ "$confirm" == "n" ]; then
    if [[ -d $HOME/.nvm ]]; then
        echo "nvm already installed."
    else
        echo -e "\n[software.sh] Download and install nvm..."
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
        # in lieu of restarting the shell
        \. "$HOME/.nvm/nvm.sh"
    fi
    if ! command -v node >/dev/null; then
        nvm install $NODE_VERSION
        node -v
        npm -v
    fi
fi

# -- cmake --
if [ "$confirm" == "c" ]; then

    # Kitware has a package to manage key rotation.  We need to additionally check that 
    # this package (kitware-archive-keyring) isn't installed before manually copying the gpg key.
    if [ ! -f "/usr/share/doc/kitware-archive-keyring/copyright" ] && [ ! -f "$KEYRING_DIR/kitware-archive-keyring.gpg" ]; then
        echo -e "\n[software.sh] Adding kitware.gpg to keyrings"
        wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc \
            | gpg --dearmor > kitware.gpg
        sudo install -D -o root -g root -m 644 kitware.gpg $KEYRING_DIR/kitware-archive-keyring.gpg
        rm -f kitware.gpg
    fi
    
    if [ ! -f $APT_SOURCES_DIR/kitware.sources ]; then
        echo -e "\n[software.sh] Adding kitware deb repo..."

        # substutute this version codename into the sources file. 
        envsubst < apt-sources/kitware.sources.in > /tmp/kitware.sources
        sudo install -D -o root -g root -m 644 /tmp/kitware.sources $APT_SOURCES_DIR/kitware.sources
        sudo apt-get update
        sudo rm $KEYRING_DIR/kitware-archive-keyring.gpg
    fi

    if ! command -v cmake >/dev/null 2>&1; then
        echo -e "\n[software.sh] installing cmake"
        sudo apt install kitware-archive-keyring cmake
    fi
fi

# -- Chrome --
if [ "$confirm" == "C" ]; then
    if [ ! -f $KEYRING_DIR/google.gpg ]; then
        echo -e "\n[software.sh] Adding google key to keyring"
        wget -O - https://dl-ssl.google.com/linux/linux_signing_key.pub \
            | gpg --dearmor > /tmp/google.gpg
        sudo install -o root -g root -m 644 /tmp/google.gpg $KEYRING_DIR/google.gpg
    fi

    if [ ! -f $APT_SOURCES_DIR/google-chrome.sources ]; then
        echo -e "\n[software.sh] Adding google deb repo..."
        envsubst < apt-sources/google-chrome.sources.in \
            | sudo tee $APT_SOURCES_DIR/google-chrome.sources >/dev/null
        sudo apt update
    fi

    sudo apt install google-chrome-stable
fi

# -- Claude --
if [ "$confirm" == "L" ]; then

    if [ ! -f  $KEYRING_DIR/claude-code.asc ]; then
        echo -e "\n[software.sh] Adding claude-code to keyring"
        wget -O /tmp/claude-code.asc https://downloads.claude.ai/keys/claude-code.asc
        sudo install -o root -g root -m 644 /tmp/claude-code.asc $KEYRING_DIR/claude-code.asc
        gpg --show-keys $KEYRING_DIR/claude-code.asc
        echo "deb [signed-by=$KEYRING_DIR/claude-code.asc] https://downloads.claude.ai/claude-code/apt/stable stable main" \
            | sudo tee $APT_SOURCES_DIR/claude-code.list
    fi
    if command -v claude >/dev/null 2>&1; then
        echo -e "\n[software.sh] Claude already installed. To update: sudo apt upgrade claude-code"
    else
        sudo apt update
        sudo apt install claude-code
    fi
fi

# --  --
if [ "$confirm" == "a" ]; then
    if [ !  ]; then
        echo -e "\n[software.sh] "
    fi
fi
