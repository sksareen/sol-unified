++ also add markdown formatting to the notes
++ add photos feature tab

## User (checkpoint)

write a plan to improve the SOl app. it should include being able to pull from and sort photos from apple photos. and to have an iOS app that synces this all so i can access on my phone. future thi acts like a place i can sort and add data to my images and clipboard to use as future training data. and also as a global pinterst/pocket style ap pwhere i can pull from curated images/contenet. do you undersandg?

## Assistant

Yes — I understand. You want a plan to improve the SOl app that includes:

- Importing, pulling, and sorting photos from Apple Photos.
- An iOS app that syncs everything so you can access and edit on your phone.
- A system for annotating/sorting images and clipboard items to build future training data.
- A global “Pinterest/Pocket”-style curation and ingestion layer so you can pull curated images and content.

Below is a structured plan (goals, features, architecture, data model, privacy, integration details, phased roadmap, milestones, risks, and next steps) you can use to scope development.

1) High-level goals
- Make the SOl app a unified, cross-device asset manager for your imagery and clips: import from Apple Photos, clipboard, web & curated sources.
- Let you tag/annotate/organize assets so they can be used later as training data.
- Provide fast, reliable sync between macOS and iOS with offline-first UX and conflict resolution.
- Provide an inspiration feed (curated sources), easy saving/bookmarking, and a share/web-clipper workflow.

2) Core features (must-haves for MVP)
- Apple Photos import:
  - Use iOS/macOS `PhotoKit` to read `PHAsset` metadata and thumbnails; support limited-library privacy mode.
  - Present import UI showing asset previews with bulk-select, tag-on-import, and album mapping.
  - Support incremental sync (only new/changed assets).
- Local organization & metadata:
  - Tagging, hierarchical collections (projects/boards), freeform notes, ratings.
  - Annotations: freehand, bounding boxes, and label/semantic fields for training data.
  - Clipboard capture: detect images/text on the clipboard and create assets quickly via a “capture” workflow.
- Cross-device sync:
  - Cloud-backed sync (iCloud/CloudKit or custom backend). Sync metadata, annotations, derived thumbnails, and optionally image copies.
  - Resolve conflicts with last-writer-wins + manual merge UI for metadata conflicts.
- iOS app:
  - Native iOS app with the same organization metaphors (boards/collections/tags).
  - Share sheet and action extension for quick saving from Safari/other apps.
  - Offline support and background sync when on Wi‑Fi/power.
- Curated content ingestion & inspiration feed:
  - Integrations with curated content sources (Unsplash/Pexels/other image APIs; Pocket for articles; or RSS/curation sources).
  - Save-to-SOl flow with tagging and collection assignment.
- Training-data pipeline:
  - Export functionality that packages image(s) + metadata/annotations into labeled datasets (COCO/TFRecord/CSV).
  - Tagging schema and versioning for training labels.
  - Optional opt-in upload to training server or export to local disk.

3) Recommended architecture & tech choices
- Client apps:
  - iOS: Swift + SwiftUI (PhotoKit, CoreData, Combine).
  - macOS (if present): Swift + AppKit or SwiftUI.
- Local storage:
  - Core Data for metadata + CloudKit sync (Core Data + CloudKit) for iCloud users; alternatively use local DB + sync to custom backend.
  - Keep references to Apple Photos assets (local PHAsset identifiers) instead of duplicating full-resolution images unless user opts-in to upload copies.
  - Derivative images (thumbnails, medium-res cached) stored locally in app container.
- Sync options:
  - Option A (recommended for easiest cross‑device native sync): CloudKit with Core Data + CloudKit integration. Matches Apple Photos privacy expectations and avoids building own auth.
  - Option B (custom backend): REST API + object storage (S3-compatible) + Postgres. Allows multi-user sharing, team features, and server-side machine learning.
- Backend (if you need curated/global features, search across users, or central curation):
  - Node.js / Python backend, Postgres for metadata, object storage for full-res images, ElasticSearch for fast search.
  - Auth: Sign in with Apple / email (depending on need).
- ML/training pipeline:
  - Local export formatter for COCO/CSV/TFRecords.
  - Server-side training: use a dedicated pipeline (e.g., PyTorch, TF) on separate infra. Optionally integrate with a managed service.
- External APIs for curated content:
  - Unsplash, Pexels: image APIs for open curated images (check licensing).
  - Pocket API: saved web articles.
  - Pinterest API is restricted — evaluate feasibility and TOS; instead provide a browser extension/clipper.

4) Data model (conceptual)
- Asset:
  - id (UUID)
  - source (ApplePhotos | Curated | Clipboard | Uploaded)
  - sourceIdentifier (PHAsset.localIdentifier or source URL)
  - thumbnailPath, cachedMediumPath
  - originalURL (if hosted externally)
  - fileType, size, orientation, timestamp
- Metadata:
  - tags: [String]
  - collections: [collectionId]
  - notes: text
  - rating: int
  - annotations: array of {type, coords, label, confidence, userId}
  - trainingLabels: array (label, type, createdBy, createdAt)
- Collection/Board:
  - id, name, description, coverAsset
- Sync metadata:
  - lastModifiedAt, lastModifiedBy, version, deletedFlag
- CuratedSource:
  - id, name, apiInfo, licenseInfo

5) UX/Flows
- Import flow from Apple Photos:
  - Request permission (handle limited library scenario).
  - Show recent albums, smart suggestions, search by date/face/location.
  - Bulk import with ability to tag/assign collection on import.
