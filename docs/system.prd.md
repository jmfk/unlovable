# PRD — Supabase / Lovable Porting & Re-platforming System

## 1. Product Overview

### Product Name

Supabase Re-platforming System (working title)

### Purpose

This system takes an existing **Lovable / Supabase-based Git repository** and converts it into a **backend-first, production-ready architecture** centered on **Next.js**, with optional **Python** or **Elixir** backends.

The goal is to **remove Supabase from the frontend**, preserve **PostgreSQL + RLS**, and generate a secure, maintainable system suitable for long-term development.

This is not a framework converter.
 It is an **architecture and trust-boundary transformation system**.

------

## 2. Goals and Non-Goals

### Goals

- Eliminate direct Supabase usage from frontend code
- Preserve PostgreSQL and Row Level Security (RLS)
- Introduce a proper backend layer
- Support background jobs and storage outside the frontend
- Enable deterministic, agent-driven porting
- Produce runnable, testable output at every step

### Non-Goals

- No React SPA + Python architecture
- No frontend-managed authentication
- No custom auth implementation
- No direct database or storage access from the browser
- No free-form agent refactors

------

## 3. Supported Architectures (Authoritative)

The system supports **exactly three architectures**.

### Happy Path A — Next.js Only

- Next.js frontend + BFF
- No secondary backend
- No realtime
- No background workers

### Happy Path B — Next.js + Python (**Default**)

- Next.js as BFF
- Python (FastAPI) as primary backend
- Redis-backed background jobs
- Most balanced and recommended option

### Happy Path C — Next.js + Elixir

- Next.js as BFF
- Elixir (Phoenix) for realtime and concurrency
- Postgres-backed jobs
- No Python

If no explicit choice is made, the system **must select Happy Path B**.

------

## 4. Target Architecture (Common to All Paths)

### Frontend

- Next.js (latest stable)
- App Router
- Server Components enabled
- Frontend communicates **only** with backend APIs

### Backend-First Model

- All data access is server-side
- Supabase client is fully removed
- Frontend never talks directly to Postgres, Storage, or Auth APIs

------

## 5. Authentication & Authorization

### Authentication

- External OIDC provider only
- Cookie-based sessions owned by the backend
- Supported SSO providers:
  - Google
  - Microsoft
  - GitHub
  - Apple
  - LinkedIn

### Authorization

- PostgreSQL Row Level Security remains authoritative
- User claims injected per request
- Service-role access limited to admin tasks and background workers

### Explicitly Forbidden

- Frontend token storage
- LocalStorage auth
- Frontend-initiated DB queries

------

## 6. Database

### Database System

- PostgreSQL

### Data Access

- Node: Drizzle
- Python: SQLAlchemy (Core)
- Elixir: Ecto

### Migrations

- SQL migrations are the source of truth
- Existing Supabase migrations must be preserved or translated

### RLS

- Enforced on every user request
- Policy tests must be generated unless explicitly disabled

------

## 7. Background Processing

### Model

- Explicit queue-based execution
- No edge functions

### Options

- Python: Redis + workers
- Elixir: Oban (Postgres-backed)

### Requirements

- Idempotent jobs
- Retry strategy
- Dead-letter handling

------

## 8. Storage

### Storage Backend

- S3-compatible object storage

### Access Model

- Backend generates signed URLs
- No client credentials
- Metadata stored in Postgres

### Object Visibility

- Private by default
- Public only if explicitly configured

------

## 9. Realtime (Optional)

### Supported

- Phoenix Channels (Elixir path only)
- Presence and PubSub

### Not Supported

- Supabase realtime
- Ad-hoc WebSocket implementations

Realtime must be explicitly detected and enabled during porting.

------

## 10. Agent-Driven Porting Workflow

The system must execute in **strict phases**.

### Phase 1 — Inventory

- Supabase client usage
- Auth flows
- Storage usage
- Edge functions
- Realtime subscriptions
- DB triggers and RLS policies

### Phase 2 — Architecture Selection

- Happy Path selection
- Auth provider
- Backend runtime
- Queue and storage backend

### Phase 3 — Transformation

- Rewrite frontend data access
- Generate backend APIs
- Move business logic server-side
- Replace storage access
- Replace auth flows

### Phase 4 — Verification

- Type checks
- Auth flow tests
- RLS policy tests
- Golden user flows

Agents must **commit per phase** unless disabled.

------

## 11. Runtime Configuration (Required Inputs)

At execution time, the system must be given:

- Git repository URL
- Branch or commit
- Happy Path selection (or default)
- Auth provider
- Environment layout (dev / stage / prod)
- Agent type (Cursor / Claude Code)

If any required input is missing, the system must refuse to run.

------

## 12. Deployment Expectations

### Local Development

- Docker-based
- One-command startup

### Environments

- dev / prod minimum
- Optional stage

### Secrets

- Environment variables
- Secret manager in production

------

## 13. Success Criteria

The system is successful if:

- The frontend contains **zero Supabase client code**
- All database access is server-side
- Auth flows work end-to-end
- RLS policies are enforced and tested
- Background jobs run reliably
- The output system is runnable immediately after generation

------

## 14. Final Constraints (Non-Negotiable)

- Next.js is always the frontend
- Backend owns authentication
- Postgres + RLS is the authority
- Agents operate under phase constraints
- Happy paths prevent architectural drift

------

## Final Statement

This PRD defines a **deterministic, agent-safe re-platforming system**.

By removing ambiguous choices and locking in happy paths, the system trades flexibility for **correctness, security, and repeatability**—which is exactly what large-scale automated porting requires.