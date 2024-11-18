{ config, pkgs, ... }:

let
  homeManagerSyncScript = pkgs.writeShellScriptBin "home-manager-sync" ''
    #!/usr/bin/env bash
    set -e

    CONFIG_DIR="/home/$USER/.dotfiles"
    REBUILD_CMD="home-manager switch"
    SUCCESS_MSG="Home Manager Rebuilt OK!"
    FAILURE_MSG="Home Manager Rebuild Failed!"
    NOTIFY_ICON="software-update-available"
    REQUIRES_ROOT="false"

    source $(command -v common-sync)

    sync_and_rebuild "$CONFIG_DIR" "$REBUILD_CMD" "$SUCCESS_MSG" "$FAILURE_MSG" "$NOTIFY_ICON" "$REQUIRES_ROOT"
  '';
in {
  home.packages = [ homeManagerSyncScript ];
}
