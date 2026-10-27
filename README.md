# syspulse

A Bash tool for automated Linux backups and system health checks.

> 🚧 **Work in progress.** Syspulse is currently under development. The features described below are planned and may not be available yet.

## ✨  Features (planned)

* Timestamped `.tar.gz` backups from a plain-text path list
* Keep only the last `N` backups
- [ ] Disk and RAM usage alerts (threshold: 85%)
- [ ] Structured logs: `[INFO]`, `[WARN]`, `[ERROR]`
* Meaningful exit codes
- [ ] Graceful cleanup with `trap`

## ⚙️ Configuration

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

### Planned settings

```bash
BACKUP_DIR="/path/to/backups"
SOURCE_FILE="/path/to/backup_paths.list"
LOG_FILE="/path/to/syspulse.log"

RETENTION_COUNT=5
DISK_THRESHOLD=85
RAM_THRESHOLD=85
```

The values above are examples of the intended configuration format. They are not yet guaranteed to be supported.

## 🚦 Exit Codes

The planned exit codes are:

| Code | Constant | Meaning |
| - | - | - |
| 0 | EXIT_SUCCESS | Execution completed successfully. |
| 1	| EXIT_SOURCE_ERROR | A configured source is invalid or missing. |
| 2	| EXIT_WRITE_ERROR | Archive creation or writing failed. |
| 3 | EXIT_HARDWARE_ERROR | Hardware limits reached |

Additional codes may be introduced as error handling becomes more detailed.

## 📦 Archive Format

```bash
syspulse-YYYY-MM-DD_HHMMSS.tar.gz
```

Each archive will have a timestamp identifying its creation time.

## 📊 Log Format

```bash
YYYY-MM-DD HH:mm:ss [LEVEL] Message
```

Example:
```bash
2026-10-16 08:00:00 [INFO] Backup started.
2026-10-16 08:00:01 [WARN] Disk usage exceeded threshold.
2026-10-16 08:00:02 [ERROR] Source path does not exist.
2026-10-16 08:00:03 [INFO] Backup completed successfully.
```

Planned severity levels: SUCCESS, INFO, WARN, ERROR.

## 🔒 Safety Principles

1. Validate all configured source paths before archiving.
1. Require absolute source paths and support spaces in filenames.
1. Abort the backup if any source is unavailable.
1. Verify temporary archives before promoting them to valid backups.
1. Apply retention only after a new archive has been verified.
1. Avoid unnecessary root privileges.

## 📌 Development Notes
The RAM usage calculation method and final resource thresholds are still to be defined. Automated execution through cron or systemd timers is planned for a future stage.

## 📝 License
MIT
