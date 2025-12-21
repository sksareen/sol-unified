# Mable: Personal Context Capture - Implementation Roadmap

Based on existing Sol Unified codebase at `/Users/savarsareen/coding/hanu/components/hanuPARTS/sol-unified`

## Foundation Status
✅ **Production Ready:**
- SwiftUI macOS app with global hotkey (Option + `)
- SQLite database with Notes, Clipboard, Screenshots tables
- Clipboard monitoring with deduplication
- Screenshot AI analysis via Python backend
- File system monitoring capabilities

## Implementation Tasks (50 x 2-hour sprints)

### Phase 1: Content Capture Expansion (Tasks 1-15)
1. Extend ClipboardMonitor.swift to detect URL patterns and extract webpage metadata
2. Add PDF text extraction using PDFKit to ScreenshotAnalyzer.swift
3. Create FileWatcher.swift using FSEventStream to monitor ~/Downloads
4. Build BrowserImporter.swift to parse Chrome/Safari SQLite databases
5. Add document content extraction for .docx, .txt, .md file types
6. Implement email content capture from Mail.app database
7. Create CalendarImporter.swift to capture event data from Calendar.app
8. Add contact information sync from Contacts.app database
9. Implement Finder bookmark and recent files capture
10. Create messaging import from Messages.app database
11. Add Terminal command history capture from shell history files
12. Implement Xcode project and file tracking integration
13. Create Slack workspace data import via API
14. Add Discord message history import via API
15. Implement Notion database sync via API

### Phase 2: Content Processing & Intelligence (Tasks 16-25)
16. Integrate OpenAI embeddings API for vector representation generation
17. Add pgvector extension to Database.swift for semantic similarity search
18. Create ContentClassifier.swift using Claude API for automatic categorization
19. Implement content summarization pipeline for long-form documents
20. Add duplicate detection using MinHash algorithm across content types
21. Create relationship mapping using graph algorithms and content similarity
22. Implement named entity recognition for people, places, companies
23. Add temporal pattern detection for recurring content themes
24. Create content quality scoring based on engagement and reference frequency
25. Implement automatic tag generation using LLM analysis

### Phase 3: Search & Retrieval (Tasks 26-35)
26. Build unified search interface combining full-text and vector search
27. Add faceted search with dynamic filters by content type, date, source
28. Implement search result ranking using relevance scoring algorithms
29. Create saved search functionality with real-time notifications
30. Add fuzzy search capabilities for handling typos and variations
31. Implement search analytics to track query patterns and result quality
32. Create search suggestions based on content and usage patterns
33. Add contextual search that considers current application and activity
34. Implement cross-reference search to find related content clusters
35. Create search export functionality for sharing query results

### Phase 4: User Interface & Experience (Tasks 36-45)
36. Build timeline visualization showing chronological content flow
37. Create content relationship graph using D3.js-style force layout
38. Add personal analytics dashboard with productivity insights
39. Implement smart notification system for relevant content surfacing
40. Create content recommendation engine based on usage patterns
41. Build keyboard shortcuts for rapid content access and navigation
42. Add content preview system with rich media support
43. Implement batch operations for content management and organization
44. Create customizable dashboard with widget-based layout
45. Add dark mode and accessibility features for inclusive design

### Phase 5: Data Management & Integration (Tasks 46-50)
46. Build comprehensive backup system with incremental snapshots
47. Create data export functionality for JSON, CSV, and standard formats
48. Implement data privacy controls with selective content exclusion
49. Add cross-device sync architecture preparation with conflict resolution
50. Create API layer with REST endpoints for external application integration

## Technical Architecture

### Core Components
- **Database**: SQLite with pgvector extension for hybrid search
- **AI Processing**: OpenAI GPT-4 + Claude for analysis, OpenAI embeddings for vectors
- **File Monitoring**: FSEventStream for real-time file system changes
- **Content Processing**: Parallel processing pipeline with async/await
- **Search Engine**: Combined inverted index + vector similarity search

### Performance Targets
- Content ingestion: <500ms per item
- Search response: <100ms for text, <300ms for semantic
- Memory usage: <200MB baseline, <1GB with full content cache
- Database size: Efficient compression with <10GB for 1M items

### Security & Privacy
- Local-first architecture with encrypted database
- API key management with secure keychain storage
- Content filtering with user-defined exclusion rules
- Audit logging for all data access and modifications

## Success Metrics
- **Content Coverage**: 95% of digital interactions captured
- **Search Accuracy**: >90% relevant results in top 5
- **Response Time**: <2 second end-to-end for any query
- **Storage Efficiency**: <50MB per 1000 captured items
- **User Engagement**: Daily usage >30 minutes average

## Risk Mitigation
- **API Rate Limits**: Implement exponential backoff and local caching
- **Storage Growth**: Automatic archival and compression policies
- **Privacy Concerns**: Granular content exclusion and local processing
- **Performance Degradation**: Lazy loading and content pagination
- **Data Loss**: Automated backups with integrity verification