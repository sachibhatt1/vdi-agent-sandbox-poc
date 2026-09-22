#!/bin/sh
set -e

STATE_FILE="/workspace/state.txt"
mkdir -p /workspace

if [ ! -f "$STATE_FILE" ]; then
  echo "1" > "$STATE_FILE"
  echo "timestamp=$(date +%s)" >> "$STATE_FILE"
  echo "State absent. Initialized counter to 1."
else
  COUNTER=$(head -n 1 "$STATE_FILE")
  COUNTER=$((COUNTER + 1))
  echo "$COUNTER" > "$STATE_FILE"
  echo "timestamp=$(date +%s)" >> "$STATE_FILE"
  echo "State present. Incremented counter to $COUNTER."
fi

# Keep container running
exec tail -f /dev/null
