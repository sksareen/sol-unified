#!/usr/bin/env python3
"""
Test script for memory tracking system
Simulates agent checking for changes
"""

import json
import os
from datetime import datetime, timedelta

def load_context():
    """Load current ai_context.json"""
    context_path = "/Users/savarsareen/coding/mable/sol-unified/ai_context.json"
    with open(context_path, 'r') as f:
        return json.load(f)

def analyze_memory_efficiency(context):
    """Analyze the memory system for token efficiency"""
    memory = context.get("memory", {})
    
    # Calculate token usage
    memory_json = json.dumps(memory)
    estimated_tokens = len(memory_json.split()) * 1.3  # rough estimate
    
    # Extract key insights
    data_sources = memory.get("data_sources", {})
    summary = memory.get("smart_summary", {})
    
    changes_detected = sum(
        source.get("new_since_check", 0) 
        for source in data_sources.values() 
        if isinstance(source, dict)
    )
    
    print("🧠 Memory System Analysis")
    print("=" * 40)
    print(f"Estimated token usage: ~{estimated_tokens:.0f} tokens")
    print(f"Last check: {memory.get('last_check', 'Never')}")
    print(f"Change window: {memory.get('change_window', 'Unknown')}")
    print(f"Changes detected: {changes_detected}")
    print(f"Session type: {summary.get('session_type', 'Unknown')}")
    print(f"Focus areas: {summary.get('focus_areas', [])}")
    print(f"Productivity score: {summary.get('productivity_score', 0):.2f}")
    
    # Check each data source
    print("\n📊 Data Source Status:")
    for source_name, source_data in data_sources.items():
        if isinstance(source_data, dict):
            activity = source_data.get("recent_activity", "No data")
            new_count = source_data.get("new_since_check", 0)
            print(f"  {source_name}: {activity} ({new_count} new)")

def simulate_agent_check():
    """Simulate what an agent would see"""
    context = load_context()
    memory = context.get("memory", {})
    
    print("\n🤖 Agent Memory Briefing")
    print("=" * 40)
    
    # Quick status
    last_check = memory.get("last_check", "Never")
    summary = memory.get("smart_summary", {})
    session_type = summary.get("session_type", "idle")
    
    print(f"Session: {session_type.title()}")
    print(f"Last check: {last_check}")
    
    # Changes summary
    data_sources = memory.get("data_sources", {})
    active_sources = []
    
    for source_name, source_data in data_sources.items():
        if isinstance(source_data, dict):
            new_count = source_data.get("new_since_check", 0)
            if new_count > 0:
                activity = source_data.get("recent_activity", "")
                active_sources.append(f"{source_name}: {activity}")
    
    if active_sources:
        print("\nRecent activity:")
        for activity in active_sources:
            print(f"  • {activity}")
    else:
        print("\nNo significant changes detected")
    
    # Key insights
    insights = summary.get("key_insights", [])
    if insights:
        print("\nKey insights:")
        for insight in insights:
            print(f"  💡 {insight}")

def check_agent_bridge():
    """Check what's available in the agent bridge for memory intelligence"""
    bridge_path = "/Users/savarsareen/coding/research/agent_bridge.json"
    
    try:
        with open(bridge_path, 'r') as f:
            bridge = json.load(f)
        
        print("\n🌉 Agent Bridge Memory Intelligence")
        print("=" * 40)
        
        sol_memory = bridge.get("sol_unified_memory", {})
        if sol_memory:
            print("✅ Memory intelligence available")
            
            # Data activity
            data_activity = sol_memory.get("data_activity", {})
            print(f"Data activity: {data_activity.get('summary', 'No data')}")
            
            # User context
            user_context = sol_memory.get("user_context", {})
            print(f"Session type: {user_context.get('session_type', 'Unknown')}")
            print(f"Engagement: {user_context.get('engagement_level', 'Unknown')}")
            
            # Productivity signals
            productivity = sol_memory.get("productivity_signals", {})
            if productivity.get("signals"):
                print("Productivity signals:")
                for signal in productivity["signals"]:
                    print(f"  • {signal}")
            
            # Opportunity indicators
            opportunities = sol_memory.get("opportunity_indicators", {})
            if opportunities.get("indicators"):
                print("Opportunities:")
                for opportunity in opportunities["indicators"]:
                    print(f"  💰 {opportunity}")
        else:
            print("❌ No memory intelligence in bridge yet")
            print("Run Sol-Unified app to populate memory data")
            
    except FileNotFoundError:
        print("❌ Agent bridge file not found")
    except Exception as e:
        print(f"❌ Error reading bridge: {e}")

if __name__ == "__main__":
    context = load_context()
    analyze_memory_efficiency(context)
    simulate_agent_check()
    check_agent_bridge()