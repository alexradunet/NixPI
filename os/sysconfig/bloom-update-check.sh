#!/usr/bin/env bash
set -euo pipefail

STATUS_DIR="${HOME}/.bloom"
STATUS_FILE="${STATUS_DIR}/update-status.json"

mkdir -p "$STATUS_DIR"

CHECKED=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if bootc upgrade --check 2>/dev/null; then
    VERSION=$(bootc status --json 2>/dev/null | jq -r '.status.staged // empty' || echo "")
    AVAILABLE=true
else
    VERSION=""
    AVAILABLE=false
fi

# Preserve notified flag if status file already exists
NOTIFIED=false
if [ -f "$STATUS_FILE" ]; then
    PREV_NOTIFIED=$(jq -r '.notified // false' "$STATUS_FILE" 2>/dev/null || echo "false")
    # Reset notified if this is a new update
    if [ "$AVAILABLE" = "true" ]; then
        NOTIFIED=$PREV_NOTIFIED
    fi
fi

cat > "$STATUS_FILE" <<EOF
{"checked": "$CHECKED", "available": $AVAILABLE, "version": "$VERSION", "notified": $NOTIFIED}
EOF
