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

# List of build dependencies and development tools (split into common and GUI components)
APT_COMMON_DEPS=(
  git build-essential autoconf automake libtool zlib1g-dev libbz2-dev liblzma-dev libexpat1-dev libffi-dev \
  libssl-dev libncurses5-dev libncursesw5-dev libreadline-dev uuid-dev libdb-dev libgdbm-dev libsqlite3-dev \
  vim shellcheck ncal tmux mosh tk tk-dev curl \
  jq yq \
  mariadb-server mariadb-client nginx uwsgi uwsgi-plugin-python3
)

APT_GUI_DEPS=(
  fonts-noto-color-emoji gir1.2-peas-1.0 grim slurp wl-clipboard
)

# --- Auto-detection of Headless / Desktop Environment ---
# Detect if the OS has a GUI environment installed or configured by default.
HEADLESS=true
if command -v labwc &>/dev/null || command -v wayfire &>/dev/null || command -v Xorg &>/dev/null; then
  HEADLESS=false
elif command -v systemctl &>/dev/null && [ "$(systemctl get-default)" = "graphical.target" ]; then
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
  APT_DEPS=("${APT_COMMON_DEPS[@]}")
  echo "=> Running in HEADLESS / NO-GUI mode. GUI packages will be skipped."
else
  APT_DEPS=("${APT_COMMON_DEPS[@]}" "${APT_GUI_DEPS[@]}")
  echo "=> Running in GUI mode."
fi

# --- Utility Functions ---

# Function to check if a package is installed via apt
is_apt_installed() {
  dpkg -s "$1" &>/dev/null
}

# --- Script Logic ---
echo "--- Starting Idempotent Raspberry Pi Environment Setup ---"

# 1. Install System Dependencies (Idempotent)
echo "1. Checking and installing system dependencies (including build tools, vim, tk, etc.)..."
DEPS_NEEDED=()
for dep in "${APT_DEPS[@]}"; do
  if ! is_apt_installed "$dep"; then
    DEPS_NEEDED+=("$dep")
  fi
done

if [ ${#DEPS_NEEDED[@]} -ne 0 ]; then
  echo "   Installing missing packages: ${DEPS_NEEDED[*]}"
  sudo apt update
  sudo apt install -y "${DEPS_NEEDED[@]}"
else
  echo "   All required APT packages are already installed."
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
    mkdir -p "$HOME/pyenv_build_scratch"
    export TMPDIR="$HOME/pyenv_build_scratch"
  else
    echo "   Physical RAM is ${TOTAL_MEM}MB. Proceeding with parallel build."
  fi

  echo "   Installing Python $PYTHON_VERSION (This may take a while)..."
  if pyenv install "$PYTHON_VERSION"; then
    echo "   Python $PYTHON_VERSION installed successfully."
  else
    echo "   Python installation failed. Check dependencies."
    [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"
    exit 1
  fi

  # Clean up build scratch dir if we created one
  [ -n "$TMPDIR" ] && [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"
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
