## AutoZSH v1.1.0 - The "Flashy" Update

Opinionated one-shot installer for my preferred zsh environment.
I find myself setting up zsh on new machines over and over, so I made this script to save time.

---

## Requirements
- Debian/Ubuntu system with `apt` (script checks for `apt` and exits gracefully if missing)
- Internet access for cloning repositories and downloading fonts
- Root access (either run as `root` or have `sudo` available)

---

## Quickstart

```bash
curl -fsSL https://raw.githubusercontent.com/St0lenThunda/AutoZSH/main/zsh_autoinstall.sh | bash
```

The script prompts for `sudo` when needed. If `sudo` is not available, rerun the command as `root`.

### Dry Run (Environment Check)
To test if your environment is ready (without making any changes), use:
```bash
bash zsh_autoinstall.sh --dry-run
```
or
```bash
bash zsh_autoinstall.sh -d
```
If piping from curl:
```bash
curl -fsSL https://raw.githubusercontent.com/St0lenThunda/AutoZSH/main/zsh_autoinstall.sh | bash -s -d
```
This prints environment info and exits without installing anything.

---

## Included Plugins & Tools

The installer now features an **Interactive Plugin Selection** menu, allowing you to customize your installation by choosing which optional plugins and tools you want.

### Core Components (Always Installed)
| Tool | Purpose | Benefits |
|------|---------|----------|
| **Zsh** | Shell | A powerful shell that operates as both an interactive shell and a scripting language interpreter. |
| **Oh My Zsh** | Framework | Manages your Zsh configuration, themes, and plugins seamlessly. |
| **Powerlevel10k** | Theme | A fast, flexible, and cool-looking theme for Zsh that provides instant context. |
| **MesloLGS NF** | Font | The recommended font for Powerlevel10k to display all icons and glyphs correctly. |
| **fzf** | Fuzzy Finder | Allows you to search your history, files, and directories with fuzzy matching. |
| **zoxide** | Smart Directory Jumper | Learns your habits and allows you to jump to frequently used directories with `z <partial_name>`. |
| **eza** | Modern `ls` | A substitute for `ls` that features color-coding, icons, and git integration. |
| **zsh-autosuggestions** | Autosuggestions | Suggests commands as you type based on your history. |
| **zsh-syntax-highlighting** | Syntax Highlighting | Highlighting of commands while they are typed at a zsh prompt. |

### Optional Selection (Interactive Menu)
| Tool/Plugin | Category | Purpose |
|-------------|----------|---------|
| **History Substring Search** | Plugin | Cycle through history entries that match the command line prefix. |
| **Zsh Completions** | Plugin | Additional completion definitions for Zsh. |
| **You Should Use** | Plugin | Reminds you of existing aliases for commands you just typed. |
| **bat** | CLI Tool | A `cat` clone with syntax highlighting and git integration. |
| **tldr** | CLI Tool | Simplified and community-driven man pages. |

### Visual Enhancements 
- **Animated Spinners**: Progress indicators for long-running tasks.
- **Enhanced Logging**: Clear, color-coded messages with emojis (🚀 ℹ️ ✅ ⚠️ ❌).
- **ASCII Art Banner**: A stylish welcome screen.
- **Interactive Menu**: Custom bash-based menu for selecting optional plugins.

It also reconfigures `~/.zshrc` to enable:
- `ZSH_THEME="powerlevel10k/powerlevel10k"` (uses robust `sed` logic to set theme)
- `ENABLE_CORRECTION="true"`
- `plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf ...)`
- `alias ls='eza --icons'` and `alias ll='eza --icons -l'`
- `zoxide init zsh`

During configuration, the installer first creates a timestamped backup of your existing `~/.zshrc` (e.g. `~/.zshrc.autozsh.20240414121530.bak`) so you can revert if needed.

---

## Uninstall / Rollback

If you need to revert the changes, you can use the rollback feature:

```bash
bash zsh_autoinstall.sh -r
```

This will:
1. Restore your previous `.zshrc` from the backup.
2. Remove standard plugins and themes installed by this script.
3. **[New]** Optionally prompt you to completely remove the Oh My Zsh directory (`~/.oh-my-zsh`) for a full cleanup.

---

## Post-install steps
1. Start a new zsh session: `zsh`
2. Run the Powerlevel10k wizard to pick a prompt style: `p10k configure`

These steps are interactive and must be completed manually inside zsh.

---

## Notes & limitations
- Idempotency: rerunning the script now pulls existing repos and merges plugin lists, but the `.zshrc` edits are still opinionated. Options: allow opting out of theme/plugin tweaks, expose flags for extra plugins, or template config snippets for easier customization.
- Distribution support: everything assumes `apt` and Debian-like paths. Options: detect distro via `/etc/os-release` and branch to the right package manager, or bail with a clearer message when `apt` is missing.
- Privilege requirements: package installs require root; the script shells out to `sudo` when possible. Use `--dry-run`/`-d` to check environment readiness before elevating.
- Interactive follow-up: prompt customization still needs `p10k configure` inside zsh. You could ship a prebuilt `.p10k.zsh` profile, or add a flag that copies one into place.
- Backup strategy: the script writes timestamped `~/.zshrc.autozsh.*.bak` files. Heavy customizers may want to track dotfiles in version control for easier rollback.

---

## Roadmap ideas
- Auto-detect distro/package manager (`dnf`, `pacman`, `brew`, etc.)
- Offer optional prompt/profile presets (prebuilt `.p10k.zsh`, extra plugin sets)

