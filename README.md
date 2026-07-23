# WordPress Restic Backup

A production-ready Bash script for backing up WordPress websites using **Restic** with support for **S3-compatible storage** (such as IDrive® e2, Backblaze B2, MinIO, Wasabi, etc.).

The script automatically:

* Creates a MySQL database backup.
* Compresses the database dump.
* Backs up WordPress files.
* Uses Restic incremental backups.
* Initializes the repository automatically.
* Applies retention policies.
* Performs repository integrity checks.
* Sends Telegram notifications.
* Cleans up temporary files.
* Detects WordPress configuration using WP-CLI.

---

# Features

* Incremental backups using Restic
* Automatic repository initialization
* Automatic database backup (mysqldump)
* Gzip-compressed SQL dumps
* Automatic cleanup
* Retention policy support
* Telegram success/failure notifications
* Automatic WP-CLI detection
* Automatic Restic binary detection
* Repository integrity check
* Excludes common cache and backup directories
* Production-ready error handling
* Cron compatible

---

# Requirements

* Linux server
* Bash 4+
* WordPress
* WP-CLI
* Restic
* mysqldump
* curl
* gzip

Optional:

* pigz (faster compression)

---

# Installation

Clone the repository.

```bash
git clone https://github.com/MilanBepari/restic-wp-backup.git

cd restic-wp-backup
```

Make the script executable.

```bash
chmod +x backup.sh
```

---

# Install Required Packages

Ubuntu / Debian

```bash
sudo apt update

sudo apt install restic mysql-client curl gzip
```

Optional

```bash
sudo apt install pigz
```

---

# Install WP-CLI

If WP-CLI is not already installed:

```bash
curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar

chmod +x wp-cli.phar

sudo mv wp-cli.phar /usr/local/bin/wp
```

Verify installation:

```bash
wp --info
```

---

# Create Restic Repository

Example using IDrive e2

```bash
export AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY"

export AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY"

export RESTIC_PASSWORD="YOUR_PASSWORD"

export RESTIC_REPOSITORY="s3:https://YOUR-ENDPOINT/YOUR-BUCKET/website-name"

restic init
```

The script will automatically initialize the repository if it does not already exist.

---

# Configuration

Copy the example configuration.

```bash
cp config.env.example config.env
```

Edit the configuration.

```bash
nano config.env
```

Example:

```bash
SITE_NAME="example.com"

WP_PATH="/home/example/public_html"

TMP_DIR="/tmp"

LOG_FILE="/var/log/wp-restic-backup.log"

RESTIC_REPOSITORY="s3:https://your-endpoint/bucket/example"

RESTIC_PASSWORD=""

AWS_ACCESS_KEY_ID=""

AWS_SECRET_ACCESS_KEY=""

KEEP_DAILY=7
KEEP_WEEKLY=4
KEEP_MONTHLY=6

TELEGRAM_TOKEN=""
TELEGRAM_CHAT_ID=""
```

---

# Telegram Notifications

The script can send notifications when:

* Backup succeeds
* Backup fails
* A required dependency is missing

---

## Create a Telegram Bot

1. Open Telegram.
2. Search for **BotFather**.
3. Start a conversation.
4. Run:

```
/newbot
```

5. Enter a bot name.
6. Enter a unique username.

BotFather will return a token similar to:

```
123456789:AAExxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

Save this as:

```bash
TELEGRAM_TOKEN="YOUR_TOKEN"
```

---

## Get Your Chat ID

Start a conversation with your new bot.

Send any message.

Open:

```
https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
```

Example:

```
https://api.telegram.org/bot123456:ABCDEF/getUpdates
```

Look for:

```json
"chat":{
    "id":123456789
}
```

Use this value:

```bash
TELEGRAM_CHAT_ID="123456789"
```

---

# Test Telegram

Run:

```bash
curl -X POST \
https://api.telegram.org/botYOUR_TOKEN/sendMessage \
-d chat_id=YOUR_CHAT_ID \
-d text="Telegram notification test"
```

You should receive the message immediately.

---

# Running the Script

Run manually.

```bash
sudo ./backup.sh
```

---

# Cron Job

Open root crontab.

```bash
sudo crontab -e
```

Run every day at 2 AM.

```cron
0 2 * * * /path/to/backup.sh >/dev/null 2>&1
```

Example:

```cron
0 2 * * * /opt/wp-restic-backup/backup.sh >/dev/null 2>&1
```

---

# Restore

List snapshots.

```bash
restic snapshots
```

Restore the latest snapshot.

```bash
restic restore latest --target /restore
```

Restore a specific snapshot.

```bash
restic restore SNAPSHOT_ID --target /restore
```

Database dumps are stored as compressed SQL files.

Restore the database.

```bash
gunzip -c database.sql.gz | mysql database_name
```

---

# Retention Policy

The script automatically runs:

```
restic forget --prune
```

Example policy:

* Daily backups: 7
* Weekly backups: 4
* Monthly backups: 6

---

# Repository Integrity Check

The script performs a repository check after backup.

Example:

```
restic check --read-data-subset=5%
```

A full repository check can be run manually.

```bash
restic check --read-data
```

---

# Excluded Paths

Common cache directories are excluded automatically.

Examples include:

* wp-content/cache
* wp-content/upgrade
* wp-content/ai1wm-backups
* wp-content/updraft
* wp-content/w3tc-config
* wp-content/litespeed
* wp-content/uploads/cache

Temporary and archive files are also excluded.

---

# Logs

All output is written to the configured log file.

Example:

```
/var/log/wp-restic-backup.log
```

---

# Troubleshooting

## Restic not found

Verify:

```bash
which restic
```

---

## WP-CLI not found

Verify:

```bash
which wp
```

---

## mysqldump not found

Install:

```bash
sudo apt install mysql-client
```

---

## Telegram not working

Verify:

* Bot token
* Chat ID
* Bot has been started
* Internet connectivity

---

## Permission denied

Run the script as root or a user with permission to:

* Read the WordPress directory
* Read wp-config.php
* Execute WP-CLI
* Run mysqldump
* Access the Restic repository

---

# License

This project is released under the MIT License.

---

# Contributing

Issues and pull requests are welcome.

If you find a bug or have an idea for an improvement, please open an issue or submit a pull request.

---

# Disclaimer

Always verify that your backups can be restored before relying on them in production. A backup is only useful if it can be successfully restored.