- Quick-capture flows:
  - iOS share sheet + action extension.
  - Global “Clip” button to capture clipboard image/text into a new Asset draft.
- Annotation/editor:
  - Simple markup tools (crop, draw, bounding box).
  - Labeling UI for multi-class/multi-label tagging.
  - Keyboard shortcuts on macOS for speed.
- Inspiration feed & save:
  - Infinite scroll of curated images with filters and “save to collection” button.
  - Save should allow tagging and optionally downloading full-res (respecting license).
- Training export:
  - Select assets or collections -> Export as COCO/CSV with included images, annotations and a manifest file.

6) Privacy, permissions, and legal
- Apple Photos access requires `NSPhotoLibraryUsageDescription`; support limited-library mode (iOS 14+).
- Explicit opt-in before uploading any photo to your servers. Default: keep images referenced only locally using PHAsset IDs.
- Provide a clear privacy setting where users can toggle whether images are uploaded to the cloud or retained locally.
- Encrypt data in transit (HTTPS/TLS) and at rest (CloudKit is encrypted; for your backend use AES at rest).
- For training data: obtain explicit consent if using personal images for model training. Offer local-only training/export paths.
- Respect licensing for curated sources (store license metadata and show usage restrictions).

7) Sync & conflict resolution details
- Use an offline-first model: edits are stored locally, then synced.
- Use a per-asset version vector or timestamp; in conflict show user a diff for metadata (tags/notes/annotations).
- Keep PHAsset references for Apple Photos; if asset removed from Photos, mark as orphaned and optionally preserve cached copy if user chose that option.

8) Performance considerations
- Don’t import full-res images by default — use thumbnails/mediums and defer downloading full-res on explicit request.
- Use background sync and batching for uploads/downloads; enforce upload size limits and pause on mobile data unless user allows.
- Use lazy loading for the curated feed and search-as-you-type with server-side suggestions.

9) Curated content & web-clipping
- Provide a browser extension or iOS action extension to clip webpages, images, and text.
- Store clipped items with metadata (source URL, title, excerpt, favicon).
- Deduplicate by canonical URL and image hash.
- Allow auto-tagging recommendations using on-device ML or a server classifier.

10) Roadmap & milestones (example 3–6 month timeline)
Phase 0 — Discovery & architecture (1–2 weeks)
- Finalize tech choices (CloudKit vs custom backend), data schema, security guidelines.
- Build prototype UI wireframes for import, annotation, and curated feed.

Phase 1 — Core import + local editors (3–5 weeks)
- Implement Apple Photos integration (PhotoKit import, limited library handling).
- Local metadata store (Core Data) and simple UI for tagging/collections.
- Clipboard capture and share-sheet action.

Phase 3 — UX & Workflow (Completed v1.3)
- Vault root switching without reboot.
- Daily notes automatic creation.
- Slide-out terminal (Cmd+J).
- Global font scaling.
- Activity log unification.

Phase 4 — Intelligence Layer & Embedding (Next)
- Embed Claude Code / AI Agent directly into the app.
- Unified interface for accessing all captured content via AI.
- Context-aware chat sidebar.
- Integrated agent execution within the local context.

Phase 5 — Mobile & Curated Content
- Build iOS app with import, tag, annotate, and collections.
- Implement sync with CloudKit + Core Data.
- Add offline support and conflict resolution UI.
- Integrate Unsplash/Pexels or implement a web clipper; add curated feed UX.
- Add save-to-collection and licensing display.

Phase 5 — Polishing, performance, security, QA (2–4 weeks)
- Optimize caching, background sync, and thumbnails.
- Add tests, analytics, and monitoring.
- Prepare App Store privacy disclosures and docs.

11) Risks & mitigation
- Apple Photos privacy: some users will deny full access — support limited access and provide clear instructions.
- Licensing: curated APIs have license constraints — enforce license tracking and show restrictions.
- Large storage & bandwidth: default to thumbnails, give user control on full-res uploads, and allow selective sync.
- Scalability: if you move to a custom backend, design to allow later migration and horizontal scaling.

12) Metrics to track success
- Import rate (# photos imported per user/week).
- Daily/weekly active users on mobile.
- Number of annotations created (training data growth).
- Sync success rate and error rate.
- Curated saves / clipper usage per user.

13) Open questions I need from you
- Do you want to rely on iCloud/CloudKit for sync (Apple-only) or a cross-platform custom backend?
- Will training and curated features require central server-side aggregation of user data, or must all training data remain local until user explicitly exports?
- Do you plan to support multi-user sharing (teams/clients) and permissioned collections?
- Which curated sources do you want first (Unsplash, Pexels, Pocket, custom RSS)?

14) Next actionable steps I recommend
- Decide on sync strategy (CloudKit vs custom backend). I can draft a short comparison and recommended approach if you want.
- Create UI wireframes for the import & annotation flows (I can sketch flow steps).
- Prepare a minimal requirements doc for the MVP (I can produce one with the features above scoped to 1–2 months).

If you want, I’ll:
- produce a more detailed technical spec for either a CloudKit-based or backend-based sync implementation,
- or sketch the UX flows/wireframes for import, annotation, and curated feed.

Which of the two sync options do you prefer (CloudKit or custom backend), and do you want the initial focus on macOS, iOS, or both?

