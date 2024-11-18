{
  writeShellScriptBin,
  coreutils,
  git,
  stow,
  libnotify,
  rsync,
  findutils,
}:
writeShellScriptBin "dotfiles-sync" ''
  set -e

  # Configuration
  ACTUAL_HOME="$HOME"
  REPO_PATH="$ACTUAL_HOME/.dotfiles"
  DOTFILES_PATH="$REPO_PATH"
  TEMP_FILE=$(mktemp)
  FAILURE_LOG="$DOTFILES_PATH/failure_log.txt"
  SETUP_FLAG="$ACTUAL_HOME/.system_setup_complete"
  STOW_SUCCESS=0

  echo "Running as user: $USER"
  echo "Home directory: $ACTUAL_HOME"
  echo "Repo and Dotfiles path: $REPO_PATH"
  echo "Temporary file: $TEMP_FILE"
  echo "Failure log file: $FAILURE_LOG"

  copy_dotfiles() {
      echo "Copying dotfiles to repository..." | tee -a "$TEMP_FILE"

      ${rsync}/bin/rsync -av --no-links --ignore-missing-args \
          --exclude=".Xauthority" \
          --exclude=".xsession-errors" \
          --exclude=".bash_history" \
          --exclude=".ssh" \
          --exclude=".gnupg" \
          --exclude=".pki" \
          --exclude=".cache" \
          --exclude=".compose-cache" \
          --exclude=".local/share/Trash/" \
          --exclude="*/recently-used.xbel" \
          --exclude=".steam" \
          --exclude=".local/share/Steam" \
          --exclude=".local/share/Rocket League/" \
          --exclude=".nix-profile" \
          --exclude=".nix-defexpr" \
          --exclude=".local/share/dolphin/view_properties" \
          --exclude=".local/share/nicotine/downloads/" \
          --exclude=".local/share/GOG.com/" \
          --exclude=".dotfiles" \
          --exclude=".local/state/nix/profiles" \
          --exclude=".nixos-config" \
          --exclude=".system_setup_complete" \
          --exclude=".mozilla" \
          --exclude=".config/BraveSoftware/" \
          --exclude=".config/Mullvad VPN" \
          --exclude=".config/StardewValley/" \
          --exclude=".config/Signal Beta/" \
          --exclude=".config/session/" \
          --exclude=".config/Joplin/" \
          --exclude=".config/joplin-desktop" \
          --exclude=".config/VSCodium/" \
          --exclude=".dbus" \
          --exclude=".ollama" \
          --exclude=".pulse-cookie" \
          --exclude=".xsession-errors.old" \
          --include=".*" \
          --include=".*/**" \
          --exclude="*" \
          "$HOME/" "$HOME/.dotfiles/"

      local -a files=(
          ".mozilla/firefox/*/chrome/userChrome.css"
          ".mozilla/firefox/*/chrome/userContent.css"
          ".mozilla/firefox/*/user.js"
          ".config/joplin-desktop/settings.json"
          ".config/Joplin/Preferences"
          ".config/Mullvad VPN/gui_settings.json"
          ".config/Mullvad VPN/Preferences"
          ".config/VSCodium/User/settings.json"
          ".config/VSCodium/User/keybindings.json"
      )

      # Create base directories first (excluding wildcarded paths)
      for file in "''${files[@]}"; do
          if [[ $file != *"*"* ]]; then
              mkdir -p "$HOME/.dotfiles/$(dirname "$file")"
          fi
      done

      # Create Firefox profile directory structure if needed
      profile_dir=$(${findutils}/bin/find "$HOME/.mozilla/firefox" -maxdepth 1 -type d -name "*.default*" | head -n 1)
      if [ -n "$profile_dir" ]; then
          profile_name=''${profile_dir##*/}
          mkdir -p "$HOME/.dotfiles/.mozilla/firefox/$profile_name/chrome"
      fi

      # Copy each file
      for file in "''${files[@]}"; do
          if [[ $file == *"/firefox/*/"* ]]; then
              # Handle Firefox profile directory wildcard
              if [ -n "$profile_dir" ]; then
                  # Get the path after the wildcard
                  suffix="''${file#*.mozilla/firefox/*/}"
                  # Construct the actual source and destination paths
                  src="$profile_dir/$suffix"
                  dst="$HOME/.dotfiles/.mozilla/firefox/$profile_name/$suffix"
                  if [ -f "$src" ]; then
                      echo "Copying $suffix from Firefox profile"
                      cp "$src" "$dst" 2>/dev/null || true
                  fi
              fi
          else
              # Handle regular files
              if [ -f "$HOME/$file" ]; then
                  echo "Copying $file"
                  cp "$HOME/$file" "$HOME/.dotfiles/$file" 2>/dev/null || true
              fi
          fi
      done
  }

  # Call the copy_dotfiles function
  copy_dotfiles

  echo "Stowing dotfiles..." | tee -a "$TEMP_FILE"
  if ${stow}/bin/stow -vR --adopt . -d "$DOTFILES_PATH" -t "$ACTUAL_HOME" 2> >(tee -a "$FAILURE_LOG" >&2); then
      STOW_SUCCESS=1
  else
      echo "Some files could not be stowed. Check the failure log for details." | tee -a "$TEMP_FILE"
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" ${libnotify}/bin/notify-send "Stow Failure" "Some dotfiles could not be stowed. Check the failure log at: $FAILURE_LOG" --icon=dialog-error
  fi

  if [ $STOW_SUCCESS -eq 1 ]; then
      cd "$DOTFILES_PATH"

      # Fixed git status check
      if [ -n "$(git status --porcelain)" ]; then
          echo "Changes detected, committing..." | tee -a "$TEMP_FILE"
          git add .
          git commit -m "Updated dotfiles: $(date '+%Y-%m-%d %H:%M:%S')"
          git push -u origin main
      else
          echo "No changes detected, skipping commit."
      fi
  else
      echo "Skipping git operations due to stow failures." | tee -a "$TEMP_FILE"
  fi

  echo "Log file available at: $TEMP_FILE"
  echo "Failure log file available at: $FAILURE_LOG"

  # Exit with appropriate status
  [ $STOW_SUCCESS -eq 1 ]
''
