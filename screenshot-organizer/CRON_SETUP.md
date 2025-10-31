# Auto-Scan Setup with Cron

This guide shows you how to automatically scan for new screenshots on a schedule using cron.

## ⚠️ Important Considerations

**Cost Warning**: Running every 2 minutes means up to 720 scans per day. If you take 10 new screenshots per day, that's ~$0.01/day. But be aware of:
- API rate limits
- Unnecessary processing (most scans will find nothing new)
- Battery usage if on laptop

**Recommendation**: Start with every 15-30 minutes, or trigger manually after screenshot sessions.

## Option 1: Python Script (Recommended)

### 1. Make sure `requests` is installed:
```bash
cd backend
source venv/bin/activate
pip install requests
```

### 2. Test the script manually:
```bash
cd backend
python3 trigger_scan.py
```

### 3. Set up cron job:
```bash
# Edit your crontab
crontab -e
```

Add one of these lines (choose your preferred interval):

```cron
# Every 2 minutes (aggressive - 720 scans/day)
*/2 * * * * cd /Users/savarsareen/Library/Mobile\ Documents/com~apple~CloudDocs/Obsidian\ Vault/brutalist-apps-ecosystem/screenshot-organizer/backend && /usr/local/bin/python3 trigger_scan.py >> scan_cron.log 2>&1

# Every 15 minutes (recommended - 96 scans/day)
*/15 * * * * cd /Users/savarsareen/Library/Mobile\ Documents/com~apple~CloudDocs/Obsidian\ Vault/brutalist-apps-ecosystem/screenshot-organizer/backend && /usr/local/bin/python3 trigger_scan.py >> scan_cron.log 2>&1

# Every 30 minutes (balanced - 48 scans/day)
*/30 * * * * cd /Users/savarsareen/Library/Mobile\ Documents/com~apple~CloudDocs/Obsidian\ Vault/brutalist-apps-ecosystem/screenshot-organizer/backend && /usr/local/bin/python3 trigger_scan.py >> scan_cron.log 2>&1

# Every hour (conservative - 24 scans/day)
0 * * * * cd /Users/savarsareen/Library/Mobile\ Documents/com~apple~CloudDocs/Obsidian\ Vault/brutalist-apps-ecosystem/screenshot-organizer/backend && /usr/local/bin/python3 trigger_scan.py >> scan_cron.log 2>&1

# Only during work hours (9 AM - 6 PM, Mon-Fri)
*/15 9-18 * * 1-5 cd /Users/savarsareen/Library/Mobile\ Documents/com~apple~CloudDocs/Obsidian\ Vault/brutalist-apps-ecosystem/screenshot-organizer/backend && /usr/local/bin/python3 trigger_scan.py >> scan_cron.log 2>&1
```

## Option 2: Shell Script

### 1. Test the script:
```bash
cd backend
./trigger_scan.sh
```

### 2. Add to crontab:
```bash
crontab -e
```

```cron
# Every 15 minutes
*/15 * * * * /Users/savarsareen/Library/Mobile\ Documents/com~apple~CloudDocs/Obsidian\ Vault/brutalist-apps-ecosystem/screenshot-organizer/backend/trigger_scan.sh >> scan_cron.log 2>&1
```

## Option 3: LaunchAgent (macOS Native - Best for macOS)

Create a Launch Agent for more reliable scheduling on macOS:

### 1. Create plist file:
```bash
nano ~/Library/LaunchAgents/com.screenshot-organizer.scan.plist
```

### 2. Add this content:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.screenshot-organizer.scan</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/python3</string>
        <string>/Users/savarsareen/Library/Mobile Documents/com~apple~CloudDocs/Obsidian Vault/brutalist-apps-ecosystem/screenshot-organizer/backend/trigger_scan.py</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>/Users/savarsareen/Library/Mobile Documents/com~apple~CloudDocs/Obsidian Vault/brutalist-apps-ecosystem/screenshot-organizer/backend</string>
    
    <key>StartInterval</key>
    <integer>900</integer> <!-- 900 seconds = 15 minutes -->
    
    <key>StandardOutPath</key>
    <string>/Users/savarsareen/Library/Mobile Documents/com~apple~CloudDocs/Obsidian Vault/brutalist-apps-ecosystem/screenshot-organizer/backend/launchagent.log</string>
    
    <key>StandardErrorPath</key>
    <string>/Users/savarsareen/Library/Mobile Documents/com~apple~CloudDocs/Obsidian Vault/brutalist-apps-ecosystem/screenshot-organizer/backend/launchagent.error.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>OPENROUTER_API_KEY</key>
        <string>sk-or-v1-your-key-here</string>
    </dict>
