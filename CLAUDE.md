# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Shelfarr is a self-hosted audiobook request and management system for the *arr ecosystem. It's a Ruby on Rails 8.1 application that combines Jellyseerr-style request UI with Radarr-style acquisition and processing for audiobooks. Integrates with Audiobookshelf for library management.

**Stack:** Rails 8.1, SQLite, Hotwire (Turbo + Stimulus), Tailwind CSS, Solid Queue (background jobs), Puma

## Development Commands

```bash
# Setup
bundle install
bin/rails db:setup

# Development server (starts web + CSS watcher)
bin/dev

# Database
bin/rails db:migrate
bin/rails db:reset        # Dev only - resets database

# Testing
bin/rails test            # Unit/integration tests
bin/rails test:system     # System tests with browser

# Linting & Security
bin/rubocop               # Code style (Rails Omakase preset)
bin/brakeman              # Security vulnerabilities
bin/bundler-audit         # Gem vulnerabilities
```

## Architecture

### Data Flow
```
User Search → Audible/Audnexus API → Results with Covers/Narrator/Duration
      ↓
User Requests Book → Book Metadata Stored
      ↓
Shelfarr Searches → Prowlarr API → Search Results
      ↓
Auto/Manual Selection → Download Client (qBittorrent/SABnzbd/etc)
      ↓
Download Completes → PostProcessingJob → File Organization
      ↓
File Moved to Output Path → Audiobookshelf Library Sync (Optional)
```

### Key Directories

- `app/services/` - Business logic abstraction layer. External API clients (ProwlarrClient, AudnexusClient, etc.) and processing services live here.
- `app/jobs/` - Solid Queue background jobs. Key jobs: RequestQueueJob (orchestrator), SearchJob, DownloadJob, PostProcessingJob, DownloadMonitorJob.
- `app/controllers/admin/` - Admin-only functionality (user management, settings, download clients, bulk operations).

### Core Models

- **Book** - Metadata cache from Audible/Audnexus (ASIN, narrator, duration, cover, series)
- **Request** - User book requests with status machine: pending → searching → downloading → processing → completed/failed/not_found
- **Download** - Tracks active downloads with external_id linking to download client
- **SearchResult** - Prowlarr/Anna's Archive results with confidence scoring
- **DownloadClient** - Multiple client configurations with priority ordering

### Service Layer Patterns

Download clients follow an adapter pattern in `app/services/download_clients/`:
- QBittorrent, SABnzbd, Deluge, Transmission, NZBGet implementations
- `DownloadClientSelector` chooses client by type and priority

Metadata services:
- `MetadataService` provides audiobook search via Audible catalog + Audnexus enrichment (same pipeline as Audiobookshelf)
- `AudnexusClient` handles Audible search and Audnexus API calls (narrator, cover, duration, series)
- `MetadataExtractorService` extracts from uploaded files

### Background Jobs

Jobs run in-process via `SOLID_QUEUE_IN_PUMA=true` (no separate worker needed).

- `RequestQueueJob` - Main orchestrator, requeues retry-due requests, processes pending in batches
- `SearchJob` - Searches Prowlarr, creates SearchResults
- `DownloadJob` - Sends to download client or handles direct HTTP downloads
- `PostProcessingJob` - Renames/organizes files after download
- `DownloadMonitorJob` - Polls download clients for completion status

### Authentication

- Password auth with bcrypt
- TOTP-based 2FA with backup codes
- OIDC/SSO support (OmniAuth OpenID Connect)
- First user to register becomes admin
- Account lockout after failed attempts

## External Integrations

| Service | Purpose | Client Location |
|---------|---------|-----------------|
| Audible/Audnexus | Audiobook metadata (covers, narrator, duration) | `app/services/audnexus_client.rb` |
| Prowlarr | Indexer search | `app/services/prowlarr_client.rb` |
| Anna's Archive | Direct ebook downloads | `app/services/anna_archive_client.rb` |
| Audiobookshelf | Library sync | `app/services/audiobookshelf_client.rb` |
| Download Clients | Torrent/Usenet | `app/services/download_clients/*.rb` |

## Docker

```bash
docker build -t shelfarr .
docker-compose up -d
```

Key environment variables:
- `RAILS_MASTER_KEY` - Auto-generated on first run
- `RAILS_RELATIVE_URL_ROOT` - For sub-path hosting (e.g., `/shelfarr`)
- `PUID`/`PGID` - File permissions
- `HTTP_PORT` - Internal port (default: 80)
