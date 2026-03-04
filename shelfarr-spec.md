# Shelfarr

A self-hosted book request and acquisition system for audiobooks and ebooks, designed to integrate with Audiobookshelf.

## Overview

Shelfarr fills the gap in the *arr ecosystem for books. It combines the functionality of Jellyseerr (request UI) and Radarr/Sonarr (acquisition + processing) into a single application purpose-built for audiobooks and ebooks.

### The Problem

The video stack has a mature pipeline:
- **Jellyseerr** → request UI
- **Sonarr/Radarr** → indexer search, download orchestration, post-processing
- **Jellyfin** → library/playback

For books, only the library layer exists:
- **Audiobookshelf** → library/playback (supports both audiobooks and ebooks)

There is no unified request system, no acquisition orchestration, and no post-processing pipeline for books.

### The Solution

Shelfarr provides:
- User-facing request interface (family members can browse and request books)
- Metadata search via Open Library API
- Acquisition through Prowlarr (leveraging existing indexer configuration)
- Download management via qBittorrent (or other supported clients)
- Post-processing (rename, organize) and delivery to Audiobookshelf watch folders

## Tech Stack

| Component | Choice | Rationale |
|-----------|--------|-----------|
| Framework | Rails 8 | Convention over configuration, batteries included, single-developer friendly |
| Database | SQLite | Single-file, no separate container, trivial backup, sufficient for workload |
| Frontend | Hotwire (Turbo + Stimulus) | SPA-like interactivity without JS framework complexity |
| Background Jobs | Solid Queue (Rails 8 default) | Built-in, SQLite-backed, no Redis dependency |
| Deployment | Docker | Single container, one volume mount, matches Audiobookshelf simplicity |

## Architecture

### High-Level Flow

```
User searches → Open Library API → Results displayed
       ↓
User requests book → Book metadata cached locally
       ↓
Shelfarr searches → Prowlarr API → Indexer results
       ↓
Best match selected → Download client API → Download queued
       ↓
Download completes → Post-processing (rename/organize)
       ↓
File moved to → Audiobookshelf watch folder → Library updated
```

### Core Principles

1. **Monolith** — Single Rails app, no microservices
2. **Self-contained** — No external database, no Redis, no Elasticsearch
3. **Lazy metadata** — No pre-built index; cache metadata on first request
4. **Leverage existing infrastructure** — Use Prowlarr for indexers, existing download client
5. **Simple deployment** — One Docker image, one volume, done

## Data Models

### Book

Cached metadata for requested books. Open Library distinguishes "works" (the abstract book) from "editions" (specific printings). We store both IDs to enable duplicate detection at the work level while allowing requests for specific editions.

```ruby
# db/schema.rb (conceptual)
create_table :books do |t|
  t.string :title, null: false
  t.string :author
  t.text :description
  t.string :cover_url
  t.string :isbn
  t.string :open_library_work_id    # e.g., "/works/OL45883W" - the abstract work
  t.string :open_library_edition_id # e.g., "/books/OL7353617M" - specific edition
  t.integer :book_type, default: 0  # enum: audiobook, ebook
  t.integer :year
  t.string :publisher
  t.string :language, default: "en"
  t.string :file_path              # populated once acquired, enables download button
  
  t.timestamps
end

add_index :books, :isbn
add_index :books, :open_library_work_id
add_index :books, :open_library_edition_id
```

**Enum:**
```ruby
enum :book_type, { audiobook: 0, ebook: 1 }
```

**Duplicate detection logic:**
- Before creating a request, check if a Book with the same `open_library_edition_id` exists and has a `file_path` (already acquired)
- Warn user if same `open_library_work_id` exists in a different edition, but allow request if they want that specific edition

### User

Family members who can request books.

```ruby
create_table :users do |t|
  t.string :name, null: false
  t.string :email, null: false
  t.string :password_digest, null: false
  t.integer :role, default: 0  # enum: user, admin
  
  t.timestamps
end

add_index :users, :email, unique: true
```

**Enum:**
```ruby
enum :role, { user: 0, admin: 1 }
```

### Request

A user's request for a book. Requests are processed via a background queue with retry logic.

```ruby
create_table :requests do |t|
  t.references :book, null: false, foreign_key: true
  t.references :user, null: false, foreign_key: true
  t.integer :status, default: 0
  t.text :notes              # user can add context to request
  t.integer :retry_count, default: 0
  t.datetime :next_retry_at
  t.datetime :completed_at
  t.boolean :attention_needed, default: false  # flagged for admin review
  t.text :issue_description  # why it needs attention
  
  t.timestamps
end

add_index :requests, :status
add_index :requests, :next_retry_at
add_index :requests, :attention_needed
```