</dict>
</plist>
```

**Note**: The API key is already configured in `main.py`, so the EnvironmentVariables section is optional.

### 3. Load the Launch Agent:
```bash
launchctl load ~/Library/LaunchAgents/com.screenshot-organizer.scan.plist
```

### 4. Control the Launch Agent:
```bash
# Start
launchctl start com.screenshot-organizer.scan

# Stop
launchctl stop com.screenshot-organizer.scan

# Unload (disable)
launchctl unload ~/Library/LaunchAgents/com.screenshot-organizer.scan.plist
```

## Monitoring

### View logs:
```bash
# Python script log
tail -f backend/scan_log.txt

# Cron log (if using cron)
tail -f backend/scan_cron.log

# LaunchAgent log (if using LaunchAgent)
tail -f backend/launchagent.log
```

### Check if it's working:
```bash
# View last 10 scan results
tail -20 backend/scan_log.txt

# Count scans today
grep "$(date +%Y-%m-%d)" backend/scan_log.txt | wc -l
```

## Making Sure Backend Stays Running

The backend needs to be running for scheduled scans to work. Options:

### Option A: Run backend as a service

Create another Launch Agent to keep the backend running:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.screenshot-organizer.backend</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/Users/savarsareen/Library/Mobile Documents/com~apple~CloudDocs/Obsidian Vault/brutalist-apps-ecosystem/screenshot-organizer/backend/venv/bin/python</string>
        <string>main.py</string>
    </array>
    
    <key>WorkingDirectory</key>
    <string>/Users/savarsareen/Library/Mobile Documents/com~apple~CloudDocs/Obsidian Vault/brutalist-apps-ecosystem/screenshot-organizer/backend</string>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/Users/savarsareen/Library/Mobile Documents/com~apple~CloudDocs/Obsidian Vault/brutalist-apps-ecosystem/screenshot-organizer/backend/backend.log</string>
    
    <key>StandardErrorPath</key>
    <string>/Users/savarsareen/Library/Mobile Documents/com~apple~CloudDocs/Obsidian Vault/brutalist-apps-ecosystem/screenshot-organizer/backend/backend.error.log</string>
    
    <key>EnvironmentVariables</key>
    <dict>
        <key>OPENROUTER_API_KEY</key>
        <string>sk-or-v1-your-key-here</string>
    </dict>
</dict>
</plist>
```

**Note**: The API key is already configured in `main.py`, so the EnvironmentVariables section is optional.

Save to: `~/Library/LaunchAgents/com.screenshot-organizer.backend.plist`

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.screenshot-organizer.backend.plist
```

### Option B: Manual start with auto-scan check

Add a check in the scan script to start backend if not running.

## Cost Estimation

At ~$0.00015 per image with GPT-4o-mini:

| Interval | Scans/Day | New Screenshots/Day | Cost/Day | Cost/Month |
|----------|-----------|---------------------|----------|------------|
| 2 min    | 720       | 10                  | $0.0015  | $0.045     |
| 15 min   | 96        | 10                  | $0.0015  | $0.045     |
| 30 min   | 48        | 10                  | $0.0015  | $0.045     |

**Note**: The cost is the same regardless of scan frequency because the app only analyzes NEW screenshots (duplicate detection). More frequent scans just mean faster discovery.

## Troubleshooting

### Cron isn't working:
1. Check if cron has Full Disk Access (macOS Security & Privacy settings)
2. Use absolute paths in crontab
3. Check `scan_cron.log` for errors

### Backend not responding:
1. Make sure it's running: `curl http://localhost:5001/api/stats`
2. Check if port 5001 is in use: `lsof -i :5001`
3. Restart backend: `./run.sh`

### Permission errors:
```bash
chmod +x trigger_scan.py trigger_scan.sh
```

## Recommended Setup

For most users:
1. **Run backend as Launch Agent** (always-on)
2. **Scan every 15-30 minutes** (good balance)
3. **Monitor logs occasionally** to ensure it's working

This gives you near-real-time organization without excessive API calls.

