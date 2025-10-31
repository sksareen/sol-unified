#!/usr/bin/env python3
"""
Trigger screenshot scan via API
Alternative to shell script - more cross-platform
"""

import requests
import json
from datetime import datetime
import sys

API_URL = "http://localhost:5001/api/scan"
LOG_FILE = "scan_log.txt"

def log_message(message):
    """Log message with timestamp"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    log_entry = f"[{timestamp}] {message}\n"
    
    with open(LOG_FILE, 'a') as f:
        f.write(log_entry)
    
    print(log_entry.strip())

def trigger_scan():
    """Trigger the scan endpoint"""
    try:
        log_message("Starting scan...")
        response = requests.post(API_URL, timeout=300)  # 5 min timeout for large scans
        
        if response.status_code == 200:
            data = response.json()
            log_message(f"Scan completed: {json.dumps(data)}")
            print(json.dumps(data, indent=2))
            return 0
        else:
            log_message(f"ERROR: Scan failed with status {response.status_code}")
            return 1
            
    except requests.exceptions.ConnectionError:
        log_message("ERROR: Cannot connect to backend. Is it running?")
        return 1
    except requests.exceptions.Timeout:
        log_message("ERROR: Scan timed out (took longer than 5 minutes)")
        return 1
    except Exception as e:
        log_message(f"ERROR: {str(e)}")
        return 1

if __name__ == "__main__":
    sys.exit(trigger_scan())

