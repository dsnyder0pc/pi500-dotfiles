#!/usr/bin/env python
"""
Symlink dot files to a clone of this repo. The location is defined
in the "Configuration" section below.
"""
import os
import sys
import shutil
import subprocess
from pathlib import Path

# --- Configuration ---
DOTFILES_REPO = Path.home() / "src" / "pi500-dotfiles"

def is_headless():
    # Support manual override flags
    if "--headless" in sys.argv or "--no-gui" in sys.argv:
        return True
    if "--gui" in sys.argv:
        return False

    # Check if a graphical window manager or server is installed/available
    for cmd in ["labwc", "wayfire", "Xorg"]:
        if shutil.which(cmd) is not None:
            return False

    # Auto-detect default target
    try:
        target = subprocess.check_output(["systemctl", "get-default"], stderr=subprocess.DEVNULL, text=True).strip()
        if target == "graphical.target":
            return False
    except Exception:
        pass

    return True

# Dictionary mapping: {Repo_Path_Fragment: Destination_Path}
FILES_TO_LINK = {
    "bashrc": Path.home() / ".bashrc",
    "bash_aliases": Path.home() / ".bash_aliases",
    "gemini/antigravity-cli/settings.json": Path.home() / ".gemini" / "antigravity-cli" / "settings.json",
    "gitconfig": Path.home() / ".gitconfig",
    "pylintrc": Path.home() / ".pylintrc",
    "tmux.conf": Path.home() / ".tmux.conf",
    "vilerc": Path.home() / ".vilerc",
    "vimrc": Path.home() / ".vimrc",
}

if is_headless():
    print("=> Headless mode detected/specified. Skipping window manager configs.")
else:
    FILES_TO_LINK["config/labwc/rc.xml"] = Path.home() / ".config" / "labwc" / "rc.xml"


# --- Script Logic ---
def link_dotfiles():
    """Removes existing files/links and creates new symbolic links from the repository."""
    print("Starting dotfiles symlink process (Python)...")
    print(f"Source Repository: {DOTFILES_REPO}")
    print("-----------------------------------")

    for source_fragment, dest_path in FILES_TO_LINK.items():
        source_path = DOTFILES_REPO / source_fragment

        print(f"Processing {source_fragment} -> {dest_path}... ", end="")

        # 1. Check if the source file exists in the repository
        if not source_path.is_file():
            print(f"FAIL (Source not found: {source_path})")
            continue

        # 2. Ensure the destination directory exists
        dest_dir = dest_path.parent
        if not dest_dir.is_dir():
            try:
                # Create parent directories if they don't exist
                dest_dir.mkdir(parents=True, exist_ok=True)
                print("Directory created, ", end="")
            except OSError as e:
                print(f"FAIL (Could not create directory: {dest_dir} - {e})")
                continue

        # 3. Remove existing file/link if it exists
        # Check if the destination exists and is not a non-symlinked directory (like ~/.config)
        if dest_path.exists() or dest_path.is_symlink():
            if dest_path.is_dir() and not dest_path.is_symlink():
                # Skip removal if it's an actual directory (like ~/.config), but continue if it's a symlink to a directory
                pass
            else:
                try:
                    os.remove(dest_path)
                    print("Existing removed, ", end="")
                except OSError as e:
                    print(f"FAIL (Could not remove existing file: {e})")
                    continue

        # 4. Create the symbolic link
        try:
            # Create a symbolic link: os.symlink(source, destination)
            os.symlink(source_path, dest_path)
            print("DONE (Symlinked)")
        except OSError as e:
            print(f"FAIL (Link creation failed: {e})")

    print("-----------------------------------")
    print("Symlinking complete. Please run 'source ~/.bashrc' or open a new terminal.")

if __name__ == "__main__":
    link_dotfiles()
