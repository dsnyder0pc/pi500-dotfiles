#!/bin/bash

# --- Configuration ---

# Function to determine the latest stable Python 3.x version
get_latest_python_version() {
  # Filters for official 3.x.x releases and takes the last one (the newest)
  local latest_version

  # Check if pyenv is available in the current PATH
  if ! command -v pyenv &>/dev/null; then
    echo "Error: pyenv command not found. Cannot determine latest version." >&2
    return 1
  fi

  # Use a robust regex to find 3.x.x releases (e.g., '3.12.1', '3.11.8', etc.)
  latest_version=$(pyenv install --list 2>/dev/null | \
                   grep -E '^[[:space:]]*3\.[0-9]+\.[0-9]+[[:space:]]*$' | \
                   tail -n 1 | tr -d '[:space:]')

  echo "$latest_version"
}

# Python Version is initially set to empty so it can be resolved after pyenv is loaded
PYTHON_VERSION=""

VIM_PACK_DIR="$HOME/.vim/pack/git-plugins/start"
ALE_DIR="$VIM_PACK_DIR/ale"
ALE_REPO="https://github.com/dense-analysis/ale.git"

NAV_DIR="$VIM_PACK_DIR/vim-tmux-navigator"
NAV_REPO="https://github.com/christoomey/vim-tmux-navigator.git"

# List of build dependencies and development tools (split into common/GUI and Pacman/AUR)
PACMAN_COMMON_DEPS=(
  base-devel git zlib bzip2 xz expat libffi openssl ncurses readline util-linux db gdbm sqlite
  vim keychain shellcheck tmux mosh tk curl jq yq mariadb nginx uwsgi uwsgi-plugin-python
)

AUR_COMMON_DEPS=(
  vile
)

PACMAN_GUI_DEPS=(
  noto-fonts-emoji libpeas grim slurp wl-clipboard
)

AUR_GUI_DEPS=(
  xvile
)

# --- Auto-detection of Headless / Desktop Environment ---
# Detect if the OS has a GUI environment installed or configured by default.
HEADLESS=true
if command -v labwc &>/dev/null || command -v wayfire &>/dev/null || command -v hyprland &>/dev/null || command -v sway &>/dev/null || command -v Xorg &>/dev/null; then
  HEADLESS=false
elif command -v systemctl &>/dev/null && [ "$(systemctl get-default 2>/dev/null)" = "graphical.target" ]; then
  HEADLESS=false
fi

# Support manual override via flags
for arg in "$@"; do
  case $arg in
    --headless|--no-gui) HEADLESS=true ;;
    --gui) HEADLESS=false ;;
  esac
done

if [ "$HEADLESS" = true ]; then
  PACMAN_DEPS=("${PACMAN_COMMON_DEPS[@]}")
  AUR_DEPS=("${AUR_COMMON_DEPS[@]}")
  echo "=> Running in HEADLESS / NO-GUI mode. GUI packages will be skipped."
else
  PACMAN_DEPS=("${PACMAN_COMMON_DEPS[@]}" "${PACMAN_GUI_DEPS[@]}")
  AUR_DEPS=("${AUR_COMMON_DEPS[@]}" "${AUR_GUI_DEPS[@]}")
  echo "=> Running in GUI mode."
fi

# --- Utility Functions ---

# Function to check if a package is installed via pacman (either package or group)
is_pacman_installed() {
  pacman -Qq "$1" &>/dev/null || pacman -Qg "$1" &>/dev/null
}

# Function to detect the available AUR helper
get_aur_helper() {
  if command -v yay &>/dev/null; then
    echo "yay"
  elif command -v paru &>/dev/null; then
    echo "paru"
  else
    echo ""
  fi
}

# --- Script Logic ---
echo "--- Starting Idempotent Arch Linux Environment Setup ---"

# 1. Install System Dependencies (Idempotent)
echo "1. Checking and installing system dependencies (including build tools, vim, tk, etc.)..."

PACMAN_DEPS_NEEDED=()
for dep in "${PACMAN_DEPS[@]}"; do
  if ! is_pacman_installed "$dep"; then
    PACMAN_DEPS_NEEDED+=("$dep")
  fi
done

