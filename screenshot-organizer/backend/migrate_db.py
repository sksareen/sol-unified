#!/usr/bin/env python3
"""
Database migration script to add favorites and settings columns
"""

import sqlite3
import os

DB_PATH = "screenshots.db"

def migrate_database():
    """Add new columns to existing database"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    print("Starting database migration...")
    
    # Check if columns exist and add them if needed
    cursor.execute("PRAGMA table_info(screenshots)")
    columns = [row[1] for row in cursor.fetchall()]
    
    if 'is_favorite' not in columns:
        print("Adding is_favorite column...")
        cursor.execute("ALTER TABLE screenshots ADD COLUMN is_favorite INTEGER DEFAULT 0")
        print("✓ Added is_favorite column")
    else:
        print("✓ is_favorite column already exists")
    
    if 'favorited_at' not in columns:
        print("Adding favorited_at column...")
        cursor.execute("ALTER TABLE screenshots ADD COLUMN favorited_at TEXT")
        print("✓ Added favorited_at column")
    else:
        print("✓ favorited_at column already exists")
    
    if 'analysis_cost' not in columns:
        print("Adding analysis_cost column...")
        cursor.execute("ALTER TABLE screenshots ADD COLUMN analysis_cost REAL DEFAULT 0.0")
        print("✓ Added analysis_cost column")
    else:
        print("✓ analysis_cost column already exists")
    
    # Check if settings table exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='settings'")
    if not cursor.fetchone():
        print("Creating settings table...")
        cursor.execute("""
            CREATE TABLE settings (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL,
                updated_at TEXT
            )
        """)
        
        cursor.execute("""
            INSERT INTO settings (key, value, updated_at) 
            VALUES 
                ('auto_scan_enabled', 'false', datetime('now')),
                ('scan_interval_minutes', '30', datetime('now')),
                ('max_scans_per_batch', '5', datetime('now')),
                ('single_scan_mode', 'true', datetime('now'))
        """)
        print("✓ Created settings table with defaults")
    else:
        print("✓ Settings table already exists")
    
    conn.commit()
    conn.close()
    
    print("\n✅ Database migration completed successfully!")

if __name__ == '__main__':
    if not os.path.exists(DB_PATH):
        print(f"Error: Database file '{DB_PATH}' not found!")
        print("Please run the main app first to create the database.")
        exit(1)
    
    migrate_database()

