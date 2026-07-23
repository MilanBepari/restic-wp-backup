#!/bin/bash

set -Eeuo pipefail

#############################################
# Load Configuration
#############################################

source /etc/restic/config.env

#############################################

DATE=$(date +"%Y-%m-%d_%H-%M-%S")
START_TIME=$(date +%s)
DB_DUMP="${TMP_DIR}/${SITE_NAME}-${DATE}.sql"
DB_GZ="${DB_DUMP}.gz"

mkdir -p "$TMP_DIR"

exec >> "$LOG_FILE" 2>&1

echo ""
echo "========================================================"
echo "Backup Started : $(date)"
echo "Website        : ${SITE_NAME}"
echo "========================================================"

#############################################
# Telegram Function
#############################################

telegram_send() {

    local MESSAGE="$1"

    curl -s \
        -X POST \
        "https://api.telegram.org/bot${TELEGRAM_TOKEN}/sendMessage" \
        -d chat_id="${TELEGRAM_CHAT_ID}" \
        --data-urlencode text="$MESSAGE" \
        >/dev/null

}

#############################################
# Error Handler
#############################################

backup_failed() {

    local EXIT_CODE=$?

    LOG=$(tail -20 "$LOG_FILE")

    telegram_send "❌ WordPress Backup FAILED

Website:
${SITE_NAME}

Time:
$(date)

Exit Code:
${EXIT_CODE}

Failed Command:
${BASH_COMMAND}

Last 20 Log Lines:

${LOG}"

    rm -f "$DB_DUMP" "$DB_GZ"

    exit $EXIT_CODE
}

trap backup_failed ERR

#############################################
# Check Dependencies
#############################################

