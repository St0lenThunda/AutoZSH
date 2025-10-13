#!/bin/bash
# Safety first: combine strict unset/pipe handling with explicit exit checks for critical commands.
set -u
set -o pipefail

# According to: https://medium.com/@shivam1/make-your-terminal-beautiful-and-fast-with-zsh-shell-and-powerlevel10k-6484461c6efb
# My ZSH install
# This script installs and configures ZSH with Oh-My-Zsh and several popular plugins and themes. I liked the idea of a one line installer. 

# Includes: 
# - nerd fonts
# - powerline10k theme
# - auto-suggestion/syntax highlighting plugins
# - etc
#
# Installing from command line:
# bash -c "$(curl -fsSL https://raw.githubusercontent.com/St0lenThunda/AutoZSH/main/zsh_autoinstall.sh)"

# Predeclare variables so `set -u` (treat unset variables as errors) stays happy.
SUDO=""
ROLLBACK_REQUESTED=false

# usage prints the public help text (only documenting the supported user-facing flags).
usage() {
  cat <<'EOF'
Usage: zsh_autoinstall.sh [-h]
  -h    Show this help message
EOF
}

# Hidden rollback flag (-r) remains available for advanced testing but intentionally undocumented.

# rollback attempts to rewind the actions performed by the installer for quick testing loops.
rollback() {
  echo "AutoZSH rollback starting..."

  # Default to Oh My Zsh's custom directory layout unless the caller overrides ZSH_CUSTOM.
  local zsh_custom_dir="${ZSH_CUSTOM:-"$HOME/.oh-my-zsh/custom"}"

  # Restore the newest timestamped backup if we had previously generated one.
  if compgen -G "$HOME"/.zshrc.autozsh.*.bak >/dev/null; then
    # Use ls -t to sort by modification time and pick the latest entry with head -n1.
    local latest_backup
    latest_backup=$(ls -t "$HOME"/.zshrc.autozsh.*.bak 2>/dev/null | head -n 1)
    if [ -n "$latest_backup" ] && cp "$latest_backup" "$HOME/.zshrc"; then
      echo "Restored ~/.zshrc from backup: $latest_backup"
    else
      echo "Failed to restore ~/.zshrc from the AutoZSH backup set." >&2
      exit 1
    fi
  else
    echo "No AutoZSH backup found; leaving ~/.zshrc untouched."
  fi

  # Cautiously remove the theme/plugin directories we manage, validating they live under $HOME first.
  local managed_paths=(
    "$zsh_custom_dir/themes/powerlevel10k"
    "$zsh_custom_dir/plugins/zsh-autosuggestions"
    "$zsh_custom_dir/plugins/zsh-syntax-highlighting"
  )

  for managed_path in "${managed_paths[@]}"; do
    case "$managed_path" in
      "$HOME"/*)
        if [ -d "$managed_path" ]; then
          if rm -rf "$managed_path"; then
            echo "Removed AutoZSH-managed directory: $managed_path"
          else
            echo "Failed to remove $managed_path" >&2
            exit 1
          fi
        else
          echo "No AutoZSH directory at $managed_path; skipping."
        fi
        ;;
      *)
        echo "Refusing to touch unexpected path outside \$HOME: $managed_path" >&2
        ;;
    esac
  done

  echo "Rollback complete. Remove packages (zsh/fonts) manually with apt if you installed them solely for testing."
}

# Parse command-line switches before doing any installation work.
# Note: -r is silently supported for internal testing but omitted from user-facing docs.
while getopts ":rh" opt; do
  case "$opt" in
    r)
      # Hidden rollback flag toggles the cleanup flow.
      ROLLBACK_REQUESTED=true
      ;;
    h)
      usage
      exit 0
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      exit 1
      ;;
  esac
done
shift $((OPTIND - 1))

# Exit early if the caller asked for a rollback-only run.
if [ "$ROLLBACK_REQUESTED" = true ]; then
  rollback
  exit 0
fi

# Installation mode begins here. Confirm we are on an apt-based system before continuing.
if ! command -v apt >/dev/null 2>&1; then
  echo "apt not found on PATH. This installer currently supports Debian/Ubuntu systems only." >&2
  exit 1
fi

# We need root access for package installation; use sudo when available.
if [ "$EUID" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "This installer needs root privileges for package installs. Re-run with sudo or as root." >&2
    exit 1
  fi
fi

if [ -n "$SUDO" ]; then
  echo "Using sudo for package installation. You may be prompted for your password."
  echo
  echo
fi

# ensure_clone is a reusable helper that keeps git repositories up to date without breaking re-runs.
ensure_clone() {
  local repo="$1"   # Repository URL we want to ensure exists locally.
  local dest="$2"   # Destination path on disk where the repo should live.

  if [ -d "$dest/.git" ]; then
    echo "Updating existing $(basename "$dest")..."
    if ! git -C "$dest" pull --ff-only; then
      echo "Failed to update repository at $dest" >&2
      exit 1
    fi
  elif [ -d "$dest" ]; then
    echo "Skipping clone of $repo because $dest already exists and is not a git repo."
  else
    if ! git clone "$repo" "$dest"; then
      echo "Failed to clone $repo into $dest" >&2
      exit 1
    fi
  fi
}
# Install core shell binary; ${SUDO} is empty when already root.
echo "Installing ZSH..."
if ! ${SUDO} apt install -y zsh; then
  echo "Failed to install zsh via apt." >&2
  exit 1
fi
echo
echo
# Oh My Zsh bootstrap script sets up ~/.oh-my-zsh and drops a starter ~/.zshrc.
echo "Installing Oh-My-Zsh..."
if ! RUNZSH=no CHSH=no bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"; then
  echo "Oh My Zsh installer failed; aborting." >&2
  exit 1
fi
 
echo
echo
# Clone or update the Powerlevel10k prompt theme inside the custom themes directory.
echo "Install PowerLevel10K theme..."
ZSH_CUSTOM=${ZSH_CUSTOM:-"$HOME/.oh-my-zsh/custom"}
ensure_clone https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
 
echo
echo
# Grab a programmer-friendly font with glyph support; adjust here if you prefer a different face.
echo "Installing Nerd Fonts..."
# git clone https://github.com/ryanoasis/nerd-fonts && ./nerd-fonts/install.sh  ## download all fonts
# git clone https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/FiraMono/Regular/complete && ./nerd-fonts/install.sh FiraMono &
if ! ${SUDO} apt install -y fonts-firacode; then
  echo "Failed to install fonts-firacode via apt." >&2
  exit 1
fi
 
echo
echo
# Pull down the helper plugins that improve the interactive experience.
echo "Download Plugins for autosuggestion and syntax highlighting..."
ensure_clone https://github.com/zsh-users/zsh-autosuggestions.git "$ZSH_CUSTOM/plugins/zsh-autosuggestions" 
ensure_clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" 

echo
echo
# Create a safety net before we start editing the user's configuration file.
# Todo: consider allowing opt-out for heavy customizers who track dotfiles in git.

if [ -f "$HOME/.zshrc" ]; then
  BACKUP_PATH="$HOME/.zshrc.autozsh.$(date +%Y%m%d%H%M%S).bak"
  if cp "$HOME/.zshrc" "$BACKUP_PATH"; then
    echo "Backed up ~/.zshrc to $BACKUP_PATH"
  else
    echo "Failed to create backup at $BACKUP_PATH" >&2
    exit 1
  fi
  echo
  echo
fi

# Flip the default theme to Powerlevel10k if it is not already active.
echo "Setting Powerlevel10k theme..."
if grep -q 'ZSH_THEME="powerlevel10k/powerlevel10k"' "$HOME/.zshrc"; then
  echo "Theme already set."
elif grep -q '^ZSH_THEME=' "$HOME/.zshrc"; then
  # The `0,` trick ensures only the first match is swapped, preserving any custom blocks beneath it.
  sed -i '0,/^ZSH_THEME=.*/s//ZSH_THEME="powerlevel10k\\/powerlevel10k"/' "$HOME/.zshrc"
else
  # Append at the end if the file never declared a theme; rare but safe.
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$HOME/.zshrc"
fi

echo
echo
# Turn on command autocorrection (corrects minor typos) when the flag is missing or commented out.
echo "Enabling AutoCorrection..."
if grep -q '^ENABLE_CORRECTION' "$HOME/.zshrc"; then
  echo "AutoCorrection already enabled."
elif grep -q '^# *ENABLE_CORRECTION="true"' "$HOME/.zshrc"; then
  # Uncomment a previously commented line that already uses the explicit ="true" syntax.
  sed -i '0,/^# *ENABLE_CORRECTION="true"/s//ENABLE_CORRECTION="true"/' "$HOME/.zshrc"
elif grep -q '^# *ENABLE_CORRECTION' "$HOME/.zshrc"; then
  # Swap any generic commented form with our preferred explicit value.
  sed -i '0,/^# *ENABLE_CORRECTION/s//ENABLE_CORRECTION="true"/' "$HOME/.zshrc"
else
  # Fall back to appending the directive when it never existed before.
  echo 'ENABLE_CORRECTION="true"' >> "$HOME/.zshrc"
fi

echo
echo
# Merge our required plugins with anything the user already had configured.
echo "Enabling plugins..."
required_plugins=("git" "zsh-autosuggestions" "zsh-syntax-highlighting")
# Grab the first plugins= line, if any; `|| true` keeps a missing match from breaking the script.
plugins_line=$(grep -m1 '^plugins=' "$HOME/.zshrc" || true)
if [ -z "${plugins_line}" ]; then
  echo "plugins=(${required_plugins[*]})" >> "$HOME/.zshrc"
else
  # shellcheck disable=SC2206
  # Split the existing plugin list into a bash array so we can de-duplicate entries.
  current_plugins=(${plugins_line#plugins=(})
  current_plugins=("${current_plugins[@]%)}")
  declare -A seen=()
  dedup=()
  for plugin in "${current_plugins[@]}"; do
    # Strip stray characters (commas, trailing parentheses) before tracking values.
    clean_plugin=${plugin//[^[:alnum:]\-_]/}
    if [ -n "$clean_plugin" ] && [ -z "${seen[$clean_plugin]:-}" ]; then
      dedup+=("$clean_plugin")
      seen["$clean_plugin"]=1
    fi
  done
  for plugin in "${required_plugins[@]}"; do
    if [ -z "${seen[$plugin]:-}" ]; then
      dedup+=("$plugin")
      seen["$plugin"]=1
    fi
  done
  new_plugins_line="plugins=(${dedup[*]})"
  if [ "$new_plugins_line" != "$plugins_line" ]; then
    # Replace only the first plugins= line, escaping slashes to keep sed happy.
    escaped_new_line=$(printf '%s\n' "$new_plugins_line" | sed 's/[\/&]/\\&/g')
    sed -i "0,/^plugins=.*/s//${escaped_new_line}/" "$HOME/.zshrc"
  else
    echo "Required plugins already enabled."
  fi
fi


echo
echo "Installation complete."
# Remind learners that configuration changes take effect the next time zsh starts.
echo "Open a new zsh session (or run 'zsh') to load the updated configuration."
echo "Once inside zsh, run 'p10k configure' to customize the Powerlevel10k prompt."
