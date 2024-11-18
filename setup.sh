#!/usr/bin/env bash
set -e

ACTUAL_USER=${SUDO_USER:-$USER}
ACTUAL_HOME="/home/$ACTUAL_USER"
NIXOS_CONFIG_DIR="/etc/nixos"
GIT_REPO_URL="git@github.com:kedwar83/nixos-config.git"
DOTFILES_REPO_URL="git@github.com:kedwar83/.dotfiles.git"
DOTFILES_PATH="$ACTUAL_HOME/.dotfiles"
USER_EMAIL="keganedwards@proton.me"
SSH_KEY_FILE="/home/$ACTUAL_USER/.ssh/id_ed25519"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Check if user is keganre
if [ "$ACTUAL_USER" != "keganre" ]; then
    echo "This script is configured for user 'keganre'. Please modify the script for your username."
    exit 1
fi

setup_git() {
    local config_dir="$1"

    # Ensure git is available
    nix-shell -p git --run "true"

    # Initialize git repository
    if [ ! -d "$config_dir/.git" ]; then
        echo "Initializing a new git repository in $config_dir..."
        sudo -u $ACTUAL_USER nix-shell -p git --run "git init '$config_dir'"
    fi

    # Configure git
    if [ -z "$(sudo -u $ACTUAL_USER git config --global user.email)" ]; then
        echo "Setting git email..."
        sudo -u $ACTUAL_USER git config --global user.email "$USER_EMAIL"
    fi

    # Add safe directory
    if ! sudo -u $ACTUAL_USER git config --global --get safe.directory | grep -q "^$config_dir$"; then
        echo "Adding $config_dir as a safe directory..."
        sudo -u $ACTUAL_USER git config --global --add safe.directory "$config_dir"
    fi

    # Setup SSH key if needed
    if [ ! -f "$SSH_KEY_FILE" ]; then
        echo "No SSH key found, generating a new one for $USER_EMAIL..."
        sudo -u $ACTUAL_USER ssh-keygen -t ed25519 -f "$SSH_KEY_FILE" -C "$USER_EMAIL" -N ""
        echo "Please add the following SSH key to your GitHub account:"
        sudo -u $ACTUAL_USER cat "$SSH_KEY_FILE.pub"
        read -p "Press Enter after you've added the key to GitHub to continue..."
    fi

    # Configure remote
    if ! sudo -u $ACTUAL_USER git -C "$config_dir" remote get-url origin &> /dev/null; then
        echo "No remote repository found. Adding origin remote..."
        sudo -u $ACTUAL_USER git -C "$config_dir" remote add origin "$GIT_REPO_URL"
    fi
}

generate_luks_config() {
    local hostname="$1"
    local boot_config_file="$NIXOS_CONFIG_DIR/hosts/$hostname/boot.nix"
    local boot_device=$(findmnt -n -o SOURCE /boot | grep -o '/dev/nvme[0-9]n[0-9]')
    local luks_uuids=($(blkid | grep "TYPE=\"crypto_LUKS\"" | grep -o "UUID=\"[^\"]*\"" | cut -d'"' -f2))

    # Create the boot configuration file
    cat > "$boot_config_file" << EOL
{ config, pkgs, ... }:

{
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "${boot_device}";
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.enableCryptodisk = true;

  boot.initrd.luks.devices = {
EOL

    # Add LUKS device information for each UUID
    for uuid in "${luks_uuids[@]}"; do
        cat >> "$boot_config_file" << EOL
    "luks-${uuid}" = {
      device = "/dev/disk/by-uuid/${uuid}";
      keyFile = "/boot/crypto_keyfile.bin";
    };
EOL
    done

    cat >> "$boot_config_file" << EOL
  };

  boot.secrets = {
    "/boot/crypto_keyfile.bin" = null;
  };
}
EOL

    echo "LUKS and boot configuration successfully written to $boot_config_file"
}

