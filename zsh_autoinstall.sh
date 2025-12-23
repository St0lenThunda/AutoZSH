#!/bin/bash
# Safety first: strict mode
set -u
set -o pipefail
# We won't use set -e globally because we want to handle some errors manually, 
# but we will check exit codes for critical steps.

# ==============================================================================
# Constants & Configuration
# ==============================================================================
REPO_URL_P10K="https://github.com/romkatv/powerlevel10k.git"
REPO_URL_AUTOSUGGEST="https://github.com/zsh-users/zsh-autosuggestions.git"
REPO_URL_SYNTAX="https://github.com/zsh-users/zsh-syntax-highlighting.git"
REPO_URL_HISTORY="https://github.com/zsh-users/zsh-history-substring-search.git"
REPO_URL_COMPLETIONS="https://github.com/zsh-users/zsh-completions.git"
REPO_URL_YOUSHOULDUSE="https://github.com/MichaelAquilina/zsh-you-should-use.git"
OHMYZSH_INSTALL_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"

# Fonts
FONT_DIR="$HOME/.local/share/fonts"
declare -A FONTS=(
  ["MesloLGS NF Regular.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf"
  ["MesloLGS NF Bold.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold.ttf"
  ["MesloLGS NF Italic.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Italic.ttf"
  ["MesloLGS NF Bold Italic.ttf"]="https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Bold%20Italic.ttf"
)

# Colors & Formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Global Flags
SUDO=""
ROLLBACK_REQUESTED=false
DRY_RUN=false
ZSH_CUSTOM=${ZSH_CUSTOM:-"$HOME/.oh-my-zsh/custom"}

# ==============================================================================
# Helper Functions
# ==============================================================================

show_banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    cat << "EOF"
    _         _        _____  _____ _   _ 
   / \  _   _| |_ ___ |__  / / ____| | | |
  / _ \| | | | __/ _ \  / / | (___ | |_| |
 / ___ \ |_| | || (_) |/ /_  \___ \|  _  |
/_/   \_\__,_|\__\___/____| |_____/|_| |_|
                                          
EOF
    echo -e "${NC}"
    echo -e "${PURPLE}${BOLD}   >>> The Ultimate ZSH Experience Installer <<<   ${NC}"
    echo -e "${BLUE}   ===============================================   ${NC}"
    echo ""
}

log_info() { echo -e "${BLUE}${BOLD} ℹ️  INFO:${NC} $1"; }
log_success() { echo -e "${GREEN}${BOLD} ✅ SUCCESS:${NC} $1"; }
log_warn() { echo -e "${YELLOW}${BOLD} ⚠️  WARN:${NC} $1"; }
log_error() { echo -e "${RED}${BOLD} ❌ ERROR:${NC} $1" >&2; }
log_section() { 
    echo ""
    echo -e "${CYAN}${BOLD}==================== [ $1 ] ====================${NC}"
    echo ""
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

run_with_spinner() {
    local msg="$1"
    shift
    local cmd="$@"
    
    echo -ne "${BLUE}${BOLD} 🚀 ${msg}...${NC}"
    
    # Run command in background, suppress output
    eval "$cmd" > /dev/null 2>&1 &
    local pid=$!
    
    # Show spinner
    spinner $pid
    
    # Wait for exit code
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}${BOLD} ✅ Done!${NC}"
    else
        echo -e "${RED}${BOLD} ❌ Failed!${NC}"
        # If crucial, we might want to exit or let the caller handle it.
        # For now, return the code so caller can decide.
        return $exit_code
    fi
}

usage() {
  cat <<EOF
Usage: $(basename "$0") [-h] [-d]
  -h    Show this help message
  -d    Dry run (check environment only)
EOF
}

# check_dependencies verifies critical tools map nicely.
check_dependencies() {
  local missing=()
  for cmd in curl git; do
    if ! command -v "$cmd" &>/dev/null; then
      missing+=("$cmd")
    fi
  done
  
  if [ ${#missing[@]} -gt 0 ]; then
    log_error "Missing required dependencies: ${missing[*]}"
    log_error "Please install them first (e.g., sudo apt install git curl)."
    exit 1
  fi
}

ensure_clone() {
  local repo="$1"
  local dest="$2"
  local name
  name=$(basename "$dest")

  if [ -d "$dest/.git" ]; then
    run_with_spinner "Updating $name" "git -C \"$dest\" pull --ff-only" || log_warn "Failed to update $dest, skipping."
  elif [ -d "$dest" ]; then
    log_warn "Directory $dest exists but is not a git clone. Skipping."
  else
    run_with_spinner "Cloning $name" "git clone --depth=1 \"$repo\" \"$dest\"" || {
      log_error "Failed to clone $repo"
      exit 1
    }
  fi
}

# ==============================================================================
# Core Functions
# ==============================================================================

prepare_environment() {
  # Root check
  if [ "$EUID" -eq 0 ]; then
    log_error "Please run as a normal user, not root."
    exit 1
  fi

  # Sudo check
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    log_error "sudo is required for package installation."
    exit 1
  fi

  # Pkg manager check (Currently apt-only as per original script)
  if ! command -v apt >/dev/null 2>&1; then
    log_error "This installer currently supports Debian/Ubuntu systems with apt only."
    exit 1
  fi
}

install_packages() {
  log_section "System Packages"
  
  if ! $SUDO apt update -y >/dev/null 2>&1; then
     log_warn "apt update failed, trying to proceed anyway..."
  fi
  
  run_with_spinner "Installing zsh, git, curl, wget, fonts-firacode" "$SUDO apt install -y zsh git curl wget fonts-firacode" || {
    log_error "Package installation failed."
    exit 1
  }
}

install_omz() {
  log_section "Oh My Zsh"
  if [ -d "$HOME/.oh-my-zsh" ]; then
    log_info "Oh My Zsh is already installed. Skipping."
    return
  fi

  # Prevent OMZ from starting zsh immediately
  run_with_spinner "Installing Oh My Zsh" "RUNZSH=no CHSH=no curl -fsSL \"$OHMYZSH_INSTALL_URL\" | bash" || {
    log_error "Oh My Zsh installation failed."
    exit 1
  }
}

install_p10k() {
  log_section "Powerlevel10k"
  ensure_clone "$REPO_URL_P10K" "$ZSH_CUSTOM/themes/powerlevel10k"
}

install_fonts() {
  log_section "Nerd Fonts"
  mkdir -p "$FONT_DIR"

  for font in "${!FONTS[@]}"; do
    if [ -f "$FONT_DIR/$font" ]; then
      log_info "$font exists, skipping."
    else
      run_with_spinner "Downloading $font" "curl -fsSL -o \"$FONT_DIR/$font\" \"${FONTS[$font]}\"" || log_warn "Failed to download $font"
    fi
  done

  if command -v fc-cache >/dev/null 2>&1; then
    run_with_spinner "Refreshing font cache" "fc-cache -f \"$FONT_DIR\""
  else
    log_warn "fc-cache not found, skipping cache refresh."
  fi
}

install_cool_tools() {
  log_section "Cool Tools"

  # 1. fzf
  if ! command -v fzf >/dev/null 2>&1; then
    run_with_spinner "Installing fzf" "$SUDO apt install -y fzf" || log_warn "Failed to install fzf"
  else
    log_info "fzf already installed."
  fi

  # 2. zoxide
  if ! command -v zoxide >/dev/null 2>&1; then
    run_with_spinner "Installing zoxide" "curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash" || log_warn "Failed to install zoxide"
  else
    log_info "zoxide already installed."
  fi

  # 3. eza
  if ! command -v eza >/dev/null 2>&1; then
    setup_eza_repo() {
        if ! command -v gpg >/dev/null 2>&1; then $SUDO apt install -y gpg; fi
        $SUDO mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | $SUDO gpg --dearmor --yes -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | $SUDO tee /etc/apt/sources.list.d/gierens.list > /dev/null
        $SUDO chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
        $SUDO apt update -y
    }
    
    run_with_spinner "Setting up eza repository" setup_eza_repo || log_warn "Failed to setup eza repo"
    run_with_spinner "Installing eza" "$SUDO apt install -y eza" || log_warn "Failed to install eza"
  else
    log_info "eza already installed."
  fi
}


install_bat() {
  if ! command -v bat >/dev/null 2>&1 && ! command -v batcat >/dev/null 2>&1; then
    run_with_spinner "Installing bat" "$SUDO apt install -y bat" || log_warn "Failed to install bat"
  else
    log_info "bat already installed."
  fi
}

install_tldr() {
  if ! command -v tldr >/dev/null 2>&1; then
    run_with_spinner "Installing tldr" "$SUDO apt install -y tldr" || log_warn "Failed to install tldr"
  else
    log_info "tldr already installed."
  fi
}

# Global array to hold selections
SELECTED_CHOICES=()

interactive_plugin_selection() {
  # Skip if dry run
  if [ "$DRY_RUN" = true ]; then return; fi

  log_section "Plugin Selection"
  
  # Ensure we have a tty
  if [ ! -t 1 ]; then
    log_warn "Non-interactive shell or no TTY detected. Installing default set only."
    return
  fi

  local options=("History Substring Search" "Zsh Completions" "You Should Use" "Bat" "TLDR")
  local descriptions=(
    "Cycle through history entries that match the command line prefix"
    "Additional completion definitions for Zsh"
    "Reminds you of existing aliases for commands you just typed"
    "A cat clone with syntax highlighting and git integration"
    "Simplified and community-driven man pages"
  )
  # Internal IDs
  local ids=("history-substring-search" "zsh-completions" "you-should-use" "bat" "tldr")
  
  # Default selection state (false by default)
  local selected=(false false false false false)
  local current_idx=0
  
  # Save cursor position if possible, but clear screen is safer for full menu
  # We'll use a loop to redraw
  
  # Hide cursor
  echo -ne "\033[?25l"
  
  # Trap to ensure cursor is restored and stty is reset
  trap 'stty echo; echo -ne "\033[?25h"; exit 1' INT TERM
  
  while true; do
      # Move cursor to top left of output area? 
      # Simpler: Clear screen for the menu (user experience is flashy anyway)
      # But we want to keep previous logs visible? Hard in simple bash script.
      # Let's clear screen to focus on menu.
      clear
      
      echo -e "${CYAN}${BOLD}   Select Optional Plugins & Tools${NC}"
      echo -e "   Use ${YELLOW}Up/Down${NC} to navigate, ${YELLOW}Space${NC} to toggle, ${YELLOW}Enter${NC} to confirm"
      echo ""
      
      for i in "${!options[@]}"; do
          local box="[ ]"
          if [ "${selected[$i]}" = true ]; then box="[x]"; fi
          
          if [ $i -eq $current_idx ]; then
              echo -e "${GREEN} > $box ${options[$i]}${NC}  - ${descriptions[$i]}"
          else
              echo -e "   $box ${options[$i]}     - ${descriptions[$i]}"
          fi
      done
      
      # Read input from /dev/tty
      # Read input from /dev/tty
      local key=""
      # Read one character (silent)
      # IFS= ensures space is not trimmed
      if ! IFS= read -rsn1 key < /dev/tty; then
         # If read fails (e.g. timeout or no tty), break to avoid infinite loop
         break
      fi
      
      # Handle special keys
      if [[ "$key" == $'\x1b' ]]; then
          # It's an escape sequence, try to read the next 2 characters
          # use a small timeout to distinguish between ESC key and escape sequence
          # (though manual ESC press is unlikely to match [A within 0.1s usually)
          local seq=""
          if read -rsn2 -t 0.1 seq < /dev/tty; then
              if [[ "$seq" == "[A" || "$seq" == "OA" ]]; then # Up
                  key="UP"
              elif [[ "$seq" == "[B" || "$seq" == "OB" ]]; then # Down
                  key="DOWN"
              fi
          fi
      fi
      
      # Logic based on key
      if [[ "$key" == "UP" || "$key" == "k" ]]; then
          ((current_idx--))
          if [ $current_idx -lt 0 ]; then current_idx=$((${#options[@]} - 1)); fi
      elif [[ "$key" == "DOWN" || "$key" == "j" ]]; then
          ((current_idx++))
          if [ $current_idx -ge ${#options[@]} ]; then current_idx=0; fi
      elif [[ "$key" == "" ]]; then # Enter (empty string from read -n1 usually means newline? Wait read -n1 returns emptiness for newline? Yes.)
          # Actually read -n1 returns empty string for Enter/Newline.
          break
      elif [[ "$key" == " " ]]; then # Space
          if [ "${selected[$current_idx]}" = true ]; then
             selected[$current_idx]=false
          else
             selected[$current_idx]=true
          fi
      fi
  done
  
  # Restore cursor
  echo -ne "\033[?25h"
  
  # Populate SELECTED_CHOICES
  for i in "${!selected[@]}"; do
      if [ "${selected[$i]}" = true ]; then
          SELECTED_CHOICES+=("${ids[$i]}")
      fi
  done
  
  # Clear screen one last time or just print summary
  echo ""
  log_info "Selected: ${SELECTED_CHOICES[*]}"
  sleep 1
}

install_plugins() {
  log_section "ZSH Plugins"
  ensure_clone "$REPO_URL_AUTOSUGGEST" "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
  ensure_clone "$REPO_URL_SYNTAX" "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
  
  # Optional Plugins
  if [[ " ${SELECTED_CHOICES[*]} " =~ " history-substring-search " ]]; then
      ensure_clone "$REPO_URL_HISTORY" "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
  fi
  if [[ " ${SELECTED_CHOICES[*]} " =~ " zsh-completions " ]]; then
      ensure_clone "$REPO_URL_COMPLETIONS" "$ZSH_CUSTOM/plugins/zsh-completions"
  fi
  if [[ " ${SELECTED_CHOICES[*]} " =~ " you-should-use " ]]; then
      ensure_clone "$REPO_URL_YOUSHOULDUSE" "$ZSH_CUSTOM/plugins/you-should-use"
  fi
  
  # Optional Tools
  if [[ " ${SELECTED_CHOICES[*]} " =~ " bat " ]]; then install_bat; fi
  if [[ " ${SELECTED_CHOICES[*]} " =~ " tldr " ]]; then install_tldr; fi
}

configure_zshrc() {
  log_section "Configuration"
  local zshrc="$HOME/.zshrc"
  
  # Backup
  if [ -f "$zshrc" ]; then
    local backup_path="$HOME/.zshrc.autozsh.$(date +%Y%m%d%H%M%S).bak"
    cp "$zshrc" "$backup_path"
    log_info "Backed up .zshrc to $backup_path"
  fi

  # Apply Theme
  log_info "Configuring .zshrc settings..."
  if grep -q '^ZSH_THEME=' "$zshrc"; then
    # Replace the whole line line, preserving quotes if possible, or forcing our own.
    sed -i 's/^ZSH_THEME=.*/ZSH_THEME="powerlevel10k\/powerlevel10k"/' "$zshrc"
  else
    echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$zshrc"
  fi

  # Enable Corrections
  # If explicitly disabled/commented, enable it.
  sed -i 's/^# *ENABLE_CORRECTION="true"/ENABLE_CORRECTION="true"/' "$zshrc" 
  # If not present at all, you might append, but OMZ usually has it commented.
  
  # Configure Plugins
  # We want: plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf ...)
  # For robustness, let's just ensure our required ones are added.
  local required_plugins="zsh-autosuggestions zsh-syntax-highlighting fzf"

  # Add optional plugins
  if [[ " ${SELECTED_CHOICES[*]} " =~ " history-substring-search " ]]; then required_plugins+=" zsh-history-substring-search"; fi
  if [[ " ${SELECTED_CHOICES[*]} " =~ " zsh-completions " ]]; then required_plugins+=" zsh-completions"; fi
  if [[ " ${SELECTED_CHOICES[*]} " =~ " you-should-use " ]]; then required_plugins+=" you-should-use"; fi

  for plugin in $required_plugins; do
    if ! grep -q "$plugin" "$zshrc"; then
        if grep -q "^plugins=(" "$zshrc"; then
            sed -i "s/^plugins=(/plugins=($plugin /" "$zshrc"
        else
            echo "plugins=($plugin)" >> "$zshrc"
        fi
    fi
  done
  
  # Zoxide Init
  if ! grep -q "zoxide init zsh" "$zshrc"; then
    echo >> "$zshrc"
    echo '# zoxide (smart cd)' >> "$zshrc"
    # Ensure ~/.local/bin is in PATH for zoxide
    if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$zshrc"
    fi
    echo 'eval "$(zoxide init zsh)"' >> "$zshrc"
  fi

  # Eza Aliases
  if ! grep -q "alias ls='eza" "$zshrc"; then
      echo >> "$zshrc"
      echo '# eza (modern ls)' >> "$zshrc"
      echo "alias ls='eza --icons'" >> "$zshrc"
      echo "alias ll='eza --icons -l'" >> "$zshrc"
  fi
  
  # Bat alias (batcat -> bat)
  if command -v batcat >/dev/null 2>&1; then
      if ! grep -q "alias bat='batcat'" "$zshrc"; then
          echo >> "$zshrc"
          echo "alias bat='batcat'" >> "$zshrc"
      fi
  fi
  
  log_success "Configuration updated."
}

set_default_shell() {
  if [ "$(basename "$SHELL")" != "zsh" ]; then
    log_info "Changing default shell to zsh..."
    chsh -s "$(which zsh)" || log_warn "Failed to change shell. You may need to do 'chsh -s $(which zsh)' manually."
  fi
}

rollback() {
  log_info "Rollback requested."
  local zsh_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
  
  # Restore backup
  local latest_backup
  latest_backup=$(ls -t "$HOME"/.zshrc.autozsh.*.bak 2>/dev/null | head -n 1)
  if [ -n "$latest_backup" ]; then
    log_info "Restoring backup from $latest_backup..."
    cp "$latest_backup" "$HOME/.zshrc"
    log_success "Restored .zshrc from $latest_backup"
  else
    log_warn "No .zshrc backup found to restore."
  fi

  # Remove dirs
  log_info "Removing Powerlevel10k..."
  rm -rf "$zsh_custom/themes/powerlevel10k"

  log_info "Removing zsh-autosuggestions..."
  rm -rf "$zsh_custom/plugins/zsh-autosuggestions"

  log_info "Removing zsh-syntax-highlighting..."
  rm -rf "$zsh_custom/plugins/zsh-syntax-highlighting"

  # Optional: remove OMZ entirely
  if [ -d "$HOME/.oh-my-zsh" ]; then
      read -rp "Do you also want to remove Oh My Zsh completely? [y/N] " remove_omz
      if [[ "$remove_omz" =~ ^[yY]$ ]]; then
          log_info "Removing Oh My Zsh..."
          rm -rf "$HOME/.oh-my-zsh"
          log_success "Oh My Zsh removed."
      else
          log_info "Keeping Oh My Zsh installation."
      fi
  fi
  
  log_success "Rollback complete."
}

show_completion_msg() {
  echo
  log_success "Installation Complete!"
  echo "------------------------------------------------------------------"
  if grep -qEi "(Microsoft|WSL)" /proc/version &>/dev/null; then
    echo -e "${YELLOW}WSL DETECTED:${NC}"
    echo "1. Install MesloLGS NF fonts on Windows manually."
    echo "2. Configure Windows Terminal to use 'MesloLGS NF'."
    echo "3. Restart your terminal."
  else
    echo "1. Configure your terminal emulator to use 'MesloLGS NF' font."
    echo "2. Restart your terminal or run 'zsh'."
  fi
  echo "------------------------------------------------------------------"
  echo "Run 'p10k configure' in zsh to set up your prompt."
  echo "  (Note: If p10k configure fails, ensure your terminal window is at least 80x24)"
  echo "Use 'z <dir>' to jump around with zoxide!"
}

# ==============================================================================
# Helper for Status Checks
# ==============================================================================

check_status() {
  log_info "Checking component status..."
  
  # Packages
  if command -v zsh >/dev/null; then log_success "zsh: Installed"; else log_warn "zsh: Missing"; fi
  if command -v git >/dev/null; then log_success "git: Installed"; else log_warn "git: Missing"; fi
  if command -v curl >/dev/null; then log_success "curl: Installed"; else log_warn "curl: Missing"; fi
  
  # OMZ
  if [ -d "$HOME/.oh-my-zsh" ]; then log_success "Oh My Zsh: Installed"; else log_warn "Oh My Zsh: Missing"; fi
  
  # P10k
  if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then 
    log_success "Powerlevel10k: Installed"
  else 
    log_warn "Powerlevel10k: Missing"
  fi
  
  # Cool Tools
  if command -v fzf >/dev/null; then log_success "fzf: Installed"; else log_warn "fzf: Missing"; fi
  if command -v zoxide >/dev/null; then log_success "zoxide: Installed"; else log_warn "zoxide: Missing"; fi
  if command -v eza >/dev/null; then log_success "eza: Installed"; else log_warn "eza: Missing"; fi
}

# ==============================================================================
# Main Execution
# ==============================================================================

while getopts ":rhd" opt; do
  case "$opt" in
    r) ROLLBACK_REQUESTED=true ;;
    d) DRY_RUN=true ;;
    h) usage; exit 0 ;;
    \?) log_error "Invalid option: -$OPTARG"; usage; exit 1 ;;
  esac
done

if [ "$ROLLBACK_REQUESTED" = true ]; then
  rollback
  exit 0
fi

if [ "$DRY_RUN" = true ]; then
  show_banner
  log_info "Dry Run Mode Enabled. Checking environment..."
  check_dependencies
  prepare_environment
  check_status
  log_success "Dry run complete."
  exit 0
fi

# Existing Install Check
if [ -d "$HOME/.oh-my-zsh" ]; then
    echo -e "${YELLOW}AutoZSH seems to be installed (found ~/.oh-my-zsh).${NC}"
    read -rp "Do you want to uninstall/reset current setup? [y/N] " response
    if [[ "$response" =~ ^[yY]$ ]]; then
        rollback
        # After rollback, we can exit or continue. Usually rollback means "remove it".
        # If user wants to reinstall, they can run the script again.
        # But wait, if they say 'reset', maybe they want to reinstall immediately?
        # The request said "trigger uninstall confirmation".
        # Let's ask if they want to proceed with fresh install.
        read -rp "Uninstall complete. Proceed with fresh installation? [y/N] " reinstall_response
        if [[ ! "$reinstall_response" =~ ^[yY]$ ]]; then
            exit 0
        fi
    else
        log_info "Aborting installation to prevent overwriting existing setup."
        exit 0
    fi
fi



show_banner
log_info "Starting AutoZSH Installation..."

check_dependencies
prepare_environment
interactive_plugin_selection
install_packages
install_omz
install_p10k
install_cool_tools
install_fonts
install_plugins
configure_zshrc
set_default_shell
show_completion_msg