**Enum:**
```ruby
enum :status, {
  pending: 0,      # in queue, waiting to be searched
  searching: 1,    # actively searching indexers
  not_found: 2,    # no results, will retry later (back of queue)
  downloading: 3,  # sent to download client
  processing: 4,   # download complete, post-processing
  completed: 5,    # delivered to Audiobookshelf
  failed: 6        # permanent failure (e.g., download client error)
}
```

**Queue behavior:**
- `pending` requests are processed in FIFO order
- `not_found` requests set `next_retry_at` to a future time (e.g., +24 hours) and increment `retry_count`
- Background job picks up requests where `next_retry_at < now` and retries
- After `max_retries` (configurable), sets `attention_needed: true` with description, stops auto-retrying

**Attention triggers:**
- Exceeded max retries (book not available on indexers)
- Download failed repeatedly
- Post-processing error (file format issues, etc.)
- Download client unreachable

### Download

Tracks active downloads.

```ruby
create_table :downloads do |t|
  t.references :request, null: false, foreign_key: true
  t.string :download_client_id  # ID/hash from qBittorrent
  t.string :name                # torrent/nzb name
  t.integer :status, default: 0
  t.integer :progress, default: 0  # 0-100
  t.bigint :size_bytes
  t.string :download_path
  
  t.timestamps
end
```

**Enum:**
```ruby
enum :status, {
  queued: 0,
  downloading: 1,
  paused: 2,
  completed: 3,
  failed: 4
}
```

### Setting

Application configuration (key-value with typed values).

```ruby
create_table :settings do |t|
  t.string :key, null: false
  t.text :value
  t.string :value_type, default: "string"  # string, integer, boolean, json
  
  t.timestamps
end

add_index :settings, :key, unique: true
```

**Expected settings:**
- `prowlarr_url` — Base URL for Prowlarr instance
- `prowlarr_api_key` — API key for Prowlarr
- `download_client_type` — qbittorrent, transmission, deluge, sabnzbd
- `download_client_url` — Base URL for download client
- `download_client_username` — Optional auth
- `download_client_password` — Optional auth
- `audiobook_output_path` — Where to place completed audiobooks
- `ebook_output_path` — Where to place completed ebooks
- `queue_batch_size` — How many requests to process per queue run
- `rate_limit_delay` — Seconds between API calls
- `max_retries` — How many times to retry not_found before giving up

### Upload

Tracks manual file uploads.

```ruby
create_table :uploads do |t|
  t.references :user, null: false, foreign_key: true
  t.references :book, foreign_key: true  # populated after processing
  t.integer :status, default: 0
  t.string :original_filename
  t.string :file_path  # temporary storage before processing
  
  t.timestamps
end
```

**Enum:**
```ruby
enum :status, {
  pending: 0,
  processing: 1,
  completed: 2,
  failed: 3
}
```

### SystemHealth

Tracks integration status for the Issues page and dashboard alerts.

```ruby
create_table :system_health do |t|
  t.string :service, null: false  # prowlarr, download_client, audiobookshelf
  t.integer :status, default: 0
  t.text :message
  t.datetime :last_check_at
  t.datetime :last_success_at
  
  t.timestamps
end

add_index :system_health, :service, unique: true
```

**Enum:**
```ruby
enum :status, {
  healthy: 0,
  degraded: 1,  # slow responses, partial failures
  down: 2
}
```

**Health checks run periodically:**
- Prowlarr: ping API, verify indexers responding
- Download client: ping API, check connection
- Audiobookshelf: verify output folder is writable (API check optional)

**Surfaced on:**
- Dashboard (status indicators)
- Issues page (if any service is degraded/down)

## External Integrations

### Open Library API

**Purpose:** Metadata search and retrieval

**Endpoints used:**
- Search: `https://openlibrary.org/search.json?q={query}`
- Book details: `https://openlibrary.org/works/{id}.json`
- Cover images: `https://covers.openlibrary.org/b/id/{cover_id}-{size}.jpg`

**Rate limits:** Informal, be respectful. Cache aggressively.

**Implementation notes:**
- Create `OpenLibraryClient` service class
- Search returns basic info; fetch full details on request
- Store `open_library_id` to avoid repeat lookups
- Cache cover URLs, not images themselves

