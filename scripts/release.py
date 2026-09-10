"""Version validation and cross-platform release packaging (Python stdlib only)."""
import argparse
import base64
import hashlib
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VERSION_RE = re.compile(r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:alpha|beta|rc)\.[1-9]\d*))?")


def metadata(root=ROOT, ref=None):
    text = (root / "app/pubspec.yaml").read_text(encoding="utf-8")
    match = re.search(r"^version: ([^\s]+)$", text, re.MULTILINE)
    if not match or "+" not in match[1]:
        raise ValueError("app/pubspec.yaml must declare version: X.Y.Z+BUILD")
    version, build = match[1].split("+", 1)
    if not VERSION_RE.fullmatch(version) or not build.isdigit() or not 0 < int(build) < 2100000000:
        raise ValueError("Invalid release version or Android build number")
    core = (root / "packages/eams_core/pubspec.yaml").read_text(encoding="utf-8")
    if not re.search(rf"^version: {re.escape(version)}$", core, re.MULTILINE):
        raise ValueError("GUI and core package versions must match")
    ref = os.environ.get("GITHUB_REF", "") if ref is None else ref
    if ref.startswith("refs/tags/") and ref != f"refs/tags/v{version}":
        raise ValueError("Tag must exactly match the version in app/pubspec.yaml")
    return {"version": version, "build_number": build, "prerelease": str("-" in version).lower()}


def require_file(path):
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"Missing or empty release input: {path.name}")
    return path


def package(target):
    version = metadata()["version"]
    dist = ROOT / "dist"
    dist.mkdir(exist_ok=True)
    os_name = os.environ.get("RUNNER_OS", {"nt": "Windows"}.get(os.name, "Linux")).lower()
    arch = os.environ.get("RUNNER_ARCH", "X64").lower()
    if arch not in {"x64", "arm64"}:
        raise ValueError("Unsupported release architecture")
    if target == "android":
        for abi in ("armeabi-v7a", "arm64-v8a", "x86_64"):
            source = require_file(ROOT / f"app/build/app/outputs/flutter-apk/app-{abi}-release.apk")
            shutil.copy2(source, dist / f"ecnu-eams-{version}-android-{abi}.apk")
        source = require_file(ROOT / "app/build/app/outputs/bundle/release/app-release.aab")
        shutil.copy2(source, dist / f"ecnu-eams-{version}-android.aab")
        return
    name = f"ecnu-eams-{version}-{target}"
    if target == "cli":
        name += f"-{os_name}-{arch}"
    elif target != "web":
        name += f"-{arch}"
    # Only this temporary staging tree is removed; build caches remain reusable.
    with tempfile.TemporaryDirectory(prefix="eams-package-") as temporary:
        stage = Path(temporary) / name
        stage.mkdir()
        if target == "windows":
            source = ROOT / "app/build/windows/x64/runner/Release"
            require_file(source / "ecnu_eams_client.exe")
            require_file(source / "flutter_windows.dll")
            shutil.copytree(source, stage, dirs_exist_ok=True, ignore=shutil.ignore_patterns("*.pdb", "*.exp", "*.lib"))
        elif target == "linux":
            source = ROOT / f"app/build/linux/{arch}/release/bundle"
            require_file(source / "ecnu_eams_client")
            shutil.copytree(source, stage, dirs_exist_ok=True, symlinks=True)
        elif target == "macos":
            source = ROOT / "app/build/macos/Build/Products/Release/ecnu_eams_client.app"
            require_file(source / "Contents/MacOS/ecnu_eams_client")
            subprocess.run(["ditto", str(source), str(stage / source.name)], check=True)
        elif target == "web":
            source = ROOT / "app/build/web"
            require_file(source / "index.html")
            require_file(source / "main.dart.js")
            shutil.copytree(source, stage, dirs_exist_ok=True)
        elif target == "cli":
            filename = "eams.exe" if os_name == "windows" else "eams"
            shutil.copy2(require_file(ROOT / "packages/eams_core/build" / filename), stage / filename)
        else:
            raise ValueError("Unknown packaging target")
        shutil.copy2(ROOT / "LICENSE", stage / "LICENSE")
        shutil.copy2(ROOT / "README.md", stage / "README.md")
        shutil.copytree(ROOT / "docs", stage / "docs")
        if target == "macos":
            subprocess.run(["ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", str(stage), str(dist / f"{name}.zip")], check=True)
        elif target == "linux" or (target == "cli" and os_name != "windows"):
            with tarfile.open(dist / f"{name}.tar.gz", "w:gz") as archive:
                archive.add(stage, arcname=name)
        else:
            shutil.make_archive(str(dist / name), "zip", stage.parent, stage.name)


def checksums(directory, version):
    expected = [
        (f"ecnu-eams-{version}-android-*.apk", 3),
        (f"ecnu-eams-{version}-android.aab", 1),
        (f"ecnu-eams-{version}-windows-*.zip", 1),
        (f"ecnu-eams-{version}-linux-*.tar.gz", 1),
        (f"ecnu-eams-{version}-macos-*.zip", 1),
        (f"ecnu-eams-{version}-web.zip", 1),
        (f"ecnu-eams-{version}-cli-windows-*.zip", 1),
        (f"ecnu-eams-{version}-cli-linux-*.tar.gz", 1),
        (f"ecnu-eams-{version}-cli-macos-*.tar.gz", 1),
    ]
    assets = []
    for pattern, count in expected:
        found = list(directory.glob(pattern))
        if len(found) != count:
            raise ValueError(f"Expected {count} assets matching {pattern}, got {len(found)}")
        assets.extend(found)
    if set(directory.iterdir()) - set(assets) - {directory / "SHA256SUMS"}:
        raise ValueError("Unexpected release files; refusing to publish")
    lines = []
    for path in sorted(assets):
        require_file(path)
        with path.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        lines.append(f"{digest}  {path.name}\n")
    (directory / "SHA256SUMS").write_text("".join(lines), encoding="utf-8")


def signing():
    keys = ("ANDROID_KEYSTORE_BASE64", "ANDROID_KEYSTORE_PATH", "ANDROID_KEY_ALIAS", "ANDROID_STORE_PASSWORD", "ANDROID_KEY_PASSWORD")
    missing = [key for key in keys if not os.environ.get(key)]
    if missing:
        raise ValueError("Missing signing configuration: " + ", ".join(missing))
    data = base64.b64decode(os.environ[keys[0]], validate=True)
    if not data:
        raise ValueError("Signing keystore is empty")
    path = Path(os.environ["ANDROID_KEYSTORE_PATH"])
    with path.open("wb") as stream:
        os.chmod(path, 0o600)
        stream.write(data)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["metadata", "package", "checksums", "signing", "clean-signing"])
    parser.add_argument("target", nargs="?")
    args = parser.parse_args()
    if args.command == "metadata":
        values = metadata()
        output = "".join(f"{key}={value}\n" for key, value in values.items())
        print(output, end="")
        if os.environ.get("GITHUB_OUTPUT"):
            with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as stream:
                stream.write(output)
    elif args.command == "package":
        package(args.target)
    elif args.command == "checksums":
        checksums(ROOT / "dist", metadata()["version"])
    elif args.command == "signing":
        signing()
    else:
        Path(os.environ["ANDROID_KEYSTORE_PATH"]).unlink(missing_ok=True)


if __name__ == "__main__":
    main()
