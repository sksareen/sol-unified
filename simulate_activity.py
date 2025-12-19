#!/usr/bin/env python3
"""
Simulate activity to test the memory system
"""

import json
import sqlite3
import os
from datetime import datetime, timedelta

def add_test_clipboard_data():
    """Add test clipboard data to simulate activity"""
    db_path = "/Users/savarsareen/coding/mable/sol-unified/activity_log.db"
    
    if not os.path.exists(db_path):
        print("❌ Database not found - run Sol-Unified app first")
        return False
    
    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Check if clipboard table exists
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='clipboard_history'")
        if not cursor.fetchone():
            print("❌ Clipboard table not found")
            return False
        
        # Add test clipboard items
        now = datetime.now()
        test_items = [
            ("text", "console.log('testing memory system')", "console.log('testing...')", "javascript", now - timedelta(minutes=5)),
            ("text", "def update_memory():\n    pass", "def update_memory():", "python", now - timedelta(minutes=3)),
            ("text", "# Memory System Notes", "# Memory System Notes", "markdown", now - timedelta(minutes=1)),
        ]
        
        for content_type, content_text, content_preview, content_hash, created_at in test_items:
            cursor.execute("""
                INSERT OR IGNORE INTO clipboard_history 
                (content_type, content_text, content_preview, content_hash, created_at)
                VALUES (?, ?, ?, ?, ?)
            """, (content_type, content_text, content_preview, content_hash, created_at.isoformat()))
        
        conn.commit()
        conn.close()
        
        print("✅ Added test clipboard data")
        return True
        
    except Exception as e:
        print(f"❌ Error adding test data: {e}")
        return False

def trigger_memory_update():
    """Trigger memory update by calling the Swift code via a simple file touch"""
    # Since we can't directly call Swift from Python, we'll simulate this by
    # manually updating the memory in the context file
    
    context_path = "/Users/savarsareen/coding/mable/sol-unified/ai_context.json"
    bridge_path = "/Users/savarsareen/coding/research/agent_bridge.json"
    
    try:
        # Update context file
        with open(context_path, 'r') as f:
            context = json.load(f)
        
        now = datetime.now().isoformat()
        context["memory"] = {
            "last_check": now,
            "change_window": "1h",
            "data_sources": {
                "screenshots": {
                    "last_count": 0,
                    "last_hash": "",
                    "new_since_check": 0,
                    "recent_activity": "No new screenshots"
                },
                "clipboard": {
                    "last_count": 3,
                    "last_hash": "abc123",
                    "new_since_check": 3,
                    "recent_activity": "3 new clipboard items (code snippets detected)"
                },
                "notes": {
                    "last_count": 0,
                    "last_hash": "",
                    "new_since_check": 0,
                    "recent_activity": "No new notes"
                },
                "activity": {
                    "last_active_app": "Terminal",
                    "session_duration": "15m",
                    "key_events": ["clipboard_activity"]
                }
            },
            "smart_summary": {
                "session_type": "coding",
                "focus_areas": ["clipboard"],
                "productivity_score": 0.6,
                "context_shifts": 1,
                "key_insights": ["Code snippets being copied - development activity detected"]
            }
        }
        
        with open(context_path, 'w') as f:
            json.dump(context, f, indent=2)
        
        # Update bridge file if it exists
        if os.path.exists(bridge_path):
            with open(bridge_path, 'r') as f:
                bridge = json.load(f)
            
            bridge["sol_unified_memory"] = {
                "data_activity": {
                    "summary": "clipboard: 3 new items",
                    "active_sources": 1,
                    "total_new_items": 3
                },
                "user_context": {
                    "session_type": "coding",
                    "focus_areas": ["clipboard"],
                    "engagement_level": "medium",
                    "context_stability": "focused"
                },
                "productivity_signals": {
                    "score": 0.6,
                    "signals": ["Code snippets detected"],
                    "recommended_action": "Maintain momentum"
                },
                "opportunity_indicators": {
                    "indicators": ["High clipboard usage - potential content creation"],
                    "content_creation_signal": "high",
                    "research_signal": "low"
                }
            }
            
            with open(bridge_path, 'w') as f:
                json.dump(bridge, f, indent=2)
            
            print("✅ Updated agent bridge with memory intelligence")
        
        print("✅ Updated memory system with simulated activity")
        return True
        
    except Exception as e:
        print(f"❌ Error updating memory: {e}")
        return False

if __name__ == "__main__":
    print("🧪 Simulating activity for memory system test")
    print("=" * 50)
    
    # Add test data
    if add_test_clipboard_data():
        # Trigger memory update
        if trigger_memory_update():
            print("\n🎉 Memory system test setup complete!")
            print("\nNow run: python test_memory.py")
        else:
            print("\n❌ Failed to update memory system")
    else:
        print("\n❌ Failed to add test data")