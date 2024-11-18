{pkgs}:
pkgs.writeShellScriptBin "nixos-sync" ''
  #!/usr/bin/env bash
  set -e

  # Variables
  CONFIG_DIR="/etc/nixos"
  REBUILD_CMD="nixos-rebuild switch --flake '/etc/nixos#$(hostname)'"
  SUCCESS_MSG="NixOS Rebuilt OK!"
  FAILURE_MSG="NixOS Rebuild Failed!"
  NOTIFY_ICON="software-update-available"
  REQUIRES_ROOT="true"

  # Ensure root privileges
  if [ "$EUID" -ne 0 ]; then
      echo "This script must be run as root"
      exit 1
  fi

  # Source the common script
  source $(command -v common-sync)

  # Call shared functionality
  sync_and_rebuild "$CONFIG_DIR" "$REBUILD_CMD" "$SUCCESS_MSG" "$FAILURE_MSG" "$NOTIFY_ICON" "$REQUIRES_ROOT"
''
