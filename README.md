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
sh -c "$(curl -fsSL https://raw.githubusercontent.com/StolenThunda/AutoZSH/master/zsh_autoinstall.sh)"
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
- The installer is not idempotent. Rerunning it without cleaning up may cause git clone failures or duplicate config entries.
- Tested only on Debian-based systems. Other distros will need manual tweaks (`apt` replacements, fonts, etc.).
- The script creates a timestamped `~/.zshrc` backup automatically, but keep your own copy if you rely on custom tweaks.

---

## Roadmap ideas
- Add idempotent checks around git clone and `~/.zshrc` edits
- Optional flag for different font choices
- Support for additional plugin bundles or theme variants
