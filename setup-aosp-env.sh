#!/usr/bin/env bash

# SPDX-License-Identifier: GPL-3.0-only
# AOSP Build Environment Setup Script for RHEL 9 and Derivatives

set -euo pipefail

# Configuration
LATEST_MAKE_VERSION="4.3"
REPO_URL="https://storage.googleapis.com/git-repo-downloads/repo"
ANDROID_RULES_URL="https://raw.githubusercontent.com/M0Rf30/android-udev-rules/master/51-android.rules"
GH_REPO_URL="https://cli.github.com/packages/rpm/gh-cli.repo"
EPEL_RPM_URL="https://dl.fedoraproject.org/pub/epel/epel-release-latest-9.noarch.rpm"

# Color Definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Error Handling
error_exit() {
    echo -e "${RED}❌ Error: $1${NC}" >&2
    exit 1
}

# System Checks
check_dnf() {
    if ! command -v dnf &>/dev/null; then
        error_exit "This script requires a dnf-based package manager."
    fi
}

# Repository Configuration
enable_crb() {
    echo -e "${YELLOW}🔍 Configuring repositories...${NC}"
    
    local rhel_crb_file="/etc/yum.repos.d/redhat.repo"
    local crb_configured=0

    if grep -qi 'rhel' /etc/os-release; then
        echo -e "${YELLOW}➖ Checking RHEL CRB...${NC}"
        if [ -f "$rhel_crb_file" ] && sudo grep -qE '^\[codeready-builder-for-rhel-9-.*\]' "$rhel_crb_file" && \
           sudo grep -qE '^enabled\s*=\s*1' "$rhel_crb_file"; then
            crb_configured=1
        fi

        if [ "$crb_configured" -eq 0 ]; then
            echo -e "${YELLOW}➕ Enabling CRB repository for RHEL...${NC}"
            sudo subscription-manager repos --enable "codeready-builder-for-rhel-9-$(uname -m)-rpms" || \
            error_exit "Failed to enable CRB. Ensure RHEL is registered with RHSM."
            # Refresh after enabling new repo
            sudo dnf update -y
        fi

    elif grep -qiE 'rocky|alma' /etc/os-release; then
        echo -e "${YELLOW}➖ Checking CRB for Rocky/AlmaLinux...${NC}"
        local crb_repo_file=$(sudo find /etc/yum.repos.d/ -name "*crb*.repo" -print -quit)
        [ -n "$crb_repo_file" ] && sudo grep -qE '^enabled\s*=\s*1' "$crb_repo_file" && crb_configured=1

        if [ "$crb_configured" -eq 0 ]; then
            echo -e "${YELLOW}➕ Enabling CRB...${NC}"
            sudo dnf config-manager --set-enabled crb || error_exit "Failed to enable CRB repository."
        fi
    fi
}

# EPEL Repository Installation
install_epel() {
    echo -e "${YELLOW}📥 Installing EPEL repository...${NC}"
    
    # Clean existing EPEL installation
    sudo dnf remove -y epel-release >/dev/null 2>&1 || true
    sudo rm -f /etc/yum.repos.d/epel*.repo || true

    # Temporary storage for RPM
    local temp_rpm=$(mktemp).rpm

    # Download EPEL RPM with retries
    for i in {1..3}; do
        echo -e "Download attempt ${i}/3"
        if curl -sSL -o "$temp_rpm" "$EPEL_RPM_URL"; then
            break
        elif [ $i -eq 3 ]; then
            error_exit "Failed to download EPEL RPM after 3 attempts"
        fi
        sleep 2
    done

    # Install RPM manually
    if ! sudo rpm -Uvh "$temp_rpm"; then
        error_exit "EPEL RPM installation failed. Check permissions and package integrity."
    fi

    # Verify EPEL files
    if ! ls /etc/yum.repos.d/epel*.repo >/dev/null 2>&1; then
        error_exit "EPEL configuration files missing after installation"
    fi

    # Modify EPEL configuration
    echo -e "${YELLOW}⚙️ Modifying EPEL configuration...${NC}"
    for repo_file in /etc/yum.repos.d/epel*.repo; do
        sudo sed -i \
            -e 's/metalink=/#metalink=/g' \
            -e 's|#baseurl=https://download.example/pub|baseurl=https://dl.fedoraproject.org/pub|g' \
            -e '/^\[epel-cisco-openh264\]/,/^\[/s/^enabled=1/enabled=0/' \
            "$repo_file" || error_exit "Failed to modify $repo_file"
    done

    # Cleanup temporary file
    rm -f "$temp_rpm"
}