### Prowlarr API

**Purpose:** Search configured indexers for book releases

**Base URL:** User-configured (e.g., `http://localhost:9696`)

**Key endpoints:**
- Search: `GET /api/v1/search?query={query}&type=book`
- Indexers: `GET /api/v1/indexer` (to show user which indexers are available)

**Headers:**
```
X-Api-Key: {prowlarr_api_key}
```

**Implementation notes:**
- Create `ProwlarrClient` service class
- Handle connection errors gracefully (Prowlarr might be down)
- Parse results to extract: title, indexer, size, seeders, download URL
- Allow user to select which result to download (or auto-select best)

### Download Client API (qBittorrent)

**Purpose:** Add downloads, monitor progress, detect completion

**Base URL:** User-configured (e.g., `http://localhost:8080`)

**Key endpoints:**
- Login: `POST /api/v2/auth/login`
- Add torrent: `POST /api/v2/torrents/add`
- List torrents: `GET /api/v2/torrents/info`
- Torrent details: `GET /api/v2/torrents/properties?hash={hash}`

**Implementation notes:**
- Create `DownloadClientClient` base class with qBittorrent implementation
- Abstract interface allows adding Transmission, Deluge, SABnzbd later
- Poll for status updates via background job
- Detect completion by checking progress = 100 and state

### Audiobookshelf Integration

**Purpose:** Deliver processed files to library

**Method:** Folder watching (no direct API integration needed initially)

**Implementation:**
- After post-processing, move files to configured output path
- Audiobookshelf's folder watcher picks them up automatically
- Future enhancement: use Audiobookshelf API to trigger scan or notify user

**Audiobookshelf API (future):**
- Base URL: User-configured
- Libraries: `GET /api/libraries`
- Trigger scan: `POST /api/libraries/{id}/scan`
- Requires API token from Audiobookshelf settings

## Background Jobs

Using Solid Queue (Rails 8 default).

### RequestQueueJob

Recurring job that processes the request queue with rate limiting.

```ruby
class RequestQueueJob < ApplicationJob
  def perform
    # Process pending requests (FIFO)
    Request.pending.order(:created_at).limit(batch_size).each do |request|
      SearchJob.perform_later(request.id)
      sleep rate_limit_delay  # Respect API rate limits
    end
    
    # Retry not_found requests that are due
    Request.not_found.where("next_retry_at <= ?", Time.current).each do |request|
      request.update!(status: :pending)  # Re-queue for search
    end
    
    # Re-enqueue self
    RequestQueueJob.set(wait: 5.minutes).perform_later
  end
  
  private
  
  def batch_size
    Setting.get(:queue_batch_size, default: 5)
  end
  
  def rate_limit_delay
    Setting.get(:rate_limit_delay, default: 2)  # seconds
  end
end
```

### SearchJob

Triggered when a request moves to the front of the queue.

```ruby
class SearchJob < ApplicationJob
  def perform(request_id)
    request = Request.find(request_id)
    request.update!(status: :searching)
    
    results = ProwlarrClient.search(request.book.title, request.book.author)
    
    if results.empty?
      # Move to back of queue for retry
      retry_delay = [24.hours * (request.retry_count + 1), 7.days].min
      request.update!(
        status: :not_found,
        retry_count: request.retry_count + 1,
        next_retry_at: Time.current + retry_delay
      )
    else
      # Store results for user selection, or auto-download best match
      # based on settings
    end
  end
end
```

### DownloadMonitorJob

Recurring job that checks download progress.

```ruby
class DownloadMonitorJob < ApplicationJob
  def perform
    Download.where(status: [:queued, :downloading]).find_each do |download|
      status = DownloadClient.status(download.download_client_id)
      download.update!(progress: status.progress, status: status.state)
      
      if status.completed?
        PostProcessJob.perform_later(download.id)
      end
    end
    
    # Re-enqueue self
    DownloadMonitorJob.set(wait: 30.seconds).perform_later
  end
end
```

### PostProcessJob

Handles renaming and moving completed downloads.

```ruby
class PostProcessJob < ApplicationJob
  def perform(download_id)
    download = Download.find(download_id)
    request = download.request
    request.update!(status: :processing)
    
    # Rename files according to naming convention
    # Move to appropriate output folder
    # Update book.file_path for ebook download button
    
    request.book.update!(file_path: final_path)
    request.update!(status: :completed, completed_at: Time.current)
  end
end
```

