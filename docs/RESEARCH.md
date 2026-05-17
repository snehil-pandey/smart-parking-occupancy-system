# Research

## Problem

Parking is usually not a single missing-space problem. It is an information problem. Drivers do not know which nearby parking area has space, how much it costs, whether it supports their vehicle, or how long it will take to reach the gate. Owners, meanwhile, often know their capacity but do not have a simple way to publish live availability or connect it to bookings.

## Why Two Apps

Park Here separates the driver and owner experiences because each side has a different job.

- Drivers need discovery, comparison, booking, QR tickets, and navigation.
- Location administrators need inventory control, booking visibility, income summaries, and location setup.

Keeping them separate makes the interface faster, reduces role checks in the UI, and makes future permissions easier.

## Why Firebase

Firebase is a good MVP backend because it covers authentication, realtime data, document storage, and operational dashboards without a custom server. The architecture keeps Firebase behind repositories so app code stays modular while runtime data comes from Firestore.

The app runtime now uses Firebase repositories by default. Local in-memory repositories remain only for tests and explicit development overrides, while demo records are seeded through `/demo/seed_firebase_demo.py`.

## Why Map-First UI

Parking decisions are spatial decisions. A list alone hides the most important questions: direction, distance, traffic expectation, and nearby alternatives. A map-first interface keeps the driver oriented while the bottom sheet handles choices and actions.

The user app is inspired by Namma Yatri’s clarity: a map as the main canvas, simple controls, large readable actions, and minimal clutter.

## Routing Options

Real routing APIs are best for production because they understand road networks, live conditions, turn restrictions, and travel modes. For local development, those APIs often require keys, billing, or network access. Park Here therefore uses a route provider interface with a local Dijkstra fallback.

The local fallback models the city as nodes and weighted edges. It is not a replacement for Google Maps, OSRM, Mapbox, or OpenRouteService, but it gives the app a deterministic route comparison flow while staying free and offline-friendly.

## Free Map Alternatives

- OpenStreetMap tiles with `flutter_map`
- OSRM public/demo routing for prototypes
- OpenRouteService free tier
- Self-hosted Valhalla or OSRM for serious deployments

The current MVP keeps map rendering dependency-light and draws a local route canvas. A real map provider can be added behind the route/map interface.

## Limitations

- Demo routing is graph-based, not real road navigation.
- Firebase config is required for normal runtime; missing config shows a setup error instead of app-bundled demo data.
- QR signing uses a local deterministic checksum for MVP verification readiness. Production should use a server-side HMAC or signed token.
- Images use Firestore-only optimized thumbnail/preview records by default. Firebase Storage is optional later because it may require Blaze billing.
