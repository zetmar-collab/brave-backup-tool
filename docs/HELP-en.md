# Brave Backup Tool — help (EN)

Version **2.1** | [Pomoc po polsku](POMOC-pl.md)

## What does it do?

Creates **local** backups of your **Brave** browser profile (bookmarks, passwords, history, extensions, sessions). Data is **never sent over the internet**.

## Quick start

1. Download `BraveBackup.exe` from [Releases](https://github.com/zetmar-collab/brave-backup-tool/releases/latest).
2. Run the file (no installer).
3. Complete the **first-run onboarding** (3 steps).
4. Click **Set backup folder** and choose a drive (e.g. external disk).
5. Close Brave — the app will prompt and close Brave processes.
6. Click **Create backup** (recommended: key data) or **Full backup**.

## Main buttons

| Button | Action |
|--------|--------|
| **Create backup** | Key data backup (smaller, for daily use) |
| **Key data** | Same — bookmarks, logins, cookies, history, extensions |
| **Full backup** | Almost full profile without cache (larger; before OS reinstall) |
| **Restore** | Restores the selected backup from the list |
| **Delete** | Deletes the selected backup (with confirmation and folder name) |
| **Refresh** | Refreshes the backup list |
| **Set backup folder** | Changes where backups are stored |

## Status bar

- **Brave** — whether the browser is running
- **Backup folder** — whether a folder is set and its path
- **Last backup** — date of the latest backup on the list
- **Backups: X/Y** — backup count and rotation limit

## Settings

Open **Settings** (top right):

- **Maximum backups** — choose **5, 10, 15, or 20** (oldest are removed automatically)
- **Language** — Polski (PL) or English (EN)
- **Check for updates** — opens GitHub Releases

The **EN / PL** toggle in the header switches language immediately.

## Restore

1. Select a backup from the list.
2. Click **Restore**.
3. Confirm you understand the profile will be overwritten.
4. Optional: **safety backup before restore** (recommended).
5. Choose mode:
   - **Overwrite files from backup only** — safer
   - **Clear profile and restore** — full restore

Start Brave manually when finished.

## Security

- Backups stay **on your disk only**.
- They contain **passwords and cookies** — do not share the folder.
- The app closes Brave to copy locked files.
- Open source (MIT) on GitHub.

## Console mode

```text
BraveBackup.exe -end -Console
```

Menu: full backup, key data, restore, delete, quit.

## Launch parameters

| Parameter | Description |
|-----------|-------------|
| `-Lang pl` | Polish UI |
| `-Lang en` | English UI |
| `-Console` | Text mode (requires `-end` in EXE) |

Example:

```text
BraveBackup.exe -end -Lang en
```

## Files and folders

| Item | Description |
|------|-------------|
| `backups\` | Default backup folder (next to the app) |
| `backup-settings.json` | Backup folder, language, rotation limit, onboarding |
| `YYYY-MM-DD_HH-mm-ss_wybrane` | Key data backup |
| `YYYY-MM-DD_HH-mm-ss_pelna` | Full backup |

## Troubleshooting

**Window not responding during backup** — normal for large profiles; wait for the log message.

**Brave won't close** — close all Brave windows manually and retry.

**Brave data not found** — ensure Brave was run at least once on this PC (`%LOCALAPPDATA%\BraveSoftware\...`).

**EXE startup error** — download the latest build from Releases.

## Source and repository

https://github.com/zetmar-collab/brave-backup-tool
