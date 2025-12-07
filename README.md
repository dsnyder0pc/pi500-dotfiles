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

> **Note:** This step requires the `link_dotfiles.py` script to be executable, and relies on the default `~/.bashrc` to check for and source the `~/.bash_aliases` file.

```bash
# Make the linking script executable
chmod +x ~/src/pi500-dotfiles/bin/link_dotfiles.py

# Run the linking script (this creates symlinks like ~/.bash_aliases)
~/src/pi500-dotfiles/bin/link_dotfiles.py

# Manually source ~/.bashrc to load the new aliases and correctly set PATH
source ~/.bashrc
```

### 3\. Install Development Environment

This step runs the main setup script. It is **idempotent**, meaning you can run it multiple times without duplication errors.

The script performs the following actions:

  * Installs system dependencies (`build-essential`, `vim`, `tmux`, `tk-dev`, etc.).
  * Installs and configures **pyenv**.
  * Installs the **latest stable Python 3.x** and sets it as the global default.
  * Installs Python development tools (`pylint`, `pytest`, `pipenv`, `numpy`).
  * Installs and updates the **ALE** Vim plugin for linting and syntax checking.

<!-- end list -->

```bash
# Run the idempotent setup script (this will take several minutes)
bash ~/src/pi500-dotfiles/bin/setup_rpi_env.sh
```

-----

## 📝 Customizations Included

### Shell Aliases and Clipboard (`~/.bash_aliases`)

Adds the following macOS-style clipboard commands using the `xsel` utility:

  * `pbcopy`: Pipes input to the system clipboard.
      * Example: `echo "text to copy" | pbcopy`
  * `pbpaste`: Prints the system clipboard content to stdout.
      * Example: `pbpaste > file.txt`

### Vim Editor (`~/.vimrc`)

  * Enables **syntax highlighting** (`syntax on`).
  * Enforces **2-space indentation** globally and specifically for Python file types.
  * Enables the ALE plugin for asynchronous linting using `pylint` and other tools.

### Window Manager (`~/.config/labwc/rc.xml`)

Includes custom keybindings, such as:

  * **Window Snapping:** `Ctrl+Alt+Left/Right`
  * **Desktop Switching:** `Win+Ctrl+Left/Right`
  * **Terminal Launch:** `Ctrl+Alt+t` launches `lxterminal`

