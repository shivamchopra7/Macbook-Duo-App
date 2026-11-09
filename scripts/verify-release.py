#!/usr/bin/env python3
"""Check that public download links, updater names and release assets agree."""
import argparse
import hashlib
import json
from pathlib import Path
import plistlib
import re
import os
import subprocess
import tempfile
import zipfile

REPOSITORY = "shivamchopra7/Macbook-Duo-App"
ARCHIVES = {"Foldbook-mac.zip": "arm64", "Foldbook-Intel.zip": "x86_64"}
DMGS = {"Foldbook.dmg", "Foldbook-Intel.dmg"}
CHECKSUMS = "Foldbook-SHA256SUMS.txt"
ASSETS = set(ARCHIVES) | DMGS | {CHECKSUMS}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def verify_links(root, available):
    prefix = f"https://github.com/{REPOSITORY}/releases/latest/download/"
    for relative in ("README.md", "docs/index.html"):
        names = re.findall(re.escape(prefix) + r'([^\s)"<>]+)', (root / relative).read_text())
        require(DMGS <= set(names), f"{relative}: both architecture download links are required")
        require(set(names) <= available, f"{relative}: download links have no matching release asset: {set(names) - available}")
    updater = (root / "Sources/FoldCore/Updates/ReleaseUpdate.swift").read_text()
    for name in set(ARCHIVES) | {CHECKSUMS}:
        require(f'"{name}"' in updater, f"Updater does not select {name}")


def verify_checksums(dist):
    entries = {}
    for line in (dist / CHECKSUMS).read_text().splitlines():
        fields = line.split()
        require(len(fields) == 2, "Malformed checksum entry")
        digest, name = fields[0], fields[1].removeprefix("*")
        require(name in set(ARCHIVES) | DMGS and name not in entries, f"Unexpected or duplicate checksum: {name}")
        require(re.fullmatch(r"[0-9a-fA-F]{64}", digest), f"Invalid SHA-256 for {name}")
        entries[name] = digest.lower()
    require(set(entries) == set(ARCHIVES) | DMGS, "Checksums must cover both DMGs and both ZIPs")
    for name, expected in entries.items():
        digest = hashlib.sha256((dist / name).read_bytes()).hexdigest()
        require(digest == expected, f"SHA-256 mismatch: {name}")


def verify_archive(path, version):
    with zipfile.ZipFile(path) as archive:
        names = archive.namelist()
        require(all(n == "INSTALL.txt" or n.startswith("Foldbook.app/") for n in names), f"{path.name}: unexpected archive root")
        require(archive.testzip() is None, f"{path.name}: corrupt ZIP")
        info = plistlib.loads(archive.read("Foldbook.app/Contents/Info.plist"))
        require(info.get("CFBundleShortVersionString") == version, f"{path.name}: app version does not match {version}")
        require(info.get("CFBundleIdentifier") == "com.shivamchopra.macbookduo", f"{path.name}: wrong bundle identifier")
        require(info.get("CFBundleName") == "Foldbook", f"{path.name}: wrong app name")
        return info["CFBundleVersion"]


def verify_local(root, dist, version):
    available = {p.name for p in dist.iterdir() if p.is_file() and p.stat().st_size > 0}
    require(ASSETS <= available, f"Missing release assets: {ASSETS - available}")
    verify_links(root, available)
    verify_checksums(dist)
    builds = {verify_archive(dist / name, version) for name in ARCHIVES}
    require(len(builds) == 1, "Architecture build numbers differ")


def verify_published(root, metadata, version, draft=False):
    tag = f"v{version}"
    require(metadata.get("tag_name") == tag, f"Expected release {tag}")
    require(metadata.get("draft") == draft and not metadata.get("prerelease"), "Release has the wrong publication state")
    download_tag = tag
    if draft:
        prefix = f"https://github.com/{REPOSITORY}/releases/tag/"
        page = metadata.get("html_url", "")
        require(page.startswith(prefix), "Unexpected draft release page")
        download_tag = page[len(prefix):]
        require(download_tag == tag or re.fullmatch(r"untagged-[0-9a-f]+", download_tag), "Unexpected draft download tag")
    assets = metadata.get("assets", [])
    names = [a["name"] for a in assets]
    require(len(names) == len(set(names)), "Duplicate published assets")
    require(ASSETS <= set(names), f"Published release is missing assets: {ASSETS - set(names)}")
    for asset in assets:
        if asset["name"] in ASSETS:
            require(asset.get("size", 0) > 0 and asset.get("state") == "uploaded", f"Incomplete asset: {asset['name']}")
            expected = f"https://github.com/{REPOSITORY}/releases/download/{download_tag}/{asset['name']}"
            require(asset.get("browser_download_url") == expected, f"Unexpected asset URL: {asset['name']}")
    verify_links(root, set(names))


