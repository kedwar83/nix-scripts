{pkgs}:
pkgs.writeShellScriptBin "common-sync" ''
  #!/usr/bin/env bash
  set -e

  # Function to determine the actual non-root user
  get_non_root_user() {
      # If SUDO_USER is set (script run with sudo), use that
      if [ -n "$SUDO_USER" ]; then
          echo "$SUDO_USER"
      else
          # Otherwise, use the current user
          whoami
      fi
  }

  # Shared Functionality
  sync_and_rebuild() {
      local config_dir="$1"
      local rebuild_cmd="$2"
      local success_msg="$3"
      local failure_msg="$4"
      local notify_icon="$5"
      local requires_root="$6"

      # Determine the actual user and their UID
      ACTUAL_USER=$(get_non_root_user)
      ACTUAL_USER_UID=$(id -u "$ACTUAL_USER")

      # Validate user detection
      if [ -z "$ACTUAL_USER" ] || [ "$ACTUAL_USER" = "root" ]; then
          echo "Unable to determine a valid non-root user."
          exit 1
      fi

      # Check for root privileges if required
      if [ "$requires_root" = "true" ] && [ "$EUID" -ne 0 ]; then
          echo "This script must be run as root"
          exit 1
      fi

      echo "Running sync and rebuild for user: $ACTUAL_USER"

      # Wrapper function to run commands as the non-root user
      run_as_user() {
          sudo -u "$ACTUAL_USER" "$@"
      }

      # Send notification as the actual user
      send_notification() {
          local msg="$1"
          local icon="$2"
          if [ -z "$icon" ]; then
              icon="info"
          fi
          sudo -u "$ACTUAL_USER" DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$ACTUAL_USER_UID/bus" notify-send "$msg" --icon="$icon"
      }

      # Format Nix files
      echo "Formatting Nix files with Alejandra..."
      alejandra "$config_dir"

      # Add and check Git changes
      run_as_user git -C "$config_dir" add .
      if ! run_as_user git -C "$config_dir" diff --quiet || ! run_as_user git -C "$config_dir" diff --cached --quiet; then
          echo "Changes detected, proceeding with rebuild..."

          # Rebuild
          if eval "$rebuild_cmd" 2>&1 | tee "$config_dir/rebuild.log"; then
              # Commit and push changes
              run_as_user git -C "$config_dir" commit -m "Update: $(date '+%Y-%m-%d %H:%M:%S')"
              run_as_user git -C "$config_dir" push origin main

              # Notify success
              send_notification "$success_msg" "$notify_icon"
          else
              # Notify failure
              send_notification "$failure_msg" "error"

              cat "$config_dir/rebuild.log" | grep --color error
              exit 1
          fi
      else
          send_notification "No changes detected, skipping rebuild and commit." "$notify_icon"
      fi
  }
''
