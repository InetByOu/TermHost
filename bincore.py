#!/usr/bin/env python3

"""
bincore.py - TermHost Binary Core Manager

Fungsi:
- Upload binary ke GitHub Releases
- Update binary di release
- Helper untuk maintain binary static

Cara pakai:
    python3 bincore.py upload ngrok arm64 /path/to/ngrok
    python3 bincore.py upload cloudflared arm64 /path/to/cloudflared
"""

import os
import sys
import subprocess

GITHUB_REPO = "InetByOu/TermHost"
RELEASE_TAG = "binaries-v1.0"


def upload_to_release(filename, filepath):
    print(f"Uploading {filename} to release {RELEASE_TAG}...")
    cmd = [
        "gh", "release", "upload", RELEASE_TAG,
        filepath,
        "--repo", GITHUB_REPO,
        "--clobber"
    ]
    try:
        subprocess.run(cmd, check=True)
        print(f"[OK] {filename} uploaded successfully.")
    except subprocess.CalledProcessError:
        print("[ERROR] Upload failed. Make sure 'gh' CLI is installed and authenticated.")


def main():
    if len(sys.argv) < 4:
        print("Usage: python3 bincore.py upload <name> <arch> <filepath>")
        print("Example: python3 bincore.py upload ngrok arm64 /path/to/ngrok")
        sys.exit(1)

    action = sys.argv[1]
    name = sys.argv[2]
    arch = sys.argv[3]
    filepath = sys.argv[4]

    if action == "upload":
        filename = f"{name}-{arch}"
        upload_to_release(filename, filepath)
    else:
        print("Unknown action. Use 'upload'")

if __name__ == "__main__":
    main()