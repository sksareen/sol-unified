#!/bin/bash
# Trigger screenshot scan via API
# Can be run manually or via cron job

# Configuration
API_URL="http://localhost:5001/api/scan"
LOG_FILE="scan_log.txt"

# Function to log with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Check if backend is running
if ! curl -s "$API_URL" > /dev/null 2>&1; then
    log_message "ERROR: Backend not running at $API_URL"
    exit 1
fi

# Trigger scan
log_message "Starting scan..."
response=$(curl -s -X POST "$API_URL" -H "Content-Type: application/json")

# Log results
if [ $? -eq 0 ]; then
    log_message "Scan completed: $response"
    echo "$response"
else
    log_message "ERROR: Scan failed"
    exit 1
fi