### ManualUploadJob

Processes manually uploaded files.

```ruby
class ManualUploadJob < ApplicationJob
  def perform(upload_id)
    upload = Upload.find(upload_id)
    
    # Detect book type from file extension
    book_type = detect_book_type(upload.file)
    
    # Extract metadata from filename or embedded data
    extracted = extract_metadata(upload.file)
    
    # Enrich from Open Library if ISBN found or title/author match
    enriched = OpenLibraryClient.enrich(extracted)
    
    # Create or find Book record
    book = Book.find_or_create_by(open_library_edition_id: enriched[:edition_id]) do |b|
      b.assign_attributes(enriched)
    end
    
    # Process and move file
    final_path = process_and_move(upload.file, book)
    book.update!(file_path: final_path)
    
    upload.update!(status: :completed, book: book)
  end
end
```

### HealthCheckJob

Monitors integration health.

```ruby
class HealthCheckJob < ApplicationJob
  def perform
    check_prowlarr
    check_download_client
    check_output_paths
    
    # Re-enqueue
    HealthCheckJob.set(wait: 5.minutes).perform_later
  end
  
  private
  
  def check_prowlarr
    health = SystemHealth.find_or_create_by(service: "prowlarr")
    
    begin
      response = ProwlarrClient.ping
      health.update!(
        status: :healthy,
        message: nil,
        last_check_at: Time.current,
        last_success_at: Time.current
      )
    rescue => e
      health.update!(
        status: :down,
        message: e.message,
        last_check_at: Time.current
      )
      flag_affected_requests("Prowlarr unreachable: #{e.message}")
    end
  end
  
  def check_download_client
    # Similar pattern
  end
  
  def check_output_paths
    # Verify audiobook/ebook output paths are writable
  end
  
  def flag_affected_requests(message)
    # Mark in-progress requests as attention_needed if integration is down
  end
end
```

## User Interface

### Pages

1. **Dashboard** — Overview of pending requests, active downloads, recent completions, system health indicators, issues count badge
2. **Search** — Search Open Library, display results, request button
3. **Requests** — List user's own requests with status, filter by status (admin sees all)
4. **Request Detail** — Show book info, indexer results, download progress
5. **Library** — Browse cached books (already acquired), download button for ebooks
6. **Upload** — Manual file upload form, metadata enrichment preview
7. **Issues** (admin) — Queue of items needing attention with actions to resolve
8. **Settings** — Configure integrations, paths, preferences
9. **Users** (admin) — Manage family member accounts

### Issues Page (Admin)

Central place for handling problems, similar to Radarr/Sonarr's activity queue.

**Displays items where:**
- `attention_needed: true`
- `status: failed`
- Download stuck (downloading for > X hours)
- Integration errors (Prowlarr/download client unreachable)

**Per-item actions:**
- **Retry now** — Clear flags, reset retry count, move to front of queue
- **Manual search** — Open Prowlarr search results, let admin pick a release
- **Upload file** — Admin provides the file manually
- **Delete request** — Remove from queue entirely (with optional user notification)
- **Mark resolved** — Clear attention flag without other action

**Bulk actions:**
- Retry all
- Delete all failed
- Pause/resume queue processing

### UI Framework

- **Hotwire/Turbo** for navigation and updates without full page reloads
- **Stimulus** for interactive components (search autocomplete, progress bars)
- **Tailwind CSS** for styling (or keep it simple with classless CSS like Pico)

### Key Interactions

**Search flow:**
1. User types in search box
2. Debounced request to server
3. Server queries Open Library
4. Results stream back via Turbo Stream
5. User clicks "Request" button
6. Book metadata cached, request created
7. Turbo navigates to request detail page

**Download progress:**
1. Request detail page shows download card
2. Turbo Stream updates progress bar every few seconds
3. Status badge updates as states change
4. Notification when complete

## File Organization

### Naming Convention

**Audiobooks:**
```
{Author}/{Title}/{Title}.m4b
# or for multi-file
{Author}/{Title}/{Title} - Part 01.mp3
```

**Ebooks:**
```
{Author}/{Title}.epub
{Author}/{Title}.pdf
```

### Post-Processing Steps

1. Identify files in completed download
2. Detect book type (audiobook vs ebook) by extension
3. Extract/confirm metadata (from filename or embedded)
4. Rename according to convention
5. Move to output directory
6. Clean up source files
7. Update request status