# Dependency Installation
install_dependencies() {
    echo -e "${YELLOW}📦 Installing base packages...${NC}"

    # Clean existing cache
    sudo dnf clean all || error_exit "Failed to clean package cache"
    sudo rm -rf /var/cache/dnf || error_exit "Failed to remove cache directory"

    # Install EPEL
    install_epel

    # Refresh package lists
    echo -e "${YELLOW}🔄 Refreshing package metadata...${NC}"
    sudo dnf makecache --refresh -y || error_exit "Failed to refresh package metadata"

    # Install development tools
    echo -e "${YELLOW}📦 Installing development tools...${NC}"
    sudo dnf groupinstall -y "Development Tools" || error_exit "Failed to install development tools"

    # Main package installation
    echo -e "${YELLOW}📦 Installing main packages...${NC}"
    sudo dnf install -y \
        adb \
        fastboot \
        git \
        git-lfs \
        python3 \
        python3-devel \
        java-1.8.0-openjdk-devel \
        curl \
        wget \
        unzip \
        bc \
        bison \
        flex \
        zlib-devel \
        zlib-devel.i686 \
        ncurses-devel \
        ncurses-compat-libs \
        gperf \
        libX11-devel \
        libXrandr-devel \
        libXcursor-devel \
        libXinerama-devel \
        mesa-libGL-devel \
        libXi-devel \
        glibc-devel \
        glibc-devel.i686 \
        libstdc++-devel \
        libstdc++-devel.i686 \
        gcc \
        gcc-c++ \
        cmake \
        perl-XML-Simple \
        openssl-devel \
        expat-devel \
        xz \
        xz-devel \
        rsync \
        zip \
        squashfs-tools \
        ImageMagick \
        texinfo \
        libxslt \
        SDL2-devel \
        lzip \
        lz4-devel \
        libselinux-devel \
        libsepol-devel \
        libatomic \
        libatomic.i686 \
        libX11-devel \
        libXrandr-devel \
        libXcursor-devel \
        libXinerama-devel \
        mesa-libGL-devel \
        ncurses-compat-libs \
        zlib-devel \
        lzo-devel \
        lzop \
        unzip \
        bc \
        rsync \
        zip \
        curl \
        wget \
        perl \
        patch \
        wayland-devel || error_exit "Failed to install base packages"
}

# GitHub CLI Installation
install_gh() {
    echo -e "${YELLOW}📦 Installing GitHub CLI...${NC}"
    if ! command -v gh &>/dev/null; then
        sudo dnf install -y dnf-plugins-core
        sudo dnf config-manager --add-repo "$GH_REPO_URL"
        sudo dnf install -y gh || error_exit "Failed to install GitHub CLI"
        echo -e "${GREEN}✅ GitHub CLI installed successfully${NC}"
    else
        echo -e "${GREEN}✅ GitHub CLI already installed${NC}"
    fi
}

# Android USB Rules
setup_android_rules() {
    local rules_file="/etc/udev/rules.d/51-android.rules"
    if [ ! -f "$rules_file" ]; then
        echo -e "${YELLOW}🔧 Configuring Android udev rules...${NC}"
        sudo curl -sSL --create-dirs -o "$rules_file" "$ANDROID_RULES_URL" || \
            error_exit "Failed to download udev rules"
        sudo chmod 644 "$rules_file"
        sudo chown root:root "$rules_file"
        sudo systemctl restart systemd-udevd
        echo -e "${GREEN}✅ Android udev rules configured${NC}"
    else
        echo -e "${GREEN}✅ Android udev rules already exist${NC}"
    fi
}

