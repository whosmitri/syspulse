# syspulse | Development Guide

This document describes **syspulse**'s internal behavior, implementation principles, and technical considerations for developers and contributors.

For installation and usage instructions, see README.md.

## ✨  Project Overview

**syspulse** is a Linux backup and system monitoring tool written in Bash.

Its main responsibilities are:

* Reading and validating backup source paths.
* Monitoring disk and RAM usage.
* Creating compressed backup archives using tar.
* Managing backup retention.
* Recording execution events.
* Scheduling automated tasks through systemd user timers.
* The project is designed to operate with regular user privileges, avoiding unnecessary root access.

## 📦 Requirements

* Linux
* `tar`
* `df`
* `awk`
* `readlink`
* systemd with user unit support (for scheduled tasks).

> **syspulse** is designed to run as a regular user, without requiring root privileges for normal operations

## ⚙️ Configuration

The installer saves the configuration file at:

```text
~/.config/syspulse/syspulse.conf
```

### 🌿 Configuration Variables

| Variable	| Description |
| - | - |
| BACKUP_DIR | Directory where backups are stored. |
| SOURCE_FILE | Path to the list of backup sources. |
| LOG_FILE | Path to the log file. |
| RETENTION_COUNT | Number of valid backups to retain. |
| DISK_THRESHOLD | Disk usage warning threshold. |
| RAM_THRESHOLD | RAM usage warning threshold. |

### 📖 Example Configuration at `syspulse.conf`

```bash
BACKUP_DIR="/path/to/backups"
SOURCE_FILE="/path/to/backup_paths.list"
LOG_FILE="/path/to/syspulse.log"

RETENTION_COUNT=5
DISK_THRESHOLD=85
RAM_THRESHOLD=85
```

> The values above are examples of the configuration format.

### 🗂️ Configuring Backup Sources at `backup_paths.list.example`

Absolute paths to include in backups, one per line. Empty lines and lines starting with `#` are ignored.

```text
/home/user/Documents
/home/user/Projects
# /home/user/Downloads
```

## ⚙️ Backup Workflow

The backup process follows these general stages:

1. Load the configuration.
2. Validate the configured source paths.
3. Run disk and RAM usage checks.
4. Abort the operation if a source is invalid or a resource threshold is reached.
5. Create a temporary backup archive.
6. Verify the archive before treating it as a valid backup.
7. Promote the verified archive to its final destination.
8. Apply the configured retention policy.
9. Record the execution result in the log.

Backup archives use the following naming convention:

```text
syspulse-YYYY-MM-DD_HHMMSS.tar.gz
```

### 🧹 Backup Retention

The retention policy is controlled by RETENTION_COUNT.

Only valid backups should be considered when applying the retention policy. Older backups are removed only after a new archive has been successfully created and verified.

## 📊 System Monitoring

**syspulse** performs disk and RAM usage checks before creating backups.

### 💾 Disk Usage

Disk usage is checked using df.

The check monitors the filesystem where Syspulse is installed.

### 🧠 RAM Usage

RAM usage is monitored against the configured RAM_THRESHOLD.

### ⚡ Threshold Handling

The configured thresholds determine whether a backup can proceed.

When a threshold is reached, the backup operation is aborted and the event is recorded in the log.

## 📰 Logging

By default, the log file is stored at:

```text
~/.config/syspulse/syspulse.log
```

Log entries include a timestamp, severity level, and message:

```text
YYYY-MM-DD HH:mm:ss [LEVEL] Message
```

Supported severity levels:

| Level | Purpose |
|-|-|
| `SUCCESS` | Operation completed successfully. |
| `INFO` | General execution information. |
| `WARN` | Warning or resource threshold notification. |
| `ERROR` | Operation failure or invalid configuration. |

### ☕ Terminal Output

* `SUCCESS` and `INFO` messages are displayed when verbose mode is enabled.
* `WARN` and `ERROR` messages are always displayed.

Verbose mode can be enabled using:

```bash
-v
--verbose
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

## 🌾 `systemd` Integration

**syspulse** supports systemd user timers for scheduled health checks and backups.

The installer can configure:

* Periodic health checks
* Daily backups
* Weekly backups
* Monthly backups
* Custom calendar-based schedules

Timers are managed through the user's systemd instance rather than the system-wide service manager

To inspect configured timers:

```bash
systemctl --user list-timers
```

### ☁ User Linger

The installer may enable user linger when scheduling is configured.

This allows the user's systemd instance and associated timers to remain active without an interactive login session.

User linger is not automatically disabled during uninstallation.

## 🧹 Uninstallation Behavior

The uninstaller:

* Requests confirmation before proceeding.
* Disables known systemd user timers.
* Removes installed files.
* Asks separately whether the internal backup directory should be deleted.

It does not automatically remove:

* Entries added to shell configuration files.
* User linger settings.

## 🔒 Safety and Reliability Principles

1. **Source validation:** Validate all configured source paths before archiving.
2. **Absolute paths:** Require absolute source paths and support spaces in filenames.
3. **Fail safely:** Abort the backup if any source is unavailable.
4. **Temporary archives:** Verify temporary archives before promoting them to valid backups.
5. **Safe retention:** Apply retention only after a new archive has been verified.
6. **Cleanup:** Use Bash trap to ensure temporary files are handled during normal termination and error conditions.
7. **Least privilege:** Avoid unnecessary root privileges.

## 📌 Development Considerations

When modifying **syspulse**, keep the following considerations in mind:

* Preserve compatibility with standard Linux environments.
* Avoid introducing unnecessary external dependencies.
* Handle paths containing spaces correctly.
* Validate configuration values before using them.
* Keep error handling explicit and predictable.
* Ensure failures are recorded in the log.
* Preserve existing exit code semantics unless a change is necessary.
* Ensure temporary files are cleaned up appropriately.
* Do not apply backup retention before successful archive verification.
* Changes to backup creation, validation, or retention should be reviewed carefully because they directly affect data integrity.

## 📝 License

Distributed under the MIT License. See the [LICENSE](./LICENSE) file