## Deployment

### Docker

```dockerfile
FROM ruby:3.3-slim

WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libsqlite3-dev \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application
COPY . .

# Precompile assets
RUN bundle exec rails assets:precompile

# Setup database
RUN bundle exec rails db:setup

EXPOSE 3000

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
```

### Docker Compose

```yaml
version: "3.8"
services:
  shelfarr:
    image: shelfarr:latest
    container_name: shelfarr
    ports:
      - "3000:3000"
    volumes:
      - ./data:/app/storage  # SQLite DB, uploads
      - /path/to/audiobooks:/audiobooks  # Output for Audiobookshelf
      - /path/to/ebooks:/ebooks  # Output for ebook reader
    environment:
      - RAILS_ENV=production
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
    restart: unless-stopped
```

### Volume Mounts

| Mount | Purpose |
|-------|---------|
| `/app/storage` | SQLite database, Active Storage files |
| `/audiobooks` | Output directory for processed audiobooks |
| `/ebooks` | Output directory for processed ebooks |

### Environment Variables

| Variable | Purpose |
|----------|---------|
| `SECRET_KEY_BASE` | Rails secret key (generate with `rails secret`) |
| `RAILS_ENV` | Environment (production) |

## Development Roadmap

### Phase 1: Foundation
- [ ] Rails 8 project setup with SQLite
- [ ] User authentication (Devise or custom)
- [ ] Basic models and migrations
- [ ] Settings management UI
- [ ] Docker configuration

### Phase 2: Metadata
- [ ] Open Library client
- [ ] Search interface
- [ ] Book metadata caching
- [ ] Cover image display
- [ ] Duplicate detection (work vs edition)

### Phase 3: Requests
- [ ] Request creation flow
- [ ] Request listing and filtering
- [ ] Request detail page
- [ ] User notifications (in-app)
- [ ] Request queue with retry logic

### Phase 4: Acquisition
- [ ] Prowlarr client
- [ ] Indexer search results display
- [ ] Result selection UI
- [ ] qBittorrent client
- [ ] Download initiation

### Phase 5: Processing
- [ ] Download monitoring job
- [ ] Progress tracking UI
- [ ] Post-processing logic
- [ ] File renaming and organization
- [ ] Output directory delivery
- [ ] Ebook download button in library

### Phase 6: Admin & Health
- [ ] Issues page with attention queue
- [ ] System health monitoring
- [ ] Health check job
- [ ] Bulk actions (retry all, delete failed)
- [ ] Manual search override
- [ ] Manual file upload for problematic requests

### Phase 7: Polish
- [ ] Dashboard with statistics and health indicators
- [ ] Activity feed
- [ ] Mobile-responsive design
- [ ] Error handling and retry logic
- [ ] Documentation

### Phase 8: Ecosystem
- [ ] Additional download clients (Transmission, SABnzbd)
- [ ] Audiobookshelf API integration (trigger scan)
- [ ] Notifications (email, webhook)
- [ ] Open source release

## Design Decisions

1. **Ebook reader integration** — No Calibre/e-reader integration for now. Ebooks go to Audiobookshelf, but the UI provides a direct download button so users can manually transfer to their e-readers (Kindle, Kobo, etc.).

2. **Multi-user permissions** — Users see only their own requests. Admins see all requests across all users. Simple privacy model for family use.

3. **Manual upload** — Supported. User uploads a file, Shelfarr extracts/enriches metadata from Open Library, processes and delivers to the appropriate output folder. Useful for books acquired outside the normal flow.

4. **Request queue** — No wishlist concept. All requests are active and processed via a background queue. The queue respects rate limits for external APIs. Books not found on first search are moved to the back of the queue for retry later (not marked as failed immediately).

5. **Duplicate handling** — Cannot request a book already in the library. Translations are considered different books (different ISBN). Different editions/versions of the same work (hardcover, paperback, different publishers, different years) need handling—likely group by Open Library "work" ID while tracking individual "edition" IDs. User can request a specific edition if desired.

## References

- [Rails 8 Release Notes](https://rubyonrails.org/)
- [Hotwire Documentation](https://hotwired.dev/)
- [Open Library API](https://openlibrary.org/developers/api)
- [Prowlarr API](https://wiki.servarr.com/prowlarr)
- [qBittorrent WebUI API](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1))
- [Audiobookshelf API](https://api.audiobookshelf.org/)
