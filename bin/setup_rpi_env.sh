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

# Python Version is determined dynamically
PYTHON_VERSION=$(get_latest_python_version)

# Fallback check (if pyenv is installed but the list command failed for some reason)
if [ -z "$PYTHON_VERSION" ]; then
  echo "WARNING: Could not determine latest Python version automatically. Falling back to a recent stable version (3.12.1)." >&2
  PYTHON_VERSION="3.12.1"
fi

VIM_PACK_DIR="$HOME/.vim/pack/git-plugins/start"
ALE_DIR="$VIM_PACK_DIR/ale"
ALE_REPO="https://github.com/dense-analysis/ale.git"

# List of build dependencies and development tools
APT_DEPS=(
  git build-essential autoconf automake libtool zlib1g-dev libbz2-dev liblzma-dev libexpat1-dev libffi-dev \
  libssl-dev libncurses5-dev libncursesw5-dev libreadline-dev uuid-dev libdb-dev libgdbm-dev libsqlite3-dev \
  vim shellcheck tmux mosh tk tk-dev \
  fonts-noto-color-emoji slurp \
  jq yq
)

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

# 4. Install Python Version (Idempotent)
echo "4. Installing Python $PYTHON_VERSION via pyenv..."
# Ensure pyenv functions are loaded for this script
export PYENV_ROOT="$HOME/.pyenv"
if [ -d "$PYENV_ROOT/bin" ]; then
  export PATH="$PYENV_ROOT/bin:$PATH"
fi
# Re-source pyenv functions as we are in a sub-shell script
eval "$(pyenv init - bash)"
eval "$(pyenv virtualenv-init -)"

if pyenv versions | grep -q "$PYTHON_VERSION"; then
  echo "   Python $PYTHON_VERSION is already installed."
else
  echo "   Installing Python $PYTHON_VERSION (This may take a while)..."
  if pyenv install "$PYTHON_VERSION"; then
    echo "   Python $PYTHON_VERSION installed successfully."
  else
    echo "   Python installation failed. Check dependencies."
    exit 1
  fi
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
# The 'pip install' command itself is not strictly idempotent, but running it ensures all are present and updated.
pip install --upgrade pip setuptools wheel pipenv pysocks pylint numpy pytest
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
echo "--- Setup complete. ---"
