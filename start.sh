#!/bin/bash
set -euo pipefail

# relink sh from dash to bash
relink_sh() {
    rm -rf /usr/bin/sh
    ln -s /usr/bin/bash /usr/bin/sh
}

# update system & upgrade
update_upgrade() {
    apt update && apt upgrade -y
}

# set sudo timeout
setup_sudoers() {
    # set sudo timeout
    echo 'Defaults    timestamp_timeout=0' >> /etc/sudoers
    # add user to sudoers
    echo "${LOCAL_USERNAME} ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
}

# setup vscode repository and install it
setup_vscode() {
    apt-get install wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
    rm -f packages.microsoft.gpg
    apt install -y apt-transport-https
    apt update
    apt install -y code # or code-insiders
}

# setup terraform
setup_terraform() {
    # --- Terraform: latest version from HashiCorp releases API ---
    TERRAFORM_VERSION=$(curl -fsSL https://api.releases.hashicorp.com/v1/releases/terraform/latest | jq -r '.version')
    wget "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip"
    unzip terraform*.zip terraform
    mv terraform /usr/bin/
    rm -rf terraform*.zip
}

# setup docker repository and install it
setup_docker() {
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" |
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    sudo apt-get update
    apt update
    apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo usermod -aG docker $LOCAL_USERNAME

    # set bash-completition for docker
    mkdir -p /etc/bash_completion.d
    docker completion bash > /etc/bash_completion.d/docker
}

# setup golang
setup_golang() {
    echo '# GOLANG PATH' >> /etc/profile
    echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
    # --- Golang: latest stable version from go.dev ---
    GOLANG_VERSION=$(curl -fsSL 'https://go.dev/dl/?mode=json' | jq -r '[.[] | select(.stable == true)][0].version')
    wget "https://go.dev/dl/${GOLANG_VERSION}.linux-amd64.tar.gz"
    rm -rf /usr/local/go && tar -C /usr/local -xzf go*.tar.gz
    rm -rf go*.tar.gz
}

# install k9s
install_k9s() {
    K9S_VERSION=$(curl -fsSL https://api.github.com/repos/derailed/k9s/releases/latest | jq -r '.tag_name')
    wget "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_linux_amd64.deb"
    apt install -y ./k9s*.deb
    rm -rf k9s*.deb
}

install_kubectl() {
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -rf kubectl
}

# setup virt-manager
setup_virt() {
    systemctl enable libvirtd
    sudo adduser ${LOCAL_USERNAME} libvirt
    sudo adduser ${LOCAL_USERNAME} kvm
}

alsa_audio() {
    touch /etc/modprobe.d/alsa-base.conf
    echo "options snd-hda-intel power_save=0 power_save_controller=N" > /etc/modprobe.d/alsa-base.conf
}

remove_bloat() {
    # Update package list
    sudo apt update

    # Remove common bloatware apps
    REMOVE_PACKAGES=(
        libreoffice*
        gnome-contacts
        gnome-maps
        gnome-music
        gnome-clocks
        gnome-characters
        gnome-dictionary
        gnome-font-viewer
        gnome-logs
        gnome-software
        gnome-sound-recorder
        gnome-terminal
        gnome-tour
        gnome-weather
        cheese
        evolution
        rhythmbox
        simple-scan
        transmission-gtk
        totem
        yelp
        thunderbird
        shotwell
        aisleriot
        five-or-more
        four-in-a-row
        hitori
        iagno
        lightsoff
        quadrapassel
        swell-foop
        tali
    )

    # Remove them
    sudo apt purge -y "${REMOVE_PACKAGES[@]}"

    # Autoremove leftovers
    sudo apt autoremove -y --purge

    # Clean cache
    sudo apt clean
}

install_packages() {
    # Update package index
    sudo apt update

    # Define the list of packages you want
    PACKAGES=(
        fastfetch
        xfce4-terminal
        unzip
        p7zip-full
        vim
        git
        git-lfs
        curl
        htop
        bash-completion
        bat
        fd-find
        ffmpeg
        fzf
        lm-sensors
        make
        ripgrep
        sqlite3
        ansible
        ansible-lint
        keepassxc
        jq
        7zip
        pwgen
        tmux
        tree
        unzip
        age
        fonts-dejavu
        fonts-dejavu-core
        fonts-dejavu-extra
        fonts-dejavu-web
        fonts-firacode
        fonts-font-awesome
        fonts-noto-mono
        fonts-cantarell
        fonts-cascadia-code
        gnupg
        ca-certificates
        virt-manager
        qemu-system
        vlc
        gnome-tweaks
        gnome-shell-extension-manager
        lazygit
        wireguard
        yaru-theme-gnome-shell
        yaru-theme-gtk
        yaru-theme-icon
    )

    # Install them
    sudo apt install -y "${PACKAGES[@]}"

    # Clean up
    sudo apt autoremove -y
    sudo apt clean
}

remove_unwanted_dirs() {
    rm -rf /home/"${LOCAL_USERNAME}"/Public /home/"${LOCAL_USERNAME}"/Templates /home/"${LOCAL_USERNAME}"/Videos /home/"${LOCAL_USERNAME}"/Music /home/"${LOCAL_USERNAME}"/Desktop
    cat > /home/"${LOCAL_USERNAME}"/.config/user-dirs.dirs << 'EOF'
# XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
# XDG_TEMPLATES_DIR="$HOME/Templates"
# XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_DOCUMENTS_DIR="$HOME/Documents"
# XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
# XDG_VIDEOS_DIR="$HOME/Videos"
EOF

    echo "enabled=False" > /home/"${LOCAL_USERNAME}"/.config/user-dirs.conf
    gsettings reset org.gnome.shell favorite-apps
}

echo -n "Enter username to add groups(docker,kvm,libvirt): "
read -r LOCAL_USERNAME

relink_sh
update_upgrade
remove_unwanted_dirs
remove_bloat
install_packages
setup_vscode
setup_terraform
setup_docker
install_k9s
install_kubectl
setup_golang
setup_virt
alsa_audio
setup_sudoers
systemctl reboot