def find_draft(releases, version):
    matches = [item for item in releases if item.get("tag_name") == f"v{version}" and item.get("draft")]
    require(len(matches) == 1, f"Expected exactly one uploaded draft for v{version}")
    return matches[0]


def verify_disk_image(path, archive_path):
    subprocess.run(["hdiutil", "verify", "-quiet", str(path)], check=True)
    with tempfile.TemporaryDirectory(prefix="foldbook-dmg-") as scratch:
        mount = Path(scratch).resolve() / "mounted"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-noautoopen", "-mountpoint", str(mount), str(path)],
                       check=True, stdout=subprocess.DEVNULL)
        try:
            app = mount / "Foldbook.app"
            require(app.is_dir(), f"{path.name}: Foldbook.app is missing")
            require((mount / "Applications").is_symlink() and os.readlink(mount / "Applications") == "/Applications",
                    f"{path.name}: Applications shortcut is missing")
            with zipfile.ZipFile(archive_path) as archive:
                expected = {n for n in archive.namelist() if n.startswith("Foldbook.app/") and not n.endswith("/")}
                actual = {str(p.relative_to(mount)) for p in app.rglob("*") if p.is_file()}
                require(actual == expected, f"{path.name}: app contents differ from the verified ZIP")
                for name in expected:
                    require(not (mount / name).is_symlink() and (mount / name).read_bytes() == archive.read(name),
                            f"{path.name}: {name} differs from the verified ZIP")
        finally:
            subprocess.run(["hdiutil", "detach", "-quiet", str(mount)], check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--dist", type=Path, default=Path("dist"))
    remote = parser.add_mutually_exclusive_group()
    remote.add_argument("--published", action="store_true", help="Verify latest metadata and download every live asset")
    remote.add_argument("--draft", action="store_true", help="Verify uploaded draft metadata and bytes before publishing")
    args = parser.parse_args()
    require(re.fullmatch(r"\d+\.\d+\.\d+", args.version), "Use a semantic version such as 1.0.2")
    root = Path(__file__).resolve().parent.parent
    verify_local(root, args.dist.resolve(), args.version)
    executable = root / "build/Foldbook.app/Contents/MacOS/MacbookDuo"
    require(executable.is_file(), "Build the native app first for package verification")
    with tempfile.TemporaryDirectory(prefix="foldbook-release-") as scratch:
        for name, architecture in ARCHIVES.items():
            subprocess.run([str(executable), "--update-package-check", str(args.dist.resolve() / name),
                            str(args.dist.resolve() / CHECKSUMS), args.version,
                            str(Path(scratch).resolve() / architecture)], check=True)
    for name in sorted(DMGS):
        archive = "Foldbook-Intel.zip" if name == "Foldbook-Intel.dmg" else "Foldbook-mac.zip"
        verify_disk_image(args.dist.resolve() / name, args.dist.resolve() / archive)
    if args.published or args.draft:
        if args.draft:
            # GitHub does not resolve the tag endpoint for a draft whose tag
            # will be created on publication. List authenticated releases instead.
            pages = json.loads(subprocess.check_output(["gh", "api", "--paginate", "--slurp", f"repos/{REPOSITORY}/releases?per_page=100"]))
            metadata = find_draft([item for page in pages for item in page], args.version)
        else:
            metadata = json.loads(subprocess.check_output(["gh", "api", f"repos/{REPOSITORY}/releases/latest"]))
        commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
        require(metadata.get("target_commitish") == commit, "Release does not target this exact source commit")
        verify_published(root, metadata, args.version, draft=args.draft)
        with tempfile.TemporaryDirectory(prefix="foldbook-downloads-") as scratch:
            downloaded = Path(scratch)
            if args.draft:
                command = ["gh", "release", "download", f"v{args.version}", "--repo", REPOSITORY, "--dir", scratch]
                for name in sorted(ASSETS):
                    command.extend(["--pattern", name])
                subprocess.run(command, check=True)
            else:
                for name in sorted(ASSETS):
                    url = f"https://github.com/{REPOSITORY}/releases/latest/download/{name}"
                    subprocess.run(["curl", "--fail", "--silent", "--show-error", "--location", "--retry", "3",
                                    "--output", str(downloaded / name), url], check=True)
            for name in ASSETS:
                actual = hashlib.sha256((downloaded / name).read_bytes()).digest()
                expected = hashlib.sha256((args.dist / name).read_bytes()).digest()
                require(actual == expected, f"Uploaded bytes do not match the verified local asset: {name}")
    print(f"Verified Foldbook {args.version}: both architectures, download names, app versions and SHA-256 checksums" + (", plus published download bytes." if args.published else ", plus uploaded draft bytes." if args.draft else "."))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Release verification failed: {error}")
