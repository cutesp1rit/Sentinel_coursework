# Sentinel Normalized Product And iOS Brief

## Product identity

Sentinel is an iOS AI-assisted personal scheduling app that converts free-form chat requests and optional attachments into structured calendar events. The app supports local calendar integration through EventKit and uses a backend service for chat orchestration, storage, auth, and achievements.

## Core user flow

1. The user opens Chat and sends a natural-language request.
2. The user may attach:
   - text only
   - photos
   - image files from the Files picker
3. The backend and LLM return one or more event suggestions.
4. The user can select multiple suggestions.
5. The user adds selected items into the calendar.
6. The app reflects events in Today and Calendar surfaces.

This chat-to-suggestions-to-calendar flow is the highest-priority product flow and should remain stable across feature work.

## Required screens and features

### 1. Chat
- send text messages
- attach photos from gallery or camera
- attach image files through a system picker
- show network and processing errors with Retry
- receive assistant-generated event suggestions
- allow multi-select of suggested events
- add selected suggestions into the calendar

### 2. Today
- show the current day event list
- show Resource Battery
- provide a Create Event entry point to Chat
- support quick add from chat suggestions
- support launching Rebalance
- show achievement progress

### 3. Calendar
- provide week and month views
- synchronize with Apple Calendar through EventKit
- allow event creation

### 4. Settings
- show auth status and entry to authorization flow
- support logout
- delete account with confirmation
- edit and save a default prompt template appended to assistant requests
- expose legal documents from the website
- navigate to Achievements

### 5. Achievements
- show earned achievements
- show available achievements
- support sharing an achievement via Share Sheet

## Input constraints

### Chat message inputs
- text up to 2000 UTF-8 characters
- photos and imported image files: PNG, JPG, JPEG, HEIC; up to 10 MB each; up to 5 per message

### Input validation expectations
- validate length and allowed characters
- validate attachment type, count, and size
- require user consent for server-side processing of text and attachments

## Output expectations

### Internal entities relevant to iOS
- user
- chat
- chat message
- event
- achievement

### External artifacts
- iOS calendar events with title, notes, reminders, and calendar identifier
- server responses as JSON
- reminder behavior through the device calendar only

### Data integrity
- avoid duplicate event export into the calendar
- visually indicate scheduling conflicts

## UX and performance constraints

- UI response <= 150 ms
- screen transitions <= 300 ms
- server interpretation target 3-6 s, timeout 15 s
- calendar event creation <= 500 ms
- no background operations required in v1; incomplete operations may be retried manually after app return

## UI and accessibility requirements

- follow Apple Human Interface Guidelines
- support light and dark mode
- support Dynamic Type
- minimum interactive element size 44x44 pt
- support VoiceOver and proper accessibility labels
- maintain contrast at least WCAG 2.1 AA
- show progress during network work
- show a clear textual error plus Retry action

## Persistence and platform requirements

- SwiftData for local storage with schema versioning and migrations
- HTTPS and JSON UTF-8 for client-server communication
- ISO-8601 with time zone handling
- Keychain for tokens and secrets
- EventKit for calendar sync
- external event UUID should be stored in EKEvent.url and-or notes for deduplication when adding or updating

## Architecture and code constraints

- Swift 6
- SwiftUI
- TCA with unidirectional data flow
- modular project structure
- Swift API Design Guidelines
- SPM for dependencies
- avoid dynamic code loading

## Security and privacy requirements

- HTTPS only, TLS 1.2+
- ATS enabled; arbitrary loads disabled
- no certificate pinning in v1
- minimize stored personal data
- exclude sensitive information from logs

## Product differentiators to preserve

- generation of multiple events from one chat request with preview before add
- Resource Battery guidance
- Rebalance scheduling support
- native Apple Calendar integration without external calendar cloud abstraction
- achievements and gamification

## Known design reality

Final design is incomplete.
When implementing before final design:
- lock in correct states, actions, and architecture first
- keep layout and ornamentation reversible
- do not hard-code cosmetic details that are likely to change
