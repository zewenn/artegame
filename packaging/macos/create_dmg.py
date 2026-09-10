#!/usr/bin/env python3
"""
create_dmg.py - Packages a macOS .app bundle into a drag-to-Applications .dmg disk image.
"""

import argparse
import os
import shutil
import subprocess
import sys


def parse_args():
    parser = argparse.ArgumentParser(description="Create a drag-to-Applications macOS DMG disk image.")
    parser.add_argument("--app", required=True, help="Path to the .app bundle (e.g. zig-out/bin/artegame.app)")
    parser.add_argument("--out", required=True, help="Path to the output .dmg file")
    parser.add_argument("--volname", default="Artegame", help="Volume name of the mounted disk image")
    parser.add_argument("--staging", default=None, help="Custom staging directory (temporary)")
    return parser.parse_args()


def create_dmg(app_path: str, out_path: str, volname: str, staging_dir: str):
    if not os.path.exists(app_path):
        print(f"Error: Application bundle not found: {app_path}", file=sys.stderr)
        sys.exit(1)

    app_name = os.path.basename(app_path.rstrip("/\\"))
    if not app_name.endswith(".app"):
        print(f"Error: Expected .app bundle, got: {app_path}", file=sys.stderr)
        sys.exit(1)

    if staging_dir is None:
        staging_dir = os.path.join(os.path.dirname(out_path) or ".", ".dmg_staging")

    # Clean up previous staging directory if it exists
    if os.path.exists(staging_dir):
        shutil.rmtree(staging_dir, ignore_errors=True)
    os.makedirs(staging_dir, exist_ok=True)

    try:
        # Copy the .app bundle to staging
        dest_app = os.path.join(staging_dir, app_name)
        print(f"Staging {app_path} -> {dest_app}...")
        shutil.copytree(app_path, dest_app, dirs_exist_ok=True)

        # Create symlink to /Applications
        apps_link = os.path.join(staging_dir, "Applications")
        print("Creating /Applications symlink...")
        if os.path.islink(apps_link) or os.path.exists(apps_link):
            os.remove(apps_link)
        os.symlink("/Applications", apps_link)

        # Ensure executable permissions on main binary
        bin_path = os.path.join(dest_app, "Contents", "MacOS", "artegame")
        if os.path.exists(bin_path):
            os.chmod(bin_path, 0o755)

        # Ad-hoc sign the app bundle so resources match the Mach-O signature
        if shutil.which("codesign"):
            print(f"Signing app bundle with ad-hoc signature: {dest_app}...")
            subprocess.run(["codesign", "--force", "--deep", "--sign", "-", dest_app], check=True)
            subprocess.run(["codesign", "--verify", "--deep", "--strict", dest_app], check=True)

        # Ensure parent output directory exists
        out_dir = os.path.dirname(out_path)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)

        # Remove existing destination DMG if present
        if os.path.exists(out_path):
            os.remove(out_path)

        # Build disk image with hdiutil
        print(f"Building DMG disk image: {out_path}...")
        cmd = [
            "hdiutil", "create",
            "-volname", volname,
            "-srcfolder", staging_dir,
            "-ov",
            "-format", "UDZO",
            out_path,
        ]
        subprocess.run(cmd, check=True)

        # Also ad-hoc sign the DMG image
        if shutil.which("codesign"):
            print(f"Signing DMG image: {out_path}...")
            subprocess.run(["codesign", "--force", "--sign", "-", out_path], check=True)

        print(f"Successfully created and signed DMG: {out_path}")

    finally:
        # Clean up staging directory
        if os.path.exists(staging_dir):
            shutil.rmtree(staging_dir, ignore_errors=True)


def main():
    args = parse_args()
    create_dmg(
        app_path=os.path.abspath(args.app),
        out_path=os.path.abspath(args.out),
        volname=args.volname,
        staging_dir=os.path.abspath(args.staging) if args.staging else None,
    )


if __name__ == "__main__":
    main()
