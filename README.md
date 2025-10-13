## AutoZSH 0.0.1 (beta)

Opinionated one-shot installer for my preferred zsh environment.

---

## Requirements
- Debian/Ubuntu system with `apt`
- Internet access for cloning repositories and downloading fonts
- Root access (either run as `root` or have `sudo` available)

---

## Quickstart

```bash
curl -fsSL https://raw.githubusercontent.com/St0lenThunda/AutoZSH/main/zsh_autoinstall.sh | bash
```

The script prompts for `sudo` when needed. If `sudo` is not available, rerun the command as `root`.

---

## What the script installs
- `zsh`
- [Oh My Zsh](https://ohmyz.sh)
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) theme
- [Fira Code Nerd Font](https://github.com/tonsky/FiraCode)
- Plugins:
  - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
  - [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)

It also reconfigures `~/.zshrc` to enable:
- `ZSH_THEME="powerlevel10k/powerlevel10k"`
- `ENABLE_CORRECTION`
- `plugins=(git zsh-autosuggestions zsh-syntax-highlighting)`

During the configuration updates the installer first creates a timestamped backup of your existing `~/.zshrc` (e.g. `~/.zshrc.autozsh.20240414121530.bak`) so you can revert if something looks off.

---

## Post-install steps
1. Start a new zsh session: `zsh`
2. Run the Powerlevel10k wizard to pick a prompt style: `p10k configure`

These steps are interactive and must be completed manually inside zsh.

---

## Notes & limitations
- Idempotency: rerunning the script now pulls existing repos and merges plugin lists, but the `.zshrc` edits are still opinionated. Options: allow opting out of theme/plugin tweaks, expose flags for extra plugins, or template config snippets for easier customization.
- Distribution support: everything assumes `apt` and Debian-like paths. Options: detect distro via `/etc/os-release` and branch to the right package manager, or bail with a clearer message when `apt` is missing.
- Privilege requirements: package installs require root; the script shells out to `sudo` when possible. Consider adding a `--dry-run`/`--no-install` mode so users can review steps before elevating.
- Interactive follow-up: prompt customization still needs `p10k configure` inside zsh. You could ship a prebuilt `.p10k.zsh` profile, or add a flag that copies one into place.
- Backup strategy: the script writes timestamped `~/.zshrc.autozsh.*.bak` files. Heavy customizers may want to track dotfiles in version control for easier rollback.

---

## Roadmap ideas
- Add `--dry-run` and `--no-config` flags for safer reuse
- Auto-detect distro/package manager (`dnf`, `pacman`, `brew`, etc.)
- Offer optional prompt/profile presets (prebuilt `.p10k.zsh`, extra plugin sets)
