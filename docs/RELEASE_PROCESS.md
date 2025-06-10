# Release Process

This document describes the release process for Claude Code Usage MenuBar.

## Quick Release

For most releases, simply run:

```bash
./scripts/release.sh
```

This will:
1. Bump the patch version (e.g., 1.0.0 → 1.0.1)
2. Build the app
3. Create a git tag
4. Push to GitHub
5. Create a GitHub release with the built app

## Release Types

### Patch Release (Bug Fixes)
```bash
./scripts/release.sh patch
# or just
./scripts/release.sh
```

### Minor Release (New Features)
```bash
./scripts/release.sh minor
```

### Major Release (Breaking Changes)
```bash
./scripts/release.sh major
```

### Specific Version
```bash
./scripts/release.sh 2.0.0
```

## Release Options

### Create Draft Release
```bash
./scripts/release.sh --draft
```
Review and publish manually on GitHub.

### Skip Building
```bash
./scripts/release.sh --no-build
```
Use when you've already built the app.

### Skip GitHub Release
```bash
./scripts/release.sh --no-github
```
Only create tag without GitHub release.

## Step-by-Step Process

### 1. Pre-release Checklist
- [ ] All tests passing
- [ ] Code reviewed and merged to main
- [ ] CHANGELOG.md updated with changes
- [ ] Documentation updated if needed

### 2. Run Release Script
```bash
# Standard release
./scripts/release.sh minor

# Draft release for review
./scripts/release.sh minor --draft
```

### 3. Post-release
- [ ] Verify GitHub release page
- [ ] Download and test the released app
- [ ] Announce release if significant

## Manual Release Process

If you need to release manually:

### 1. Update Version
```bash
echo "1.2.0" > VERSION
```

### 2. Build App
```bash
./scripts/build.sh
```

### 3. Create Archive
```bash
cd build
zip -r "Claude Code Usage-v1.2.0.zip" "Claude Code Usage.app"
cd ..
```

### 4. Commit and Tag
```bash
git add VERSION
git commit -m "chore: bump version to 1.2.0"
git tag -a v1.2.0 -m "Release v1.2.0"
git push origin main
git push origin v1.2.0
```

### 5. Create GitHub Release
```bash
gh release create v1.2.0 \
  --title "Release v1.2.0" \
  --notes "Release notes here" \
  "build/Claude Code Usage-v1.2.0.zip"
```

## Version Numbering

We follow [Semantic Versioning](https://semver.org/):

- **Major** (X.0.0): Breaking changes
  - Removing features
  - Major UI redesigns
  - Incompatible API changes

- **Minor** (1.X.0): New features
  - Adding new functionality
  - Minor UI improvements
  - Performance enhancements

- **Patch** (1.0.X): Bug fixes
  - Fixing bugs
  - Small tweaks
  - Documentation updates

## Troubleshooting

### Build Fails
```bash
# Clean and rebuild
rm -rf .build build
./scripts/build.sh
```

### GitHub CLI Not Installed
```bash
# Install with Homebrew
brew install gh

# Authenticate
gh auth login
```

### Wrong Version in Release
Make sure VERSION file is updated before running release script.

### Can't Push Tags
Ensure you have push access to the repository and are on the main branch.

## GitHub Release Notes

The release script automatically generates release notes from git commits. To ensure good release notes:

1. Use conventional commit messages:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `chore:` for maintenance

2. Keep commit messages clear and concise

3. The script excludes version bump commits automatically

## Future Improvements

- [ ] Automated testing before release
- [ ] Notarization support (when needed)
- [ ] Homebrew formula updates
- [ ] Auto-update functionality