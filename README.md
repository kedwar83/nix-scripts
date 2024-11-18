# NixOS Configuration Management Scripts

This repository contains a collection of scripts for managing NixOS configurations and dotfiles. These scripts help automate the process of setting up a new NixOS system, synchronizing configurations, and managing dotfiles.

## Scripts Overview

### 1. First-Time Setup Script (`setup.sh`)

A comprehensive setup script that initializes a new NixOS system with the following features:

- Git repository initialization
- SSH key generation
- LUKS configuration generation
- NixOS configuration structure creation
- Home-manager installation
- Dotfiles setup

**Key Features:**
- Automatic LUKS device detection and configuration
- Git repository management
- User-specific configuration
- Hardware configuration copying
- Dotfiles management using stow

### 2. Dotfiles Sync Script (`dotfiles-sync`)

A Nix-based script for synchronizing dotfiles between your home directory and a Git repository.

**Key Features:**
- Automated dotfiles backup
- Selective file synchronization
- Extensive file exclusion list
- Firefox profile management
- Automatic git commits and pushes
- Error logging and notifications

### 3. NixOS Sync Script (`nixos-sync`)

A script for synchronizing and rebuilding NixOS configurations.

**Key Features:**
- Automated NixOS rebuilding
- System-wide configuration management
- Root privilege handling
- Success/failure notifications

### 4. Home Manager Sync Script (`home-manager-sync`)

A script for synchronizing and rebuilding Home Manager configurations.

**Key Features:**
- User-level configuration management
- Automated Home Manager rebuilding
- Success/failure notifications
- No root privileges required

## Requirements

- NixOS installation
- Git
- Home Manager
- GNU Stow
- Root access (for system-wide operations)

## Usage

### First-Time Setup

```bash
sudo ./setup.sh
```

Follow the prompts to configure your system. You'll need to:
1. Provide a hostname
2. Add your SSH key to GitHub when prompted
3. Edit configuration files as needed

### Regular Synchronization

For dotfiles:
```bash
dotfiles-sync
```

For NixOS configuration:
```bash
sudo nixos-sync
```

For Home Manager configuration:
```bash
home-manager-sync
```

## Configuration Files

- NixOS configurations are stored in `/etc/nixos`
- Dotfiles are stored in `~/.dotfiles`
- Home Manager configurations are managed through the dotfiles repository

## File Structure

```
/etc/nixos/
├── flake.nix
├── hosts/
│   └── <hostname>/
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       ├── boot.nix
│       └── home.nix
└── ...

~/.dotfiles/
├── .config/
├── .mozilla/
└── ...
```

## Notes

- The setup script is specifically configured for the user "keganre". Modify the script for your username if needed.
- LUKS configuration is automatically generated based on your system's encrypted volumes.
- Certain sensitive files and directories are excluded from dotfiles synchronization (see exclusion list in `dotfiles-sync`).
- All sync scripts include error handling and notifications.