# Initialize/check git repository for dotfiles
init_git_repo() {
    echo "Checking dotfiles git repository setup..."
    # Create directory if it doesn't exist
    if [ ! -d "$DOTFILES_PATH" ]; then
        echo "Creating dotfiles directory..."
        sudo -u $ACTUAL_USER mkdir -p "$DOTFILES_PATH"
    fi
    # Change to the dotfiles directory
    cd "$DOTFILES_PATH"
    # Initialize git if needed
    if [ ! -d "$DOTFILES_PATH/.git" ]; then
        echo "Initializing new git repository..."
        sudo -u $ACTUAL_USER git init
        # Make sure it's a safe directory right after initialization
        sudo -u $ACTUAL_USER git config --global --add safe.directory "$DOTFILES_PATH"
        # Create main branch and set it as default
        sudo -u $ACTUAL_USER git checkout -b main
    else
        # Make sure it's a safe directory
        sudo -u $ACTUAL_USER git config --global --add safe.directory "$DOTFILES_PATH"
    fi
    # Check for remote only if we have a git repository
    if [ -d "$DOTFILES_PATH/.git" ]; then
        if ! sudo -u $ACTUAL_USER git remote get-url origin >/dev/null 2>&1; then
            echo "Setting up remote repository..."
            sudo -u $ACTUAL_USER git remote add origin "$DOTFILES_REPO_URL"
        fi
        # Try to fetch only if we have a remote configured
        if sudo -u $ACTUAL_USER git remote -v | grep -q origin; then
            echo "Fetching from remote..."
            sudo -u $ACTUAL_USER git fetch origin || true
        fi
        # Ensure we're on the main branch
        if ! sudo -u $ACTUAL_USER git rev-parse --verify main >/dev/null 2>&1; then
            echo "Creating main branch..."
            sudo -u $ACTUAL_USER git checkout -b main
        else
            echo "Checking out main branch..."
            sudo -u $ACTUAL_USER git checkout main || sudo -u $ACTUAL_USER git checkout -b main
        fi
        # Clone the actual repo contents
        sudo -u $ACTUAL_USER git clone "$DOTFILES_REPO_URL" "$DOTFILES_PATH"
    fi
}

# Main setup function
echo "First-time setup detected..."

# Setup git
setup_git "$NIXOS_CONFIG_DIR"

# Chown the config directory to the actual user
echo "Changing ownership of $NIXOS_CONFIG_DIR to $ACTUAL_USER..."
chown -R "$ACTUAL_USER:users" "$NIXOS_CONFIG_DIR"

# Clone the repository
echo "Cloning NixOS configuration repository..."
sudo -u $ACTUAL_USER nix-shell -p git --run "git clone '$GIT_REPO_URL' '$NIXOS_CONFIG_DIR/temp' && cp -r '$NIXOS_CONFIG_DIR/temp/'* '$NIXOS_CONFIG_DIR/' && rm -rf '$NIXOS_CONFIG_DIR/temp'"

# Get hostname from user
read -p "Please enter the hostname for this machine: " hostname

# Create new host directory structure by copying from desktop
echo "Creating new host configuration structure..."
cp -r "$NIXOS_CONFIG_DIR/hosts/desktop" "$NIXOS_CONFIG_DIR/hosts/$hostname"

# Generate LUKS configuration and overwrite boot.nix
echo "Generating LUKS configuration..."
generate_luks_config "$hostname"

# Copy hardware configuration from /etc/nixos and overwrite the existing one
echo "Copying hardware configuration..."
cp "/etc/nixos/hardware-configuration.nix" "$NIXOS_CONFIG_DIR/hosts/$hostname/hardware-configuration.nix"

# Prompt user to edit configuration files
echo "Please edit the following configuration files for your new host:"
echo "1. $NIXOS_CONFIG_DIR/hosts/$hostname/configuration.nix"
echo "2. $NIXOS_CONFIG_DIR/hosts/$hostname/home.nix"
read -p "Press Enter after you've finished editing the configuration files..."

# Rebuild NixOS with flake
echo "Rebuilding NixOS..."
nixos-rebuild switch --flake "/etc/nixos#${hostname}"

# Clone dotfiles repository
echo "Setting up dotfiles repository..."
init_git_repo

# Setup home-manager
echo "Setting up home-manager..."
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
nix-shell '<home-manager>' -A install

# Stow the dotfiles forcefully
echo "Stowing dotfiles..."
sudo -u $ACTUAL_USER nix-shell -p stow --run "stow -vR --adopt . -d '$DOTFILES_PATH' -t '$ACTUAL_HOME' 2>"

echo "First-time setup and home-manager installation complete!"
