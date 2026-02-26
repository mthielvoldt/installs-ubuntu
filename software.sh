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
  'n' node.js v20 (to change node version, edit nodesource.sources)
  's' ssh key
  'u' for utilities (tree...)
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


# -- Create ~/bin if not there --
if [ "$confirm" == "a" ] || [ "$confirm" == "h" ]; then
    if [ ! -d "$HOME/bin" ]; then
        echo -e "\n[software.sh] Creating ~/bin"
        mkdir -p "$HOME/bin"
        export PATH="$HOME/bin:$PATH"
    fi
    if [[ ! $MGT_ALIASES ]]; then
        echo -e "\n[software.sh] Adding 'source ~/installs/aliases.sh' to ~/.profile"
        echo -e "\nsource ~/installs/aliases.sh\n" >> ~/.profile
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
    sudo apt install tree python3-venv mpv
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
        sudo install -D -o root -g root -m 644 "$CALL_DIR/vscode.sources" /etc/apt/sources.list.d/vscode.sources
    fi
    
    sudo apt install apt-transport-https
    sudo apt update
    sudo apt install code
    
    xargs -n 1 code --install-extension < vscode-extensions.txt
fi

# -- Node.js --
if [ "$confirm" == "a" ] || [ "$confirm" == "n" ]; then

    if [[ ! -f "/usr/share/keyrings/nodesource.gpg" ]]; then
        echo -e "\n[software.sh] Adding nodesource.gpg to keyrings"
        wget -O - https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
            | gpg --dearmor > nodesource.gpg
        sudo install -D -o root -g root -m 644 nodesource.gpg /usr/share/keyrings/nodesource.gpg
        rm -f nodesource.gpg
    fi
    
    if [ ! -f /etc/apt/sources.list.d/nodesource.sources ]; then
        echo -e "\n[software.sh] Installing nodesource.sources"
        sudo install -D -o root -g root -m 644 "$CALL_DIR/nodesource.sources" /etc/apt/sources.list.d/nodesource.sources
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo -e "\n[software.sh] Installing Node"
        sudo apt update
        sudo apt install nodejs
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
        envsubst < kitware.sources.in > /tmp/kitware.sources
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

    if [ ! -f /etc/apt/sources.list.d/google.sources ]; then
        echo -e "\n[software.sh] Adding google deb repo..."
        envsubst < google.sources.in \
            | sudo tee /etc/apt/sources.list.d/google.sources >/dev/null
        sudo apt update
    fi

    sudo apt install google-chrome-stable
fi

# --  --
if [ "$confirm" == "a" ] || [ "$confirm" == "a" ]; then
    if [ !  ]; then
        echo -e "\n[software.sh] "
    fi
fi