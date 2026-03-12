#!/bin/bash
set -e

echo "Installing system software.  Press:
  'a' for all
  'b' build tools
  'c' cmake
  'C' Chrome browser
  'd' for Dropbox
  'g' git (latest)
  'h' home mods
  'l' libre office writer, calc
  'L' Claude
  'n' node.js v24 (to change node version, edit NODE_VERSION)
  's' ssh key
  'u' for apt utilities (tree...)
  'U' for user setup (groups)
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
export DPKG_ARCH=$(dpkg --print-architecture)
export NODE_VERSION=24

# -- User setup --
if [ "$confirm" == "a" ] || [ "$confirm" == "U" ]; then
    if [[ $USER == "root" ]]; then
        echo "Script run as root.  Restart as your normal user."
        exit -1
    fi
    sudo usermod -a -G dialout,tinyproxy $USER
fi

# -- Create ~/bin if not there --
if [ "$confirm" == "a" ] || [ "$confirm" == "h" ]; then
    if [ ! -d "$HOME/bin" ]; then
        echo -e "\n[software.sh] Creating ~/bin"
        mkdir -p "$HOME/bin"
        export PATH="$HOME/bin:$PATH"
    fi
    if [[ ! $MGT_ALIASES ]]; then
        echo -e "\n[software.sh] Adding 'source ~/installs/aliases.sh' to ~/.profile"
        echo -e "\n# MGT Aliases\nsource ~/installs/aliases.sh" >> ~/.bashrc
    fi
fi

# -- Dropbox --
if [ "$confirm" == "a" ] || [ "$confirm" == "d" ]; then
    
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

# -- Generic utilities from apt --
if [ "$confirm" == "a" ] || [ "$confirm" == "u" ]; then
    echo -e "\n[software.sh] Installing apt utilities..."
    sudo apt update
    sudo apt install tree python3-venv mpv curl libcap-dev ripgrep tinyproxy
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

# -- Git from ppa (because github hosted runner ubuntu-latest has the latest git, apt does not.)
if [ "$confirm" == "a" ] || [ "$confirm" == "g" ]; then
    echo -e "\n[software.sh] Installing git from PPA..."
    sudo add-apt-repository ppa:git-core/ppa
    sudo apt update
    sudo apt install git
    git config --global user.email "mthielvoldt@gmail.com"
    git config --global user.name "Mike Thielvoldt"
fi

# -- Ssh key (for github) --
if [ "$confirm" == "a" ] || [ "$confirm" == "s" ]; then
    if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
        echo -e "\n[software.sh] Generating ssh key for mthielvoldt@gmail.com to ~/.ssh"
        ssh-keygen -t ed25519 -C "mthielvoldt@gmail.com" -N "" -f "$HOME/.ssh/id_ed25519"
        cat ~/.ssh/id_ed25519.pub
        read -p "[software.sh] Add above line to: https://github.com/settings/ssh/new Then press Enter to continue..."
    fi
fi

# -- Native Build from apt --
if [ "$confirm" == "a" ] || [ "$confirm" == "b" ]; then
    echo -e "\n[software.sh] Installing build tools..."
    sudo apt install build-essential
fi

# -- Libre Office from apt --
if [ "$confirm" == "a" ] || [ "$confirm" == "l" ]; then
    echo -e "\n[software.sh] Installing Libre office..."
    sudo apt install libreoffice-calc libreoffice-writer apt-transport-https
fi

# -- Visual Studio Code --
if [ "$confirm" == "a" ] || [ "$confirm" == "v" ]; then

    if [[ ! -f "/usr/share/keyrings/microsoft.gpg" ]]; then
        echo -e "\n[software.sh] Adding microsoft.gpg to keyrings"
        wget -O - https://packages.microsoft.com/keys/microsoft.asc \
            | gpg --dearmor > microsoft.gpg
        sudo install -D -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/microsoft.gpg
        rm -f microsoft.gpg
    fi
    
    if [ ! -f /etc/apt/sources.list.d/vscode.sources ]; then
        echo -e "\n[software.sh] Installing vscode.sources"
        sudo install -D -o root -g root -m 644 apt-sources/vscode.sources /etc/apt/sources.list.d/vscode.sources
    fi
    
    sudo apt install apt-transport-https
    sudo apt update
    sudo apt install code
    
    xargs -n 1 code --install-extension < vscode-extensions.txt
fi

# -- Node.js --
# Use nvm instead of apt so we can `npm install -g` without being root.
# Also, it really seems the ecosystem wants to be able to run multiple node versions.
if [ "$confirm" == "a" ] || [ "$confirm" == "n" ]; then
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
if [ "$confirm" == "a" ] || [ "$confirm" == "c" ]; then

    # Kitware has a package to manage key rotation.  We need to additionally check that 
    # this package (kitware-archive-keyring) isn't installed before manually copying the gpg key.
    if [ ! -f "/usr/share/doc/kitware-archive-keyring/copyright" ] && [ ! -f "/usr/share/keyrings/kitware-archive-keyring.gpg" ]; then
        echo -e "\n[software.sh] Adding kitware.gpg to keyrings"
        wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc \
            | gpg --dearmor > kitware.gpg
        sudo install -D -o root -g root -m 644 kitware.gpg /usr/share/keyrings/kitware-archive-keyring.gpg
        rm -f kitware.gpg
    fi
    
    if [ ! -f /etc/apt/sources.list.d/kitware.sources ]; then
        echo -e "\n[software.sh] Adding kitware deb repo..."

        # Get the version code of this ubuntu (bionic, focal, jammy, noble)
        . /etc/os-release
        export VERSION_CODENAME

        # substutute this version codename into the sources file. 
        envsubst < apt-sources/kitware.sources.in > /tmp/kitware.sources
        sudo install -D -o root -g root -m 644 /tmp/kitware.sources /etc/apt/sources.list.d/kitware.sources
        sudo apt-get update
        sudo rm /usr/share/keyrings/kitware-archive-keyring.gpg
    fi

    if ! command -v cmake >/dev/null 2>&1; then
        echo -e "\n[software.sh] installing cmake"
        sudo apt install kitware-archive-keyring cmake
    fi
fi

# -- Chrome --
if [ "$confirm" == "a" ] || [ "$confirm" == "C" ]; then
    if [ ! -f /usr/share/keyrings/google.gpg ]; then
        echo -e "\n[software.sh] Adding google key to keyring"
        wget -O - https://dl-ssl.google.com/linux/linux_signing_key.pub \
            | gpg --dearmor > /tmp/google.gpg
        sudo install -o root -g root -m 644 /tmp/google.gpg /usr/share/keyrings/google.gpg
    fi

    if [ ! -f /etc/apt/sources.list.d/google-chrome.list ]; then
        echo -e "\n[software.sh] Adding google deb repo..."
        envsubst < apt-sources/google-chrome.list.in \
            | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
        sudo apt update
    fi

    sudo apt install google-chrome-stable
fi

# -- Claude --
if [ "$confirm" == "a" ] || [ "$confirm" == "L" ]; then
    if [[ -d "$HOME/.claude" ]]; then
        echo -e "\n[software.sh] Claude already installed. - skipping."
    else
        echo -e "\n[software.sh] Installing Claude..."
        curl -fsSL https://claude.ai/install.sh | bash
    fi
fi

# --  --
if [ "$confirm" == "a" ] || [ "$confirm" == "a" ]; then
    if [ !  ]; then
        echo -e "\n[software.sh] "
    fi
fi