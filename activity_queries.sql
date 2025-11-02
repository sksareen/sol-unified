-- Activity Log Sample Queries
-- Database path: ~/Library/Application Support/SolUnified/sol.db
-- Open this database in Cursor to run these queries interactively

-- ===== OVERVIEW QUERIES =====

-- Total events by type
SELECT event_type, COUNT(*) as count 
FROM activity_log 
GROUP BY event_type 
ORDER BY count DESC;

-- Recent activity (last 20 events)
SELECT 
    event_type,
    app_name,
    window_title,
    datetime(timestamp) as time
FROM activity_log 
ORDER BY timestamp DESC 
LIMIT 20;

-- Today's activity
SELECT 
    event_type,
    app_name,
    window_title,
    datetime(timestamp) as time
FROM activity_log 
WHERE date(timestamp) = date('now', 'localtime')
ORDER BY timestamp DESC;

-- ===== APP USAGE STATISTICS =====

-- Most used apps (by activation count)
SELECT 
    app_name,
    COUNT(*) as activations
FROM activity_log 
WHERE event_type = 'appActivate' AND app_name IS NOT NULL
GROUP BY app_name 
ORDER BY activations DESC
LIMIT 10;

-- App usage today
SELECT 
    app_name,
    COUNT(*) as switches,
    datetime(MIN(timestamp)) as first_use,
    datetime(MAX(timestamp)) as last_use
FROM activity_log 
WHERE event_type = 'appActivate' 
    AND date(timestamp) = date('now', 'localtime')
    AND app_name IS NOT NULL
GROUP BY app_name 
ORDER BY switches DESC;

-- ===== TIME-BASED QUERIES =====

-- Hourly activity distribution
SELECT 
    strftime('%H:00', timestamp) as hour,
    COUNT(*) as events
FROM activity_log 
GROUP BY hour 
ORDER BY hour;

-- Events per day (last 7 days)
SELECT 
    date(timestamp) as day,
    COUNT(*) as events
FROM activity_log 
WHERE date(timestamp) >= date('now', '-7 days')
GROUP BY day 
ORDER BY day DESC;

-- ===== DETAILED ANALYSIS =====

-- Window titles by app
SELECT 
    app_name,
    window_title,
    COUNT(*) as occurrences
FROM activity_log 
WHERE window_title IS NOT NULL AND app_name IS NOT NULL
GROUP BY app_name, window_title 
ORDER BY app_name, occurrences DESC;

-- System events (idle, sleep, wake)
SELECT 
    event_type,
    datetime(timestamp) as time
FROM activity_log 
WHERE event_type IN ('idleStart', 'idleEnd', 'screenSleep', 'screenWake')
ORDER BY timestamp DESC;

-- ===== DATA QUALITY CHECKS =====

-- Check for potential duplicates (same event within 2 seconds)
SELECT 
    a1.event_type,
    a1.app_name,
    datetime(a1.timestamp) as time1,
    datetime(a2.timestamp) as time2,
    (julianday(a2.timestamp) - julianday(a1.timestamp)) * 86400 as seconds_apart
FROM activity_log a1
JOIN activity_log a2 ON 
    a1.event_type = a2.event_type 
    AND a1.app_bundle_id = a2.app_bundle_id
    AND a1.id < a2.id
WHERE (julianday(a2.timestamp) - julianday(a1.timestamp)) * 86400 < 2
ORDER BY a1.timestamp DESC
LIMIT 20;

-- Database statistics
SELECT 
    'Total Events' as metric, COUNT(*) as value FROM activity_log
UNION ALL
SELECT 
    'Events Today', COUNT(*) FROM activity_log 
    WHERE date(timestamp) = date('now', 'localtime')
UNION ALL
SELECT 
    'Unique Apps', COUNT(DISTINCT app_bundle_id) FROM activity_log 
    WHERE app_bundle_id IS NOT NULL
UNION ALL
SELECT 
    'Date Range', 
    date(MIN(timestamp)) || ' to ' || date(MAX(timestamp)) 
    FROM activity_log;