# Repo Tool Installation
install_repo() {
    echo -e "${YELLOW}🔍 Configuring repo tool...${NC}"
    
    # Get user context even when running with sudo
    local user_name=${SUDO_USER:-$USER}
    local home_dir=$(eval echo "~$user_name")
    local bin_dir="${home_dir}/.bin"
    local repo_path="${bin_dir}/repo"

    # Clean existing installation
    echo -e "${YELLOW}🧹 Removing old repo tool if it exists...${NC}"
    rm -f "$repo_path"

    # Create bin directory if needed
    mkdir -p "$bin_dir"

    # Download repo tool
    echo -e "${YELLOW}📥 Downloading repo tool...${NC}"
    if ! curl -fsSL -o "$repo_path" "$REPO_URL"; then
        error_exit "Failed to download repo tool from $REPO_URL"
    fi

    chmod a+x "$repo_path"

    # Update PATH in .bashrc
    echo -e "${YELLOW}🔄 Updating PATH in .bashrc if needed...${NC}"
    if ! grep -q 'export PATH=$HOME/.bin:$PATH' "${home_dir}/.bashrc"; then
        echo 'export PATH=$HOME/.bin:$PATH' >> "${home_dir}/.bashrc"
        exec bash --rcfile "${home_dir}/.bashrc"
    fi

    # Verify installation
    if [[ -x "$repo_path" ]]; then
        echo -e "${GREEN}✅ Repo tool installed to ${repo_path}${NC}"
    else
        error_exit "Repo installation verification failed"
    fi
}

# Make Version Upgrade
upgrade_make() {
    local current_make=$(make -v 2>/dev/null | head -1 | awk '{print $3}')
    [ "$current_make" == "$LATEST_MAKE_VERSION" ] && return 0

    echo -e "${YELLOW}⬆️  Building make $LATEST_MAKE_VERSION...${NC}"
    temp_dir=$(mktemp -d)
    trap "rm -rf $temp_dir" EXIT
    
    curl -sSL -o "$temp_dir/make.tar.gz" "https://ftp.gnu.org/gnu/make/make-$LATEST_MAKE_VERSION.tar.gz"
    tar -xf "$temp_dir/make.tar.gz" -C "$temp_dir"
    pushd "$temp_dir/make-$LATEST_MAKE_VERSION" >/dev/null
    ./configure --prefix=/usr
    make -j$(nproc)
    sudo make install
    popd >/dev/null
}

# Final Summary
show_summary() {
    echo -e "\n${GREEN}✅ Environment Setup Complete!${NC}"
    echo -e "Installed Components:"
    echo -e "  - Build Essentials"
    echo -e "  - Android Tools (adb/fastboot)"
    echo -e "  - repo v$(repo --version 2>/dev/null | awk '/repo launcher/ {print $3}')"
    echo -e "  - GitHub CLI"
    echo -e "  - make ${LATEST_MAKE_VERSION}"
    
    echo -e "\n${YELLOW}Next Steps:${NC}"
    echo -e "1. Configure git:"
    echo -e "   git config --global user.name \"Your Name\""
    echo -e "   git config --global user.email \"you@example.com\""
    echo -e "2. Consider setting up ccache for faster builds"
}

# Main Execution Flow
main() {
    echo -e "${YELLOW}🚀 Starting AOSP Environment Setup...${NC}"
    check_dnf
    enable_crb
    install_dependencies
    install_gh
    setup_android_rules
    install_repo
    upgrade_make
    show_summary
    echo -e "\n${GREEN}✔️ Setup Completed Successfully!${NC}"
}

# Execute Main Function
main
