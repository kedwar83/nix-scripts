{ writeShellScriptBin
, coreutils
, git
, stow
, libnotify
, rsync
, findutils
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

  # Initialize/check git repository
  init_git_repo() {
      echo "Checking git repository setup..." | tee -a "$TEMP_FILE"

      # Create directory if it doesn't exist
      if [ ! -d "$DOTFILES_PATH" ]; then
          echo "Creating dotfiles directory..." | tee -a "$TEMP_FILE"
          mkdir -p "$DOTFILES_PATH"
      fi

      # Change to the dotfiles directory
      cd "$DOTFILES_PATH"

      # Initialize git if needed
      if [ ! -d "$DOTFILES_PATH/.git" ]; then
          echo "Initializing new git repository..." | tee -a "$TEMP_FILE"
          git init
          # Make sure it's a safe directory right after initialization
          git config --global --add safe.directory "$DOTFILES_PATH"
          # Create main branch and set it as default
          git checkout -b main
      else
          # Make sure it's a safe directory
          git config --global --add safe.directory "$DOTFILES_PATH"
      fi

      # Check for remote only if we have a git repository
      if [ -d "$DOTFILES_PATH/.git" ]; then
          if ! git remote get-url origin >/dev/null 2>&1; then
              echo "Setting up remote repository..." | tee -a "$TEMP_FILE"
              git remote add origin "git@github.com:kedwar83/.dotfiles.git"
          fi

          # Try to fetch only if we have a remote configured
          if git remote -v | grep -q origin; then
              echo "Fetching from remote..." | tee -a "$TEMP_FILE"
              git fetch origin || true
          fi

          # Ensure we're on the main branch
          if ! git rev-parse --verify main >/dev/null 2>&1; then
              echo "Creating main branch..." | tee -a "$TEMP_FILE"
              git checkout -b main
          else
              echo "Checking out main branch..." | tee -a "$TEMP_FILE"
              git checkout main || git checkout -b main
          fi
      fi
  }

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
  --include="*/" \
  --include=".*" \
  --exclude="*" \
  "$HOME/" "$HOME/.dotfiles/"

      # Define files to copy with relative paths from home directory
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

  # Main script execution
  if [ ! -f "$SETUP_FLAG" ]; then
      echo "First-time setup detected..." | tee -a "$TEMP_FILE"
      mkdir -p "$DOTFILES_PATH"
      init_git_repo
  else
      copy_dotfiles
  fi

  # Stow all dotfiles and capture the result
  echo "Stowing dotfiles..." | tee -a "$TEMP_FILE"
  if ${stow}/bin/stow -vR --adopt . -d "$DOTFILES_PATH" -t "$ACTUAL_HOME" 2> >(tee -a "$FAILURE_LOG" >&2); then
      STOW_SUCCESS=1
  else
      echo "Some files could not be stowed. Check the failure log for details." | tee -a "$TEMP_FILE"
      DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus" ${libnotify}/bin/notify-send "Stow Failure" "Some dotfiles could not be stowed. Check the failure log at: $FAILURE_LOG" --icon=dialog-error
  fi

  # Git operations only if stow was successful
  if [ $STOW_SUCCESS -eq 1 ]; then
      cd "$DOTFILES_PATH"

      if ! git diff --quiet || ! git ls-files --others --exclude-standard --quiet; then
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
