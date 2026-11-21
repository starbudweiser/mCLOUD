# mCLOUD

Your cloud accounts as drives in the Finder, without macFUSE.

## About

mCLOUD is made by Starbudweiser & Claude Code (Anthropic). Part of the **DESKTOP MAC TOOLKIT**. MIT License, © 2026 Starbudweiser. Provided as is, without warranty. "About mCLOUD" is in the app menu.

**mCLOUD** is a macOS app that mounts your cloud accounts (Google Drive, Dropbox, OneDrive, iCloud Drive, Box, pCloud, Infomaniak kDrive, MEGA, S3, Backblaze B2, Wasabi, SFTP, FTP, Nextcloud, WebDAV) as drives in the Finder. No kernel extension and no macFUSE: it runs a local WebDAV server powered by [rclone](https://rclone.org) (MIT) and mounts it with macOS.

- Client-side encryption, mount at startup, low local storage by default (offline cache is optional per account).
- A silent internal watch follows rclone releases and each account's health, and reports any change at a service that calls for a code fix.
- Automatic reconnection after sleep, network loss or failure.
- Imports the account list from CloudMounter (tokens are not read: each account is re-authorized).
- Available in French, English, Spanish and Italian.

Independent project, not affiliated with the cloud services mentioned.

![The main window listing four example cloud accounts (Google Drive, Amazon S3, Nextcloud, SFTP) ready to mount.](docs/screenshot.png)

## Requirements and installation

- macOS 14 or later, Apple Silicon or Intel (universal binary).
- Download `mCLOUD-<version>-macOS.zip` from the [Releases](https://github.com/starbudweiser/mCLOUD/releases) page, unzip it and move `mCLOUD.app` to Applications. The app is signed and notarized, and updates itself from GitHub releases (daily check, optional automatic install).

## Build

```bash
tools/update_rclone.sh      # fetches the rclone engine (not stored in git)
DEV=1 ./build_app.sh        # development build "mCLOUD Dev.app"
./build_app.sh              # local build, installed in ~/Applications/Applications Personnelles
./release.sh                # notarize and publish a GitHub release
```

MIT license.

## Support / Soutenir

This app is free. If it is useful to you, you can support the project (optional, no reward expected): [GitHub Sponsors](https://github.com/sponsors/starbudweiser).

Cette appli est gratuite. Si elle vous est utile, vous pouvez soutenir le projet (facultatif, sans contrepartie) : [GitHub Sponsors](https://github.com/sponsors/starbudweiser).