check_dependencies() {

    local missing=()

    command -v mysqldump >/dev/null 2>&1 || missing+=("mysqldump")
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v gzip >/dev/null 2>&1 || missing+=("gzip")
    command -v flock >/dev/null 2>&1 || missing+=("flock")

    if (( ${#missing[@]} > 0 )); then

        telegram_send "❌ Backup FAILED

Website:
${SITE_NAME}

Missing command(s):
$(printf '%s\n' "${missing[@]}")"

        echo "Missing commands: ${missing[*]}"
        exit 1
    fi
}

#############################################
# Find Binary
#############################################

find_binary() {

    local VAR_NAME="$1"
    local BINARY_NAME="$2"

    shift 2

    for BIN in "$@"; do

        [[ -n "$BIN" && -x "$BIN" ]] || continue

        printf -v "$VAR_NAME" '%s' "$BIN"

        echo "Found ${BINARY_NAME}: ${BIN}"

        return 0

    done

    telegram_send "❌ WordPress Backup FAILED

Website:
${SITE_NAME}

Reason:
Unable to locate the '${BINARY_NAME}' binary."

    exit 1
}


#############################################
# CHECK WP USER
#############################################

check_wp_user() {

    if ! id "$WP_USER" >/dev/null 2>&1; then

        telegram_send "❌ WordPress Backup FAILED

Website:
${SITE_NAME}

Reason:
WordPress user '$WP_USER' does not exist."

        exit 1
    fi
}

# checking if WP User is available
check_wp_user

#############################################
# Prevent Concurrent Execution
#############################################
LOCK_FILE="${TMP_DIR}/backup.lock"

check_lock() {
    # Open lock file on file descriptor 9 and try to get an exclusive lock
    exec 9> "$LOCK_FILE"
    if ! flock -n 9; then
        # Silently exit if another backup is running, or log it
        echo "Another backup instance is already running. Exiting."
        exit 0
    fi
}

# Call it immediately
check_lock

find_binary RESTIC restic \
    "$(command -v restic 2>/dev/null)" \
    "/usr/local/bin/restic" \
    "/usr/bin/restic" \
    "/bin/restic"

find_binary WPCLI wp \
    "$(command -v wp 2>/dev/null)" \
    "/usr/local/bin/wp" \
    "/usr/bin/wp" \
    "/opt/cpanel/composer/bin/wp"

#############################################
# Verify WP Variable
#############################################

require_variable() {

    local NAME="$1"
    local VALUE="$2"

    if [[ -z "$VALUE" ]]; then

        telegram_send "❌ WordPress Backup FAILED

Website:
${SITE_NAME}

Reason:
Required variable '$NAME' is empty."

        exit 1
    fi
}

if [[ $EUID -eq 0 ]]; then
    WPCLI_CMD=(sudo -u "$WP_USER" "$WPCLI")
else
    WPCLI_CMD=("$WPCLI")
fi

#############################################
# Get WordPress Database Credentials
#############################################

get_wp_config() {

    echo "Reading WordPress configuration..."

    DB_NAME=$("${WPCLI_CMD[@]}" config get DB_NAME \
        --type=constant \
        --path="$WP_PATH" \
        --quiet)

    DB_USER=$("${WPCLI_CMD[@]}" config get DB_USER \
        --type=constant \
        --path="$WP_PATH" \
        --quiet)

    DB_PASS=$("${WPCLI_CMD[@]}" config get DB_PASSWORD \
        --type=constant \
        --path="$WP_PATH" \
        --quiet)

    DB_HOST=$("${WPCLI_CMD[@]}" config get DB_HOST \
        --type=constant \
        --path="$WP_PATH" \
        --quiet)

    require_variable "DB_NAME" "$DB_NAME"
    require_variable "DB_USER" "$DB_USER"
    require_variable "DB_PASS" "$DB_PASS"
    require_variable "DB_HOST" "$DB_HOST"
}

# Check dependencies
check_dependencies

# Get Database Credential
get_wp_config


#############################################
# Check Disk Space Before Dump
#############################################

check_disk_space() {
    local MIN_SPACE_MB=2048 # Require at least 2GB free in TMP_DIR
    local AVAILABLE_MB=$(df -m "$TMP_DIR" | awk 'NR==2 {print $4}')

    if [[ "$AVAILABLE_MB" -lt "$MIN_SPACE_MB" ]]; then
        telegram_send "❌ WordPress Backup FAILED

Website:
${SITE_NAME}

Reason:
Insufficient disk space. Only ${AVAILABLE_MB}MB available in ${TMP_DIR}. Minimum required: ${MIN_SPACE_MB}MB."
        exit 1
    fi
}

check_disk_space

#############################################
# Database Dump
#############################################

echo "Creating database dump..."

mysqldump \
    --single-transaction \
    --quick \
    --lock-tables=false \
    -h "$DB_HOST" \
    -u "$DB_USER" \
    -p"$DB_PASS" \
    "$DB_NAME" > "$DB_DUMP"


#############################################
# Verify Database Dump
#############################################

echo "Verifying database dump..."

if [[ ! -s "$DB_DUMP" ]]; then
    telegram_send "❌ WordPress Backup FAILED
    
Website:
${SITE_NAME}

Reason:
Database dump is empty."
    exit 1
fi

if ! tail -n 10 "$DB_DUMP" | grep -q "Dump completed"; then
    telegram_send "❌ WordPress Backup FAILED
    
Website:
${SITE_NAME}

Reason:
Database dump is incomplete or corrupted."
    rm -f "$DB_DUMP"
    exit 1
fi

#############################################
# Compress Database
#############################################

echo "Compressing database..."

if command -v pigz >/dev/null 2>&1; then
    pigz -9 "$DB_DUMP"
else
    gzip -9 "$DB_DUMP"
fi

#############################################
# Build Exclude Arguments
#############################################

EXCLUDE_ARGS=()

for DIR in "${EXCLUDE_DIRS[@]}"; do
    EXCLUDE_ARGS+=(--exclude "$DIR")
done

for FILE in "${EXCLUDE_FILES[@]}"; do
    EXCLUDE_ARGS+=(--exclude "$FILE")
done

#############################################
# Initialize Repository
#############################################

if ! $RESTIC snapshots >/dev/null 2>&1; then
    echo "Initializing Restic repository..."
    $RESTIC init
fi

#############################################
# Backup
#############################################

echo "Starting Restic backup..."

$RESTIC backup \
    "${WP_PATH}" \
    "${DB_GZ}" \
    "${EXCLUDE_ARGS[@]}" \
    --tag wordpress \
    --tag "${SITE_NAME}" \
    --verbose

#############################################
# Cleanup Temporary Dump
#############################################

rm -f "$DB_GZ"

#############################################
# Retention Policy
#############################################

echo "Applying retention policy..."

$RESTIC forget \
    --keep-daily "$KEEP_DAILY" \
    --keep-weekly "$KEEP_WEEKLY" \
    --keep-monthly "$KEEP_MONTHLY" \
    --prune

#############################################
# Verify Repository
#############################################

echo "Checking repository..."

$RESTIC check --read-data-subset=5%

#############################################
# Finish
#############################################

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# SNAPSHOT=$(
#     "$RESTIC" snapshots --latest 1 --json \
#     | grep -o '"short_id":"[^"]*"' \
#     | cut -d'"' -f4
#     )

# Safely parse the JSON using jq if available, fallback to grep
if command -v jq >/dev/null 2>&1; then
    SNAPSHOT=$("$RESTIC" snapshots --latest 1 --json | jq -r '.[0].short_id')
else
    SNAPSHOT=$("$RESTIC" snapshots --latest 1 --json | grep -o '"short_id":"[^"]*"' | cut -d'"' -f4)
fi

telegram_send "✅ WordPress Backup Successful

Website:
${SITE_NAME}

Snapshot:
${SNAPSHOT}

Duration:
${DURATION} seconds

Completed:
$(date)"

echo ""
echo "========================================================"
echo "Backup Completed Successfully"
echo "Snapshot : ${SNAPSHOT}"
echo "Duration : ${DURATION} seconds"
echo "Finished : $(date)"
echo "========================================================"