if [ ${#PACMAN_DEPS_NEEDED[@]} -ne 0 ]; then
  echo "   Installing missing official packages: ${PACMAN_DEPS_NEEDED[*]}"
  sudo pacman -S --needed --noconfirm "${PACMAN_DEPS_NEEDED[@]}"
else
  echo "   All required official Pacman packages are already installed."
fi

AUR_DEPS_NEEDED=()
for dep in "${AUR_DEPS[@]}"; do
  if ! is_pacman_installed "$dep"; then
    AUR_DEPS_NEEDED+=("$dep")
  fi
done

if [ ${#AUR_DEPS_NEEDED[@]} -ne 0 ]; then
  AUR_HELPER=$(get_aur_helper)
  if [ -z "$AUR_HELPER" ]; then
    echo "   AUR helper not found. Attempting to install 'paru'..."
    if sudo pacman -S --needed --noconfirm paru; then
      AUR_HELPER="paru"
      echo "   Successfully installed paru from repositories."
    else
      echo "   paru not found in repositories. Building paru-bin from AUR..."
      # Ensure git and base-devel are installed (should be, but as a safeguard)
      sudo pacman -S --needed --noconfirm git base-devel

      # Clone and compile/install paru-bin (must be run as normal user, not root)
      TEMP_DIR=$(mktemp -d)
      if git clone https://aur.archlinux.org/paru-bin.git "$TEMP_DIR" && \
         (cd "$TEMP_DIR" && makepkg -si --noconfirm); then
        AUR_HELPER="paru"
        echo "   Successfully built and installed paru-bin."
      else
        echo "ERROR: Failed to install paru. Cannot install AUR packages: ${AUR_DEPS_NEEDED[*]}"
      fi
      rm -rf "$TEMP_DIR"
    fi
  fi

  if [ -n "$AUR_HELPER" ]; then
    echo "   Installing missing AUR packages via $AUR_HELPER: ${AUR_DEPS_NEEDED[*]}"
    $AUR_HELPER -S --needed --noconfirm "${AUR_DEPS_NEEDED[@]}"
  else
    echo "WARNING: AUR helper not installed. Cannot install AUR packages: ${AUR_DEPS_NEEDED[*]}"
    echo "Please install these AUR packages manually: ${AUR_DEPS_NEEDED[*]}"
  fi
else
  echo "   All required AUR packages are already installed."
fi
echo ""

# 1b. Initialize, Start and Secure System Services (Idempotent)
echo "1b. Configuring, starting and securing system services (MariaDB, NGINX)..."
if is_pacman_installed "mariadb"; then
  # On Arch, we must check if the database directory is initialized before starting
  if [ ! -d "/var/lib/mysql/mysql" ]; then
    echo "   Initializing MariaDB data directory..."
    sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
  else
    echo "   MariaDB data directory is already initialized."
  fi

  echo "   Enabling and starting MariaDB service..."
  sudo systemctl enable --now mariadb

  # Wait for MariaDB to start (up to 10 seconds)
  echo "   Waiting for MariaDB to become ready..."
  for _ in {1..10}; do
    if sudo mariadb -e "SELECT 1" &>/dev/null; then
      break
    fi
    sleep 1
  done

  # Secure the installation (non-interactive equivalent to mariadb-secure-installation)
  echo "   Securing MariaDB installation (removing anonymous users and test db)..."
  sudo mariadb -e "DELETE FROM mysql.user WHERE User='';"
  sudo mariadb -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');"
  sudo mariadb -e "DROP DATABASE IF EXISTS test;"
  sudo mariadb -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
  sudo mariadb -e "FLUSH PRIVILEGES;"
fi

if is_pacman_installed "nginx"; then
  echo "   Enabling and starting NGINX service..."
  sudo systemctl enable --now nginx
fi
echo ""

# 2. Install Pyenv (Idempotent)
echo "2. Installing pyenv..."
if [ ! -d "$HOME/.pyenv" ]; then
  echo "   Pyenv not found. Running installation script..."
  curl -fsSL https://pyenv.run | bash
else
  echo "   Pyenv is already installed."
fi
echo ""

# 3. Configure Pyenv in ~/.bashrc (Assumes prior idempotent fix is in place)
# This step relies on the user ensuring ~/.bashrc is sourced.

# 3b. Setup Local Git Configuration (Idempotent)
echo "3b. Checking local Git configuration..."
if [ ! -f "$HOME/.gitconfig.local" ]; then
  echo "    ~/.gitconfig.local not found."
  if [ -t 0 ]; then
    echo "    Creating local Git identity (~/.gitconfig.local)..."
    read -r -p "    Enter your Git user name: " git_name
    read -r -p "    Enter your Git email address: " git_email

    cat << EOF > "$HOME/.gitconfig.local"
[user]
        name = $git_name
        email = $git_email
EOF
    echo "    ~/.gitconfig.local created successfully."
  else
    echo "    Non-interactive terminal detected. Skipping local Git configuration creation."
  fi
else
  echo "    ~/.gitconfig.local is already present."
fi
echo ""

# 4. Install Python Version (Idempotent)
# Ensure pyenv functions are loaded for this script
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT/bin" ]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
fi
# Re-source pyenv functions as we are in a sub-shell script
eval "$(pyenv init - bash)"
eval "$(pyenv virtualenv-init -)"

# Resolve Python version now that pyenv is guaranteed to be installed and loaded
PYTHON_VERSION=$(get_latest_python_version)
if [ -z "$PYTHON_VERSION" ]; then
  echo "WARNING: Could not determine latest Python version automatically. Falling back to a recent stable version (3.12.1)." >&2
  PYTHON_VERSION="3.12.1"
fi

echo "4. Installing Python $PYTHON_VERSION via pyenv..."

if pyenv versions --bare | grep -q "^${PYTHON_VERSION}$"; then
  echo "   Python $PYTHON_VERSION is already installed."
else
  # Get total memory in MB
  TOTAL_MEM=$(awk '/^MemTotal:/ {print int($2/1024)}' /proc/meminfo)

  if [ "$TOTAL_MEM" -lt 1900 ]; then
    echo "   Physical RAM is ${TOTAL_MEM}MB. Limiting compilation to 1 core and using local scratch temp directory to prevent lockups."
    export MAKE_OPTS="-j1"
    export MAKEFLAGS="-j1"
    LOCAL_SCRATCH="$HOME/pyenv_build_scratch"
    mkdir -p "$LOCAL_SCRATCH"
    export TMPDIR="$LOCAL_SCRATCH"
  else
    echo "   Physical RAM is ${TOTAL_MEM}MB. Proceeding with parallel build."
  fi

  echo "   Installing Python $PYTHON_VERSION (This may take a while)..."
  if pyenv install "$PYTHON_VERSION"; then
    echo "   Python $PYTHON_VERSION installed successfully."
  else
    echo "   Python installation failed. Check dependencies."
    [ -n "$LOCAL_SCRATCH" ] && [ -d "$LOCAL_SCRATCH" ] && rm -rf "$LOCAL_SCRATCH"
    exit 1
  fi

  # Clean up build scratch dir if we created one
  [ -n "$LOCAL_SCRATCH" ] && [ -d "$LOCAL_SCRATCH" ] && rm -rf "$LOCAL_SCRATCH"
fi
echo ""

# 5. Set Global Python Version (Idempotent)
echo "5. Setting Python $PYTHON_VERSION as the global default..."
CURRENT_GLOBAL=$(pyenv global)
if [ "$CURRENT_GLOBAL" = "$PYTHON_VERSION" ]; then
  echo "   Global version is already set to $PYTHON_VERSION."
else
  pyenv global "$PYTHON_VERSION"
  echo "   Global version set to $PYTHON_VERSION."
fi
echo ""

# 6. Install Python Development Tools (pylint, pytest, etc.)
echo "6. Installing Python development tools (pylint, pytest, pipenv, etc.)..."
# Use python -m pip to ensure the pyenv active environment's pip is used
python -m pip install --upgrade pip setuptools wheel pipenv pysocks pylint numpy pytest \
  Flask pymysql requests cryptography pytest-mock pytest-cov ipython black python-dotenv psutil paramiko
echo ""

# 7. Setup Vim Plugin Directory (Idempotent)
echo "7. Setting up Vim plugin directory..."
if [ ! -d "$VIM_PACK_DIR" ]; then
  mkdir -p "$VIM_PACK_DIR"
  echo "   Created Vim plugin directory structure: $VIM_PACK_DIR"
else
  echo "   Vim plugin directory already exists."
fi
echo ""

# 8. Install ALE Plugin (Idempotent)
echo "8. Installing/Updating ALE Plugin..."
if [ -d "$ALE_DIR" ]; then
  # Update if already a Git repository
  if [ -d "$ALE_DIR/.git" ]; then
    echo "   ALE plugin is already installed. Attempting 'git pull'..."
    (cd "$ALE_DIR" && git pull)
  else
    echo "   $ALE_DIR exists but is not a git repo. Skipping update."
  fi
else
  # Install if the directory is missing
  echo "   ALE plugin not found. Cloning repository..."
  git clone --depth 1 "$ALE_REPO" "$ALE_DIR"
  echo "   ALE installed successfully."
fi
echo ""

# 8b. Install Vim-Tmux-Navigator Plugin (Idempotent)
echo "8b. Installing/Updating Vim-Tmux-Navigator Plugin..."
if [ -d "$NAV_DIR" ]; then
  if [ -d "$NAV_DIR/.git" ]; then
    echo "   Vim-Tmux-Navigator is already installed. Attempting 'git pull'..."
    (cd "$NAV_DIR" && git pull)
  else
    echo "   $NAV_DIR exists but is not a git repo. Skipping update."
  fi
else
  echo "   Vim-Tmux-Navigator not found. Cloning repository..."
  git clone --depth 1 "$NAV_REPO" "$NAV_DIR"
  echo "   Vim-Tmux-Navigator installed successfully."
fi
echo ""

# 9. Install Antigravity CLI (Idempotent)
echo "9. Installing Antigravity CLI (agy)..."
if [ ! -f "$HOME/.local/bin/agy" ]; then
  echo "   Installing Antigravity CLI..."
  curl -fsSL https://antigravity.google/cli/install.sh | bash
else
  echo "   Antigravity CLI (agy) is already installed."
fi
echo ""

echo "--- Setup complete. ---"
