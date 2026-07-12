import sys
import shutil
import subprocess
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

from bin.link_dotfiles import is_headless, link_dotfiles

def test_is_headless_cli_override():
    assert is_headless(["--headless"]) is True
    assert is_headless(["--no-gui"]) is True
    assert is_headless(["--gui"]) is False

@patch("shutil.which")
def test_is_headless_wm_available(mock_which):
    # If one of the window managers is found, it should return False
    mock_which.side_effect = lambda cmd: "/usr/bin/labwc" if cmd == "labwc" else None
    assert is_headless([]) is False

@patch("shutil.which")
@patch("subprocess.check_output")
def test_is_headless_systemd_graphical(mock_check_output, mock_which):
    # No window manager found, but default target is graphical
    mock_which.return_value = None
    mock_check_output.return_value = "graphical.target\n"
    assert is_headless([]) is False

@patch("shutil.which")
@patch("subprocess.check_output")
def test_is_headless_fallback(mock_check_output, mock_which):
    # No window manager, and systemd target is not graphical or command fails
    mock_which.return_value = None
    mock_check_output.side_effect = subprocess.SubprocessError("command not found")
    assert is_headless([]) is True

def test_link_dotfiles_success(tmp_path):
    # Setup source repo and files
    repo_dir = tmp_path / "repo"
    repo_dir.mkdir()
    
    source_file = repo_dir / "bashrc"
    source_file.write_text("dummy bashrc contents")

    # Setup target paths
    target_dir = tmp_path / "target"
    # target directory doesn't exist yet to test parent directory creation
    dest_file = target_dir / ".bashrc"

    files_to_link = {
        "bashrc": dest_file
    }

    # Call link_dotfiles
    link_dotfiles(repo_repo=repo_dir, files_to_link=files_to_link)

    # Verify
    assert dest_file.is_symlink()
    assert dest_file.read_text() == "dummy bashrc contents"

def test_link_dotfiles_source_missing(tmp_path):
    # Setup source repo without file
    repo_dir = tmp_path / "repo"
    repo_dir.mkdir()

    target_dir = tmp_path / "target"
    target_dir.mkdir()
    dest_file = target_dir / ".bashrc"

    files_to_link = {
        "bashrc": dest_file
    }

    # Call link_dotfiles
    link_dotfiles(repo_repo=repo_dir, files_to_link=files_to_link)

    # Verify that it didn't create the symlink
    assert not dest_file.exists()
    assert not dest_file.is_symlink()

def test_link_dotfiles_overwrite_existing(tmp_path):
    # Setup source repo and file
    repo_dir = tmp_path / "repo"
    repo_dir.mkdir()
    source_file = repo_dir / "bashrc"
    source_file.write_text("new contents")

    # Setup target path with an existing file
    target_dir = tmp_path / "target"
    target_dir.mkdir()
    dest_file = target_dir / ".bashrc"
    dest_file.write_text("old contents")

    files_to_link = {
        "bashrc": dest_file
    }

    # Call link_dotfiles
    link_dotfiles(repo_repo=repo_dir, files_to_link=files_to_link)

    # Verify it got overwritten
    assert dest_file.is_symlink()
    assert dest_file.read_text() == "new contents"
