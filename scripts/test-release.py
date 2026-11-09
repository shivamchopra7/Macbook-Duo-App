#!/usr/bin/env python3
"""Regression tests for the release/download-name contract (no network or builds)."""
import hashlib
import importlib.util
from pathlib import Path
import plistlib
import tempfile
import sys
import unittest
import zipfile

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location("verify_release", Path(__file__).with_name("verify-release.py"))
release = importlib.util.module_from_spec(spec)
spec.loader.exec_module(release)


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.dist = self.root / "dist"
        self.dist.mkdir()
        (self.root / "docs").mkdir()
        (self.root / "Sources/FoldCore/Updates").mkdir(parents=True)
        links = "\n".join(f"https://github.com/{release.REPOSITORY}/releases/latest/download/{n}" for n in sorted(release.DMGS))
        for name in ("README.md", "docs/index.html"):
            (self.root / name).write_text(links)
        (self.root / "Sources/FoldCore/Updates/ReleaseUpdate.swift").write_text(" ".join(f'"{n}"' for n in set(release.ARCHIVES) | {release.CHECKSUMS}))
        self.write_archives()
        for name in release.DMGS:
            (self.dist / name).write_bytes(b"fixture disk image")
        self.write_checksums()

    def write_archives(self, version="1.0.2"):
        info = {"CFBundleShortVersionString": version, "CFBundleVersion": "105", "CFBundleIdentifier": "com.shivamchopra.macbookduo", "CFBundleName": "Foldbook"}
        for name in release.ARCHIVES:
            with zipfile.ZipFile(self.dist / name, "w") as archive:
                archive.writestr("Foldbook.app/Contents/Info.plist", plistlib.dumps(info))
                archive.writestr("INSTALL.txt", "fixture")

    def write_checksums(self):
        lines = [f"{hashlib.sha256((self.dist / n).read_bytes()).hexdigest()}  {n}" for n in sorted(set(release.ARCHIVES) | release.DMGS)]
        (self.dist / release.CHECKSUMS).write_text("\n".join(lines) + "\n")

    def metadata(self):
        return {"tag_name": "v1.0.2", "html_url": f"https://github.com/{release.REPOSITORY}/releases/tag/v1.0.2", "draft": False, "prerelease": False, "assets": [
            {"name": n, "size": 123, "state": "uploaded", "browser_download_url": f"https://github.com/{release.REPOSITORY}/releases/download/v1.0.2/{n}"}
            for n in sorted(release.ASSETS)]}

    def test_matching_local_assets_pass(self):
        release.verify_local(self.root, self.dist, "1.0.2")

    def test_old_asset_names_reproduce_issue_2(self):
        for path in self.dist.iterdir():
            path.rename(path.with_name(path.name.replace("Foldbook", "Macbook-Duo")))
        with self.assertRaisesRegex(ValueError, "Missing release assets"):
            release.verify_local(self.root, self.dist, "1.0.2")

    def test_missing_intel_download_fails(self):
        (self.dist / "Foldbook-Intel.dmg").unlink()
        with self.assertRaisesRegex(ValueError, "Missing release assets"):
            release.verify_local(self.root, self.dist, "1.0.2")

    def test_wrong_website_link_fails(self):
        with (self.root / "docs/index.html").open("a") as file:
            file.write(f"\nhttps://github.com/{release.REPOSITORY}/releases/latest/download/Wrong.dmg")
        with self.assertRaisesRegex(ValueError, "no matching release asset"):
            release.verify_local(self.root, self.dist, "1.0.2")

    def test_stale_app_version_fails(self):
        self.write_archives("1.0.1")
        self.write_checksums()
        with self.assertRaisesRegex(ValueError, "version does not match"):
            release.verify_local(self.root, self.dist, "1.0.2")

    def test_corrupt_archive_or_dmg_fails(self):
        for name in ("Foldbook-mac.zip", "Foldbook-Intel.dmg"):
            with self.subTest(name=name):
                original = (self.dist / name).read_bytes()
                (self.dist / name).write_bytes(b"tampered")
                with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
                    release.verify_local(self.root, self.dist, "1.0.2")
                (self.dist / name).write_bytes(original)

    def test_matching_published_assets_pass(self):
        release.verify_published(self.root, self.metadata(), "1.0.2")

    def test_verified_draft_must_still_be_private(self):
        metadata = self.metadata()
        metadata["draft"] = True
        release.verify_published(self.root, metadata, "1.0.2", draft=True)
        with self.assertRaisesRegex(ValueError, "wrong publication state"):
            release.verify_published(self.root, metadata, "1.0.2")

    def test_temporary_draft_urls_are_valid_only_before_publication(self):
        metadata = self.metadata()
        metadata["draft"] = True
        metadata["html_url"] = metadata["html_url"].replace("v1.0.2", "untagged-2bb77fa61652b886e3de")
        for asset in metadata["assets"]:
            asset["browser_download_url"] = asset["browser_download_url"].replace("v1.0.2", "untagged-2bb77fa61652b886e3de")
        release.verify_published(self.root, metadata, "1.0.2", draft=True)
        metadata["draft"] = False
        with self.assertRaisesRegex(ValueError, "Unexpected asset URL"):
            release.verify_published(self.root, metadata, "1.0.2")

    def test_draft_lookup_does_not_require_a_published_tag(self):
        metadata = self.metadata()
        metadata["draft"] = True
        self.assertIs(release.find_draft([self.metadata(), metadata], "1.0.2"), metadata)
        with self.assertRaisesRegex(ValueError, "exactly one"):
            release.find_draft([self.metadata()], "1.0.2")
        with self.assertRaisesRegex(ValueError, "exactly one"):
            release.find_draft([metadata, metadata], "1.0.2")

    def test_published_legacy_names_fail(self):
        metadata = self.metadata()
        for asset in metadata["assets"]:
            asset["name"] = asset["name"].replace("Foldbook", "Macbook-Duo")
        with self.assertRaisesRegex(ValueError, "missing assets"):
            release.verify_published(self.root, metadata, "1.0.2")

    def test_stale_latest_release_fails(self):
        metadata = self.metadata()
        metadata["tag_name"] = "v1.0.1"
        with self.assertRaisesRegex(ValueError, "Expected release"):
            release.verify_published(self.root, metadata, "1.0.2")

    def test_unpublished_asset_fails(self):
        metadata = self.metadata()
        metadata["assets"][0]["state"] = "new"
        with self.assertRaisesRegex(ValueError, "Incomplete asset"):
            release.verify_published(self.root, metadata, "1.0.2")


if __name__ == "__main__":
    unittest.main()
