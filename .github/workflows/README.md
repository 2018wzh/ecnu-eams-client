# GitHub Actions Workflow for ECNU EAMS Client

This workflow automatically builds the Flutter application for multiple platforms when a version tag is pushed or when manually triggered.

## Supported Platforms

- **Android**: APK and AAB formats
- **Windows**: MSIX package
- **Linux**: AppImage format
- **macOS**: macOS app bundle
- **Web**: Static web files

## Triggering Builds

### Automatic (Tag Push)
```bash
git tag v1.0.0
git push origin v1.0.0
```

### Manual (Workflow Dispatch)
1. Go to GitHub Actions tab
2. Select "Build and Release" workflow
3. Click "Run workflow"
4. Optionally specify a version

## Output Artifacts

After successful build, the following artifacts are available:
- `android-apk`: Android APK files
- `android-aab`: Android App Bundle
- `windows-build`: Windows MSIX package
- `linux-build`: Linux application bundle
- `macos-build`: macOS application bundle
- `web-build`: Web static files

For tagged releases, these artifacts are automatically uploaded to GitHub Releases.

## Local Development

See the main README.md for local build instructions.