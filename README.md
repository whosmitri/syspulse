# syspulse

A Bash tool for Linux that creates compressed backups and monitors disk and RAM usage. Syspulse reads paths from a text file, logs execution events, and can schedule tasks using systemd user timers.

## ✨  Features

* Creates `.tar.gz` backup archives with timestamps in their filenames
* Reads backup source paths from a text file
* Validates paths before starting the backup
* Keep only the last `N` backups
* Disk and RAM usage alerts
* Provides a verbose mode using `-v` or `--verbose` flag
* Logs events to a file; warnings and errors are also displayed in the terminal
* Can configure systemd user timers for backups and health checks
* Secure cleanup with `trap` in the backup script

## Requirements
* Linux
* Standard utilities used by the scripts, including `tar`, `df`, `awk`, and `readlink`
* `systemd` with support for user units, if you want to schedule tasks through the installer

> **syspulse** is designed to run as a regular user, without requiring root privileges for normal operations

## Installation
Clone the repository and run the installer from the project directory:

```bash
git clone https://github.com/whosmitri/syspulse.git
cd syspulse
./install.sh
```

The installer prompts you to choose where backups should be stored, where the list of source paths is located, and where the log file should be written. It also lets you configure resource usage thresholds and optionally schedule health checks and backups using systemd user timers.

If you enable scheduled tasks, the installer may enable user linger to allow timers to continue running without an active interactive session.


## ⚙️ Configuration

The installer saves the configuration file at:

```text
~/.config/syspulse/syspulse.conf
```

By default, the source path list and log file are also stored in `~/.config/syspulse/`. You can choose different locations during installation.

| File | Purpose |
| - | - |
| `syspulse.conf` | Backup destination, source list, retention policy, and resource thresholds. |
| `backup_paths.list` | Absolute paths to include in backups, one per line. |
| `syspulse.log` | Timestamped execution logs. |

### Configuration Variables

| Variable	| Description |
| - | - |
| BACKUP_DIR | Directory where backups are stored. |
| SOURCE_FILE | Path to the list of backup sources. |
| LOG_FILE | Path to the log file. |
| RETENTION_COUNT | Number of valid backups to retain. |
| DISK_THRESHOLD | Disk usage warning threshold. |
| RAM_THRESHOLD | RAM usage warning threshold. |

### Settings at `syspulse.conf`

```bash
BACKUP_DIR="/path/to/backups"
SOURCE_FILE="/path/to/backup_paths.list"
LOG_FILE="/path/to/syspulse.log"

RETENTION_COUNT=5
DISK_THRESHOLD=85
RAM_THRESHOLD=85
```

> The values above are examples of the configuration format.

### Settings at `backup_paths.list.example`

Add existing absolute paths, one per line. Empty lines and lines starting with `#` are ignored.

```text
/home/user/Documents
/home/user/Projects
# /home/user/Downloads
```

## Usage

After installation, the following commands are available in the user's PATH:

```bash
syspulse-health
syspulse-backup
```

To also display informational messages in the terminal, use verbose mode:

```bash
syspulse-health --verbose
syspulse-backup --verbose
```

The backup command runs a health check before creating the archive. If a configured path does not exist or a resource usage threshold is reached, the operation is aborted.

Backup archives follow this naming format:

```text
syspulse-YYYY-MM-DD_HHMMSS.tar.gz
```

Each archive will have a timestamp identifying its creation time.

## ⏲ Scheduling
During installation, you can configure systemd user timers:

* **Health check:** Runs periodically using the project's health check timer.
* **Backup:** Can be scheduled daily, weekly, monthly, or using a custom calendar expression.

You can inspect the timers with:

```bash
systemctl --user list-timers
```

## 📊 Logs

By default, the log file is stored at:

```text
~/.config/syspulse/syspulse.log
```

Log entries include a timestamp, severity level, and message:

```text
YYYY-MM-DD HH:mm:ss [LEVEL] Message
```

The severity levels include `SUCCESS`, `INFO`, `WARN`, and `ERROR`. Informational and success messages are displayed in the terminal when verbose mode is enabled. Warnings and errors are always displayed, even when verbose mode is disabled.

Example:

```text
2026-10-16 08:00:00 [INFO] Backup started.
2026-10-16 08:00:01 [WARN] Disk usage exceeded threshold.
2026-10-16 08:00:02 [ERROR] Source path does not exist.
2026-10-16 08:00:03 [INFO] Backup completed successfully.
```

## 🚦 Exit Codes

The exit codes are:

| Code | Constant | Meaning |
| - | - | - |
| 0 | EXIT_SUCCESS | Execution completed successfully. |
| 1	| EXIT_SOURCE_ERROR | A configured source is invalid or missing. |
| 2	| EXIT_WRITE_ERROR | Archive creation or writing failed. |
| 3 | EXIT_HARDWARE_ERROR | Hardware limits reached |

> Additional codes may be introduced as error handling becomes more detailed.

## Uninstallation

From the project directory, run:

```bash
./uninstall.sh
```

The uninstaller asks for confirmation, disables known timers, and removes the installed files. It separately asks whether you want to delete the internal backup directory. **Entries added to shell configuration files and user linger settings are not automatically removed.**

## 🔒 Safety Principles

1. Validate all configured source paths before archiving.
1. Require absolute source paths and support spaces in filenames.
1. Abort the backup if any source is unavailable.
1. Verify temporary archives before promoting them to valid backups.
1. Apply retention only after a new archive has been verified.
1. Avoid unnecessary root privileges.

## 📌 Notes
* The disk usage check monitors the filesystem where **syspulse** is installed.
* The source path list must contain valid absolute paths.
* Keep additional copies of important data. A local backup alone does not protect against failure or loss of the device itself.

## 📝 License
Distributed under the MIT License. See the [LICENSE](./LICENSE) file
