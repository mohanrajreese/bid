# Technical Documentation: BidPlatform SaaS

BidPlatform is a high-performance, multi-tenant auction platform built with the Phoenix Framework, leveraging PostgreSQL Row-Level Security (RLS) for data isolation and Phoenix LiveView for real-time interactivity.

## 🏛 Architecture Overview

### 1. Multi-Tenant Isolation (PostgreSQL RLS)
The system uses a single-database, shared-schema approach. Isolation is enforced at the database level:
- **Tenant Identification**: Every table contains a `tenant_id` column.
- **RLS Policies**: PostgreSQL Row-Level Security policies ensure that a database connection can only see rows belonging to the active `tenant_id`.
- **TenantPreparer**: A custom module (`BidPlatform.Repo.TenantPreparer`) sets the `app.current_tenant_id` session variable on every database checkout.

### 2. Core Contexts (Domain Logic)
- **Accounts**: Manages `User` and `Invitation` schemas. Handles registration and RBAC (Admin, Bidder).
- **Auctions**: Manages the auction lifecycle (`Auction` schema). Supports Forward/Reverse types and reserve prices.
- **Bidding**: The engine that processes `Bid` and `ProxyBid` records. Uses pessimistic locking to ensure concurrency safety.
- **Notifications**: persistence and dispatch of alerts via real-time PubSub and Swoosh Email.
- **AuditLogs**: Immutable record of all system-critical mutations.

### 3. Real-Time Engine (Phoenix Channels)
- Auctions broadcast updates to a specific topic: `tenant:{id}:auction:{id}`.
- Bids are broadcasted instantly, triggering UI updates without page reloads.
- User-specific notifications are sent to `user:{id}`.

### 4. Background Processing (Oban)
- **AuctionClosingWorker**: Auto-closes auctions at `end_time`, calculates winners, and handles reserve price logic.
- **GhostSweepWorker**: Cleans up abandoned or expired invitations/records.

## 🎨 Frontend Design System
The UI is built with **Tailwind CSS v4** and **DaisyUI**, featuring:
- **Glassmorphism**: Backdrop blurs, mesh gradients, and semi-transparent panels.
- **LiveView Components**: Encapsulated logic for auction forms and bidding controls.
- **Responsive Navigation**: Adaptive sidebar and header for mobile/desktop.

## 🚀 Environment & Deployment
- **Runtime**: Elixir 1.15+, Erlang/OTP 25+.
- **CI/CD**: GitHub Actions pipeline for linting, formatting, and unit testing.
- **Database**: PostgreSQL 16+.

## 🛠 Extension & Maintenance
To add new features:
1. **New Schema**: Create migration and schema with standard `tenant_id` column.
2. **Context**: Add domain logic to a module under `lib/bid/`.
3. **LiveView**: Create a new LiveView or Component under `lib/bid_web/live/`.
4. **Docs**: Update this file and typespecs in the module.
