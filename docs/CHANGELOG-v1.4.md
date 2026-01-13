# Changelog v1.4 - People CRM & Agent Enhancements

**Release Date**: January 2026

## Overview

This release introduces a comprehensive People/CRM feature with network visualization, enhanced AI agent capabilities, and several UX improvements.

---

## New Features

### People/CRM Tab (Major Feature)

A full-featured personal CRM with relational data model and network visualization.

**Core Functionality:**
- **People Management**: Add, edit, and delete contacts with rich metadata
  - Name, email, phone, LinkedIn, location, current city
  - One-liner descriptions (e.g., "CEO at Acme Corp")
  - Free-form notes
  - Flexible tagging system

- **Organizations**: Track companies and schools
  - Link people to organizations with roles and dates
  - Organization types: company, school, nonprofit, government, other

- **Connections**: Map relationships between people
  - Connection types: known, friend, colleague, family, mentor, introduced
  - Context notes for how people know each other
  - Bidirectional relationship tracking

**Views:**
- **List View**: Grouped display with search
  - Grouping options: A-Z, Company, Tag, Recent
  - Multi-field search across name, email, tags, company, notes
  - Person rows showing key info at a glance

- **Graph View**: Force-directed network visualization
  - Interactive canvas with zoom/pan
  - Node size based on connection count
  - Edge colors by connection type
  - Click nodes to view/edit person details

**Import:**
- Import from Obsidian CRM database (`network.db`)
- Preserves people, organizations, tags, and connections
- Progress tracking during import

### New Agent Tools

Five new tools for AI agent integration with the People CRM:

| Tool | Description |
|------|-------------|
| `search_people` | Search contacts by name, company, tag, or notes |
| `add_person` | Create new person with full metadata |
| `update_person` | Update existing person's information |
| `add_connection` | Link two people with relationship context |
| `get_network` | Retrieve full network data for analysis |

**Example Agent Interactions:**
- "Who do I know at Google?"
- "Add John Smith - we met at the tech conference"
- "How is Sarah connected to Mike?"
- "Show me everyone tagged as 'investor'"

### Agent Welcome Screen

The Agent tab now shows a welcome screen with example prompts before the first message:

**Categories:**
- **People & Network**: "Who do I know at [company]?", "Add a new contact"
- **Calendar & Scheduling**: "What's on my calendar today?", "Schedule a meeting"
- **Memory & Context**: "What do you know about me?", "Remember that I..."

Clickable examples populate the input field for quick interaction.

---

## Improvements

### Calendar Performance

- **Event Caching**: 5-minute cache for calendar events per date
- **Lazy Loading**: Events only refresh when cache expires or manually triggered
- **Force Refresh**: Manual refresh button invalidates cache and reloads
- Significantly reduces API calls and improves tab switching performance

### Privacy Enhancement

- **Neural Context Off by Default**: Screen recording feature (for work context detection) is now opt-in
- New toggle in Settings under Privacy section
- Clear warning about Screen Recording permission requirement
- Feature only activates when explicitly enabled by user

### Tab Navigation

- Reordered tabs for better workflow:
  1. Agent (⌘1)
  2. Calendar (⌘2)
  3. Notes (⌘3)
  4. Tasks (⌘4)
  5. People (⌘5)
  6. Context (⌘6)

---

## Database Schema Additions

New tables added to `sol.db`:

```sql
-- Core people table
CREATE TABLE people (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    one_liner TEXT,
    notes TEXT,
    location TEXT,
    current_city TEXT,
    email TEXT,
    phone TEXT,
    linkedin TEXT,
    board_priority TEXT,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

-- Organizations (companies, schools)
CREATE TABLE organizations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    industry TEXT,
    location TEXT,
    website TEXT,
    description TEXT,
    created_at REAL NOT NULL,
    updated_at REAL NOT NULL
);

-- Person-to-organization relationships
CREATE TABLE person_organizations (
    id TEXT PRIMARY KEY,
    person_id TEXT NOT NULL,
    organization_id TEXT NOT NULL,
    role TEXT,
    start_date TEXT,
    end_date TEXT,
    is_current INTEGER DEFAULT 1,
    FOREIGN KEY (person_id) REFERENCES people(id),
    FOREIGN KEY (organization_id) REFERENCES organizations(id)
);

-- Person-to-person connections
CREATE TABLE person_connections (
    id TEXT PRIMARY KEY,
    person_a_id TEXT NOT NULL,
    person_b_id TEXT NOT NULL,
    connection_type TEXT DEFAULT 'known',
    context TEXT,
    strength INTEGER DEFAULT 5,
    created_at REAL NOT NULL,
    FOREIGN KEY (person_a_id) REFERENCES people(id),
    FOREIGN KEY (person_b_id) REFERENCES people(id)
);

-- Tags for people
CREATE TABLE person_tags (
    id TEXT PRIMARY KEY,
    person_id TEXT NOT NULL,
    tag TEXT NOT NULL,
    FOREIGN KEY (person_id) REFERENCES people(id),
    UNIQUE(person_id, tag)
);
```

---

## File Changes

### New Files
```
SolUnified/Features/People/
├── Models/
│   └── PeopleModels.swift        # Person, Organization, Connection models
├── Views/
│   ├── PeopleView.swift          # Main container with list/graph toggle
│   ├── PeopleListView.swift      # Grouped list with search
│   ├── PeopleGraphView.swift     # Force-directed network graph
│   ├── PersonDetailView.swift    # View/edit person sheet
│   └── PersonRowView.swift       # List row component
├── Import/
│   └── ObsidianImporter.swift    # Import from Obsidian network.db
└── PeopleStore.swift             # CRUD, search, relationship queries
```

### Modified Files
- `SolUnified/Core/Database.swift` - Added 5 new table migrations
- `SolUnified/Shared/Models.swift` - Added `AppTab.people`, 5 new `AgentTool` cases
- `SolUnified/Shared/TabNavigator.swift` - Added People tab, reordered tabs
- `SolUnified/Features/Agent/Actions/ActionDispatcher.swift` - Added 5 tool executors
- `SolUnified/Features/Agent/API/ClaudeAPIClient.swift` - Added 5 tool schemas
- `SolUnified/Features/Agent/UI/ChatView.swift` - Added welcome screen
- `SolUnified/Features/Agent/UI/ChatMessageView.swift` - Added People tool icons
- `SolUnified/Features/AgentContext/CalendarStore.swift` - Added caching
- `SolUnified/Features/Calendar/CalendarView.swift` - Added force refresh
- `SolUnified/Shared/Settings.swift` - Added neuralContextEnabled setting
- `SolUnified/Features/Activity/ValueComputer.swift` - Gated screen capture

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Cmd + 5` | Switch to People tab |
| `Cmd + 6` | Switch to Context tab |

---

## Known Issues

- Graph view performance may degrade with very large networks (500+ people)
- Obsidian import requires manual trigger from settings

---

## Upgrade Notes

- Database migrations run automatically on first launch
- Existing data is preserved
- No manual intervention required
