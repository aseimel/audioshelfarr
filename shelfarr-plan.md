# Shelfarr

A book and audiobook management system inspired by Jellyseerr's user experience, designed to organize content for consumption in Audiobookshelf.

## Vision

Shelfarr fills a gap in the *arr ecosystem for books and audiobooks. Readarr exists but is notoriously difficult to use, especially for audiobooks. Shelfarr takes a different approach: treating the "Work" as the core entity, with multiple versions (formats, languages, narrators) underneath it.

The goal is a Jellyseerr-like experience for discovering, requesting, acquiring, and organizing books—then outputting clean folder structures that Audiobookshelf can ingest without metadata headaches.

## Core Concepts

### Data Model

```
Work
├── title (canonical)
├── author(s)
├── series (optional)
├── series_position (optional)
├── description
├── openLibraryId
├── subjects/genres
├── cover_url
└── versions[]

Version
├── work_id (FK)
├── format (ebook | audiobook)
├── language
├── narrator (audiobooks only)
├── publisher
├── publish_date
├── isbn / asin
├── duration (audiobooks)
├── page_count (ebooks)
├── source (prowlarr | manual_upload | owned)
├── status (wanted | downloading | available)
└── files[]

File
├── version_id (FK)
├── path (relative to library root)
├── filename
├── size_bytes
├── format (mp3 | m4b | epub | pdf | mobi | etc)
└── added_date
```

### Key Principle: Work as Truth

A Work represents the abstract creative entity. "The Iron Druid Chronicles: Hounded" is one Work, regardless of whether you have:
- English audiobook narrated by Luke Daniels
- German audiobook
- English epub
- Portuguese PDF

This solves the metadata chaos problem: you search for and browse Works, and see all your versions at a glance.

## User Flows

### Discovery

1. User searches Shelfarr (queries OpenLibrary API)
2. Results show Works with cover, author, series info
3. User can browse by author, series, or subject
4. Each Work shows:
   - Existing versions in library (if any)
   - Available versions for download (from Prowlarr)
   - Status indicators (owned, wanted, downloading)

### Request/Acquisition

1. User selects a Work they want
2. Shelfarr queries Prowlarr for available releases
3. User selects preferred version(s): format, language, narrator
4. Shelfarr sends to download client (qBittorrent or SABnzbd)
5. On completion, Shelfarr:
   - Moves files to library location
   - Organizes into correct folder structure
   - Updates Version status to "available"
   - Optionally triggers Audiobookshelf scan or API push

### Manual Upload

1. User uploads files through web UI
2. Shelfarr attempts to match against OpenLibrary:
   - Filename parsing
   - Embedded metadata extraction (ID3 for audio, epub metadata)
   - User confirmation/correction for ambiguous matches
3. User assigns to existing Work or creates new
4. User specifies Version details (format, language, narrator)
5. Files organized and moved to library

### Library Organization

Output folder structure for Audiobookshelf compatibility:

```
/audiobooks
  /Author Name
    /Series Name (if applicable)
      /Book Title
        /files...
    /Standalone Title (non-series)
      /files...

/ebooks
  /Author Name
    /Title.epub
```

Audiobookshelf expects this hierarchy. Shelfarr handles the organization so you never manually shuffle files.

## Integrations

### OpenLibrary (Discovery & Metadata)

- Search API: `https://openlibrary.org/search.json`
- Works API: `https://openlibrary.org/works/{id}.json`
- Authors API: `https://openlibrary.org/authors/{id}.json`
- Covers: `https://covers.openlibrary.org/b/id/{id}-L.jpg`

OpenLibrary is free, open, and has decent coverage. Its data model (Works vs Editions) aligns with Shelfarr's philosophy.

Fallback/supplement: Google Books API, Audible scraping for audiobook-specific metadata (narrator, duration).

### Prowlarr (Indexer Aggregation)

Standard *arr integration pattern:
- API endpoint configuration
- Search by title, author, ISBN
- Parse results for quality, format, language
- Send releases to download client

### Download Clients

Support both:
- **qBittorrent**: WebUI API for adding torrents, monitoring progress
- **SABnzbd**: API for NZB handling

