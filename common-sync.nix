{pkgs}:
pkgs.writeShellScriptBin "common-sync" ''
  #!/usr/bin/env bash
  set -e

  # Shared Functionality
  sync_and_rebuild() {
      local config_dir="$1"
      local rebuild_cmd="$2"
      local success_msg="$3"
      local failure_msg="$4"
      local notify_icon="$5"
      local requires_root="$6"

      # Use whoami to determine the actual user
      ACTUAL_USER=$(whoami)

      # Check for root privileges if required
      if [ "$requires_root" = "true" ] && [ "$EUID" -ne 0 ]; then
          echo "This script must be run as root"
          exit 1
      fi

      # Check if the username matches the current user
      if [ -z "$ACTUAL_USER" ]; then
          echo "Unable to determine the actual user."
          exit 1
      fi

      echo "Running sync and rebuild for user: $ACTUAL_USER"

      # Format Nix files
      echo "Formatting Nix files with Alejandra..."
      alejandra "$config_dir"

      # Add and check Git changes, using 'sudo -u' to run as the actual user
      sudo -u "$ACTUAL_USER" git -C "$config_dir" add .
      if ! sudo -u "$ACTUAL_USER" git -C "$config_dir" diff --quiet || ! sudo -u "$ACTUAL_USER" git -C "$config_dir" diff --cached --quiet; then
          echo "Changes detected, proceeding with rebuild..."

          # Rebuild
          if eval "$rebuild_cmd" 2>&1 | tee "$config_dir/rebuild.log"; then
              # Commit changes, using 'sudo -u' to run as the actual user
              sudo -u "$ACTUAL_USER" git -C "$config_dir" commit -m "Update: $(date '+%Y-%m-%d %H:%M:%S')"
              sudo -u "$ACTUAL_USER" git -C "$config_dir" push origin main

              # Notify success (Ensure correct reference of ACTUAL_USER inside shell)
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $ACTUAL_USER)/bus" notify-send "$success_msg" --icon="$notify_icon"
          else
              # Notify failure (Ensure correct reference of ACTUAL_USER inside shell)
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $ACTUAL_USER)/bus" notify-send "$failure_msg" --icon=error
              cat "$config_dir/rebuild.log" | grep --color error
              exit 1
          fi
      else
          DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u $ACTUAL_USER)/bus" notify-send "No changes detected, skipping rebuild and commit." --icon="$notify_icon"
      fi
  }
''
