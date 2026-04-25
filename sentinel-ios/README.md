# Sentinel iOS

Sentinel is an AI-assisted personal scheduling app for iPhone.

This repository contains the iOS client. The app turns free-form chat requests into structured event suggestions, lets the user review them, and then saves accepted events into Apple Calendar through EventKit.

## Core flow

1. User opens Chat
2. Sends a natural-language scheduling request
3. Backend returns assistant text and event proposals
4. User reviews and selectively accepts proposals
5. Accepted events are synchronized into the `Sentinel` calendar

## Current product surfaces

- Home / Today
- Chat with history
- Event proposal review and apply
- Calendar synchronization
- Profile
- Achievements

## iOS stack

- Swift 6
- SwiftUI
- TCA
- SwiftData
- EventKit
- Keychain-backed session storage

## Project structure

- `Sentinel/Sentinel/` — application source
- `Sentinel/Sentinel/Features/` — feature modules
- `Sentinel/Sentinel/Clients/` — API and platform clients
- `Sentinel/Sentinel/Models/` — transport and domain models

## Notes

- The app uses a dedicated calendar named `Sentinel` for synchronized events.
- Backend contracts are English-centric at payload level even when user-facing copy changes.
- Product and API reference docs live under `docs/sentinel/`.
