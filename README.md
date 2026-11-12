## About

**mCLOUD** is a macOS app that mounts your cloud accounts (Google Drive, Dropbox, OneDrive, iCloud Drive, Box, pCloud, MEGA, S3, Backblaze B2, Wasabi, SFTP, FTP, Nextcloud, WebDAV) as drives in the Finder. No kernel extension and no macFUSE: it runs a local WebDAV server powered by [rclone](https://rclone.org) (MIT) and mounts it with macOS.

- Client-side encryption, mount at startup, low local storage by default (offline cache is optional per account).
- A silent internal watch follows rclone releases and each account's health, and reports any change at a service that calls for a code fix.
- Automatic reconnection after sleep, network loss or failure.
- Imports the account list from CloudMounter (tokens are not read: each account is re-authorized).
- Available in French, English, Spanish and Italian.

Independent project, not affiliated with the cloud services mentioned.

## Build

```bash
tools/update_rclone.sh      # fetches the rclone engine (not stored in git)
DEV=1 ./build_app.sh        # development build "mCLOUD Dev.app"
./build_app.sh              # local build, installed in ~/Applications/Applications Personnelles
./release.sh                # notarize and publish a GitHub release
```

MIT license.
