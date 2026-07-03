# `pi500-dotfiles`

## 🚀 Raspberry Pi OS Environment Setup

This repository contains the configuration files and scripts necessary to set up a personalized development environment on Raspberry Pi OS (Labwc/Wayland). It includes custom aliases (like `pbcopy`/`pbpaste`), Vim/ALE configuration for Python development, and custom window manager keybindings.

The installation is performed by the idempotent script `setup_rpi_env.sh` and the symlinking script `link_dotfiles.py`.

-----

## 💾 Installation Steps

Follow these steps on a fresh Raspberry Pi OS install to clone the repository and apply the configuration.

### 1\. Prerequisite: Clone the Repository

First, ensure `git` is installed and clone this repository into the designated source directory:

```bash
# Install git if needed (usually present on RPi OS)
sudo apt update
sudo apt install -y git

# Clone the repository
mkdir -pv ~/src
git clone https://github.com/dsnyder0pc/pi500-dotfiles.git ~/src/pi500-dotfiles

# Change into the directory for the next step
cd ~/src/pi500-dotfiles
```

### 2\. Configure PATH and Symlink Dotfiles

The first script prepares your shell by adding the custom `~/bin` directory to your `PATH` and then creates symbolic links for all configuration files.

By default, the script detects if the system is headless (e.g. running Raspberry Pi OS Lite or a system without a desktop compositor/server installed) and automatically skips window manager configs like `rc.xml`. You can also manually force this behavior.

> **Note:** This step requires the `link_dotfiles.py` script to be executable, and relies on the default `~/.bashrc` to check for and source the `~/.bash_aliases` file.

```bash
# Make the linking script executable
chmod +x ~/src/pi500-dotfiles/bin/link_dotfiles.py

# Run the linking script (automatically detects headless/no-GUI)
# To force headless mode, pass: ~/src/pi500-dotfiles/bin/link_dotfiles.py --headless
~/src/pi500-dotfiles/bin/link_dotfiles.py

# Manually source ~/.bashrc to load the new aliases and correctly set PATH
source ~/.bashrc
```

### 3\. Install Development Environment

This step runs the main setup script. It is **idempotent**, meaning you can run it multiple times without duplication errors.

By default, the script automatically detects if the system is headless (e.g., systemd's default target is not `graphical.target` or there is no Wayland/X11 window manager installed). If headless, it skips all GUI-specific dependencies (such as Wayland window tools).

The script performs the following actions:

  * Installs system dependencies (`build-essential`, `vim`, `tmux`, `tk-dev`, `curl`, `nginx`, `mariadb-server`, `uwsgi`, etc. + Wayland/GUI tools if not headless).
  * Installs and configures **pyenv**.
  * Installs the **latest stable Python 3.x** and sets it as the global default.
  * Installs Python web stack and dev tools (`pylint`, `pytest`, `Flask`, `pymysql`, `requests`, `cryptography`, etc.).
  * Installs and updates the **ALE** Vim plugin for linting and syntax checking.
  * Installs the **Antigravity CLI** (`agy`) to enable terminal-based AI chat.

<!-- end list -->

```bash
# Run the idempotent setup script (automatically detects headless/no-GUI)
# To force headless mode, pass: bash ~/src/pi500-dotfiles/bin/setup_rpi_env.sh --headless
bash ~/src/pi500-dotfiles/bin/setup_rpi_env.sh
```

-----

## 📝 Customizations Included

### Shell Aliases and Clipboard (`~/.bash_aliases`)

Adds standard clipboard commands that dynamically adapt to your environment:

  * **Wayland Session**: Uses `wl-copy`/`wl-paste` via `wl-clipboard`.
  * **X11 Session**: Uses `xclip` if available.
  * **Tmux Session**: Uses `tmux load-buffer` / `save-buffer`.
  * **Headless/Terminal Session**: Falls back to copying and pasting via a local temporary file (`~/.clipboard`).
  * `pbcopy`: Pipes input to the system/fallback clipboard.
      * Example: `echo "text to copy" | pbcopy`
  * `pbpaste`: Prints clipboard content to stdout.
      * Example: `pbpaste > file.txt`
  * `agy-pop`: Launches the Antigravity TUI inside a centered, floating `tmux` popup window.

### Vim Editor (`~/.vimrc`)

  * Enables **syntax highlighting** (`syntax on`).
  * Enforces **2-space indentation** globally and specifically for Python file types.
  * Enables the ALE plugin for asynchronous linting using `pylint` and other tools.

### Tmux Configuration (`~/.tmux.conf`)

* Enables vi-mode keyboard shortcuts for copy-mode.
* Enables terminal clipboard passing (`set-clipboard on`) so that yank/copy commands inside `tmux` (including `agy`'s copy actions) pass through to the system clipboard.

### Antigravity CLI (`~/.gemini/antigravity-cli/settings.json`)

* Configures preferred model preferences.
* Pre-configures command execution permissions for typical developer workflows (e.g., git, pylint, shellcheck).
* Registers trusted workspace directories.

### Window Manager (`~/.config/labwc/rc.xml`)

Includes custom keybindings, such as:

  * **Window Snapping:** `Ctrl+Alt+Left/Right`
  * **Desktop Switching:** `Win+Ctrl+Left/Right`
  * **Terminal Launch:** `Ctrl+Alt+t` launches `lxterminal`