On download completion, Shelfarr needs to:
1. Detect completion (poll or webhook)
2. Identify which request the download fulfills
3. Process/rename/move files
4. Update internal state

### Audiobookshelf (Optional Push)

Audiobookshelf has an API. Instead of just dropping files in a watched folder, Shelfarr could:
- Trigger library scans
- Push metadata directly
- Check for existing items to avoid duplicates

This is a nice-to-have for v1; folder-based import works fine initially.

## Technical Approach

### Stack Recommendation

- **Backend**: Go or TypeScript (Node)
  - Go: single binary, efficient, good for long-running service
  - TypeScript: faster iteration, more libraries for metadata parsing
- **Database**: SQLite (simple deployment) or PostgreSQL (if scaling matters)
- **Frontend**: React with a clean, Jellyseerr-inspired UI
- **Deployment**: Docker container, single image

Given this is a homelab tool, SQLite + single Docker container is probably ideal. Keep it simple.

### API Design

RESTful API, resources:

```
GET    /api/works                    # List works in library
GET    /api/works/:id                # Single work with versions
POST   /api/works                    # Create work (manual)
PUT    /api/works/:id                # Update work metadata

GET    /api/works/:id/versions       # List versions
POST   /api/works/:id/versions       # Add version
PUT    /api/versions/:id             # Update version
DELETE /api/versions/:id             # Remove version

GET    /api/search?q=               # Search OpenLibrary
GET    /api/search/prowlarr?q=      # Search available downloads

POST   /api/requests                 # Request a download
GET    /api/requests                 # List pending/active requests
DELETE /api/requests/:id             # Cancel request

POST   /api/upload                   # Upload files
GET    /api/upload/:id/match         # Get match suggestions for upload

GET    /api/settings                 # Configuration
PUT    /api/settings                 # Update configuration
```

### Configuration

User-configurable:
- Library paths (audiobooks, ebooks)
- Prowlarr connection (URL, API key)
- Download client connection(s)
- Audiobookshelf connection (optional)
- Folder structure templates
- Preferred languages (for sorting results)

## MVP Scope (v1)

Focus on the core loop:

1. **Search OpenLibrary** for books
2. **View library** of existing Works/Versions
3. **Search Prowlarr** for available downloads
4. **Send to download client**
5. **Process completed downloads** into correct folder structure
6. **Manual upload** with metadata matching

Out of scope for v1:
- Audiobookshelf API push (use folder watching)
- Multiple users/permissions
- Notifications
- Automated requests (wishlists)
- Mobile app

## UI Sketch

### Main Views

**Home/Dashboard**
- Recently added
- In progress downloads
- Quick search bar

**Search**
- Results from OpenLibrary
- Each result shows: cover, title, author, series
- Click to see details + available versions

**Library**
- Grid or list of Works
- Filter by: author, series, format, status
- Click Work to see all Versions

**Work Detail**
- Cover, metadata
- List of Versions (format, language, status)
- Actions: Request more versions, upload files

**Downloads**
- Active downloads with progress
- History of completed

**Settings**
- Connection configs
- Library paths
- Preferences

## Open Questions

1. **Metadata sources for audiobooks**: OpenLibrary is weak on audiobook-specific data (narrator, runtime). May need to supplement with Audible scraping or manual entry.

2. **Multi-file audiobooks**: Some audiobooks are single m4b, others are dozens of mp3s. Need consistent handling and folder structure for both.

3. **Ebook handling**: Integrate with Calibre for ebook management, or keep it simple and just organize folders?

4. **Duplicate detection**: How to identify if an uploaded/downloaded file is a different version of something already in library vs a true duplicate?

5. **Series handling**: Series info from OpenLibrary can be inconsistent. May need manual curation for series ordering.

## Success Criteria

Shelfarr is successful when:
- You can go from "I want this book" to "it's in Audiobookshelf, properly organized" in under a minute
- Your existing library can be uploaded and automatically matched/organized
- You never have to manually create folder structures or rename files
- The Iron Druid Chronicles import works cleanly on first try
