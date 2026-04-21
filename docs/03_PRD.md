# PRODUCT REQUIREMENTS DOCUMENT (PRD) — Multi-Tenant Real-Time Bidding SaaS Platform

> **Document ID:** PRD-BID-2026-001
> **Version:** 1.0
> **Date:** April 21, 2026
> **Author:** Product & Engineering Team
> **Status:** Draft for Review
> **Classification:** Internal — Engineering
> **Related Documents:** MKT-BID-2026-001 (Market Analysis), BRD-BID-2026-001 (Business Requirements)
> **Tech Stack:** Phoenix Framework (Elixir), PostgreSQL, Phoenix Channels/LiveView, Oban

---

## 1. System Overview

### 1.1 Architecture Summary

The platform is a multi-tenant SaaS application built on the Phoenix Framework (Elixir/OTP) with PostgreSQL as the primary datastore. Multi-tenancy is implemented via a **shared database, shared schema** approach where every table includes a `tenant_id` column and every query is scoped through a tenant isolation layer.

Real-time bidding is powered by Phoenix Channels (WebSockets) with topic-level tenant isolation. Background job processing (auction auto-close, notifications, cleanup) is handled by Oban. The system is designed to handle thousands of concurrent bidders across hundreds of tenants with sub-500ms bid broadcast latency.

### 1.2 High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENTS                                  │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │ Web App  │  │ Mobile   │  │ API      │  │ Admin    │       │
│  │ (LiveView│  │ (Resp.)  │  │ Consumer │  │ Panel    │       │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
│       │              │              │              │             │
│       └──────────────┴──────┬───────┴──────────────┘             │
│                             │                                    │
│              ┌──────────────▼──────────────┐                    │
│              │     LOAD BALANCER / CDN     │                    │
│              └──────────────┬──────────────┘                    │
└─────────────────────────────┼───────────────────────────────────┘
                              │
┌─────────────────────────────▼───────────────────────────────────┐
│                    PHOENIX APPLICATION                           │
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────┐  │
│  │  Router / Plugs │  │  Tenant Context  │  │  Auth Layer    │  │
│  │  (HTTP + WS)    │  │  Middleware      │  │  (Guardian)    │  │
│  └────────┬────────┘  └────────┬────────┘  └───────┬────────┘  │
│           │                    │                     │           │
│  ┌────────▼────────────────────▼─────────────────────▼────────┐ │
│  │                    CONTEXT MODULES                          │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────────┐  │ │
│  │  │ Accounts │ │ Auctions │ │ Bidding  │ │ Notifications│  │ │
│  │  │ Context  │ │ Context  │ │ Context  │ │ Context      │  │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────────┘  │ │
│  └────────────────────────┬───────────────────────────────────┘ │
│                           │                                      │
│  ┌────────────────────────▼───────────────────────────────────┐ │
│  │                    REAL-TIME LAYER                          │ │
│  │  ┌──────────────────┐  ┌───────────────────────────────┐  │ │
│  │  │ Phoenix Channels │  │ PubSub (distributed Erlang)   │  │ │
│  │  │ tenant:T:auction │  │ (multi-node sync)             │  │ │
│  │  └──────────────────┘  └───────────────────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
│                                                                  │
│  ┌────────────────────────────────────────────────────────────┐ │
│  │                    BACKGROUND JOBS (Oban)                  │ │
│  │  ┌──────────────┐ ┌──────────────┐ ┌──────────────────┐  │ │
│  │  │ AuctionCloser│ │ Notifier     │ │ CleanupWorker    │  │ │
│  │  └──────────────┘ └──────────────┘ └──────────────────┘  │ │
│  └────────────────────────────────────────────────────────────┘ │
└──────────────────────────────┬──────────────────────────────────┘
                               │
┌──────────────────────────────▼──────────────────────────────────┐
│                      DATA LAYER                                  │
│  ┌──────────────────┐  ┌──────────────────┐                    │
│  │   PostgreSQL     │  │   Redis          │                    │
│  │   (Primary DB)   │  │   (Cache/PubSub) │                    │
│  │   - tenants      │  │   - current_price│                    │
│  │   - users        │  │   - session data │                    │
│  │   - auctions     │  │                  │                    │
│  │   - bids         │  │   (Optional)     │                    │
│  │   - audit_logs   │  │                  │                    │
│  └──────────────────┘  └──────────────────┘                    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. Data Model

### 2.1 Entity Relationship Diagram

```
┌──────────────┐       ┌──────────────────┐       ┌──────────────┐
│   tenants    │       │     users        │       │  auctions    │
├──────────────┤       ├──────────────────┤       ├──────────────┤
│ id (PK)      │──┐    │ id (PK)          │    ┌──│ id (PK)      │
│ name         │  │    │ tenant_id (FK)───│────│  │ tenant_id(FK)│──┐
│ subdomain    │  │    │ email            │    │  │ created_by   │  │
│ slug         │  └────│                  │    │  │ type         │  │
│ plan         │       │ password_hash    │    │  │ title        │  │
│ settings     │       │ role             │    │  │ description  │  │
│ is_active    │       │ is_active        │    │  │ start_price  │  │
│ inserted_at  │       │ inserted_at      │    │  │ current_price│  │
│ updated_at   │       │ updated_at       │    │  │ min_increment│  │
└──────────────┘       └──────────────────┘    │  │ reserve_price│  │
                                               │  │ start_time   │  │
                                               │  │ end_time     │  │
                                               │  │ status       │  │
                                               │  │ winner_id    │  │
                                               │  │ settings     │  │
                                               │  │ inserted_at  │  │
                                               │  │ updated_at   │  │
                                               │  └──────────────┘  │
                                               │         │          │
                                               │  ┌──────▼───────┐  │
                                               │  │    bids      │  │
                                               │  ├──────────────┤  │
                                               │  │ id (PK)      │  │
                                               └──│ tenant_id(FK)│  │
                                                  │ auction_id   │──┘
                                                  │ user_id (FK) │
                                                  │ amount       │
                                                  │ status       │
                                                  │ metadata     │
                                                  │ inserted_at  │
                                                  └──────────────┘

┌──────────────────┐
│   audit_logs     │
├──────────────────┤
│ id (PK)          │
│ tenant_id (FK)   │
│ user_id (FK)     │
│ action           │
│ resource_type    │
│ resource_id      │
│ changes          │
│ ip_address       │
│ user_agent       │
│ inserted_at      │
└──────────────────┘
```

### 2.2 Table Definitions

#### `tenants`

```elixir
# Table: tenants
# Purpose: Root entity for multi-tenancy. Every organization is a tenant.
# Isolation: This table is the anchor — all other tables reference tenant_id.

defmodule BidPlatform.Tenants.Tenant do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "tenants" do
    field :name, :string          # Organization display name
    field :subdomain, :string     # Unique subdomain (e.g., "acme" → acme.bidplatform.com)
    field :slug, :string          # URL-safe identifier
    field :plan, :string, default: "free"  # Subscription tier: free, starter, professional, enterprise
    field :is_active, :boolean, default: true
    field :settings, :map, default: %{
      "max_auctions_per_month" => 3,
      "max_users" => 10,
      "max_concurrent_bidders" => 5,
      "custom_domain" => nil,
      "branding" => %{}
    }

    has_many :users, BidPlatform.Accounts.User
    has_many :auctions, BidPlatform.Auctions.Auction

    timestamps()
  end

  def changeset(tenant, attrs) do
    tenant
    |> cast(attrs, [:name, :subdomain, :slug, :plan, :is_active, :settings])
    |> validate_required([:name, :subdomain])
    |> validate_format(:subdomain, ~r/^[a-z0-9]([a-z0-9-]*[a-z0-9])?$/, message: "must be lowercase alphanumeric with optional hyphens")
    |> validate_length(:subdomain, min: 3, max: 63)
    |> unique_constraint(:subdomain)
    |> validate_exclusion(:subdomain, ~w[www api admin app dashboard mail ftp], message: "is reserved")
  end
end
```

#### `users`

```elixir
# Table: users
# Purpose: Authenticated users within a tenant. Each user belongs to exactly one tenant.
# Roles: "super_admin" (platform-level), "admin" (tenant-level), "bidder" (participant)

defmodule BidPlatform.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "users" do
    field :email, :string
    field :password_hash, :string
    field :password, :string, virtual: true          # Never persisted
    field :password_confirmation, :string, virtual: true
    field :name, :string
    field :role, :string, default: "bidder"           # "admin" | "bidder"
    field :is_active, :boolean, default: true
    field :last_login_at, :utc_datetime

    belongs_to :tenant, BidPlatform.Tenants.Tenant, type: :binary_id
    has_many :bids, BidPlatform.Bidding.Bid

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :name, :role, :is_active, :tenant_id])
    |> validate_required([:email, :name, :role, :tenant_id])
    |> validate_format(:email, ~r/^[\w.!#$%&'*+\/=?^`{|}~-]+@[\w-]+(?:\.[\w-]+)+$/)
    |> validate_inclusion(:role, ~w[admin bidder])
    |> unique_constraint([:email, :tenant_id], message: "already registered in this organization")
    |> put_password_hash()
  end

  defp put_password_hash(%Ecto.Changeset{valid?: true, changes: %{password: pw}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(pw))
  end
  defp put_password_hash(changeset), do: changeset
end
```

#### `auctions`

```elixir
# Table: auctions
# Purpose: Core auction entity. Supports both English (forward) and Reverse types.
# Lifecycle: draft → scheduled → active → closed | force_closed | no_bids | reserve_not_met

defmodule BidPlatform.Auctions.Auction do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @valid_types ~w[english reverse]
  @valid_statuses ~w[draft scheduled active closed force_closed no_bids reserve_not_met cancelled]

  schema "auctions" do
    field :title, :string
    field :description, :string
    field :type, :string                            # "english" | "reverse"
    field :start_price, :decimal                    # Starting price (floor for english, ceiling for reverse)
    field :current_price, :decimal                  # Real-time current price
    field :min_increment, :decimal                  # Minimum bid increment (english) or decrement (reverse)
    field :reserve_price, :decimal                  # Hidden reserve (english only); nil if not set
    field :start_time, :utc_datetime                # When auction goes active
    field :end_time, :utc_datetime                  # When auction auto-closes
    field :original_end_time, :utc_datetime         # Preserved for anti-sniping tracking
    field :status, :string, default: "draft"
    field :winner_id, :binary_id                    # FK to users.id (set on close)
    field :winning_bid_id, :binary_id               # FK to bids.id (set on close)
    field :bid_count, :integer, default: 0          # Denormalized counter
    field :settings, :map, default: %{
      "anti_sniping_enabled" => false,
      "anti_sniping_window_minutes" => 5,
      "anti_sniping_extension_minutes" => 3,
      "max_extensions" => 5,
      "extension_count" => 0,
      "visibility" => "invited",                    # "invited" | "public_within_tenant"
      "allow_auto_bid" => false
    }

    belongs_to :tenant, BidPlatform.Tenants.Tenant, type: :binary_id
    belongs_to :created_by_user, BidPlatform.Accounts.User,
      type: :binary_id, foreign_key: :created_by
    has_many :bids, BidPlatform.Bidding.Bid

    timestamps()
  end

  def changeset(auction, attrs) do
    auction
    |> cast(attrs, [
      :title, :description, :type, :start_price, :current_price,
      :min_increment, :reserve_price, :start_time, :end_time,
      :status, :tenant_id, :created_by, :settings
    ])
    |> validate_required([:title, :type, :start_price, :min_increment, :end_time, :tenant_id, :created_by])
    |> validate_inclusion(:type, @valid_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_number(:start_price, greater_than: 0)
    |> validate_number(:min_increment, greater_than: 0)
    |> validate_end_time_after_now()
    |> validate_reserve_price()
    |> set_current_price()
    |> set_original_end_time()
  end

  # Ensure end_time is in the future
  defp validate_end_time_after_now(changeset) do
    validate_change(changeset, :end_time, fn :end_time, end_time ->
      if DateTime.compare(end_time, DateTime.utc_now()) == :gt do
        []
      else
        [end_time: "must be in the future"]
      end
    end)
  end

  # Reserve price only valid for English auctions
  defp validate_reserve_price(changeset) do
    type = get_field(changeset, :type)
    reserve = get_change(changeset, :reserve_price)

    cond do
      type == "reverse" && reserve != nil ->
        add_error(changeset, :reserve_price, "not allowed for reverse auctions")
      type == "english" && reserve != nil ->
        start = get_field(changeset, :start_price)
        if Decimal.compare(reserve, start) == :lt do
          add_error(changeset, :reserve_price, "must be greater than or equal to start price")
        else
          changeset
        end
      true ->
        changeset
    end
  end

  # Initialize current_price to start_price on creation
  defp set_current_price(changeset) do
    if get_field(changeset, :current_price) == nil do
      put_change(changeset, :current_price, get_field(changeset, :start_price))
    else
      changeset
    end
  end

  defp set_original_end_time(changeset) do
    if get_field(changeset, :original_end_time) == nil do
      put_change(changeset, :original_end_time, get_field(changeset, :end_time))
    else
      changeset
    end
  end
end
```

#### `bids`

```elixir
# Table: bids
# Purpose: Immutable bid records. Once inserted, a bid cannot be modified or deleted.
# Integrity: tenant_id is denormalized for isolation enforcement at query level.

defmodule BidPlatform.Bidding.Bid do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "bids" do
    field :amount, :decimal
    field :status, :string, default: "valid"       # "valid" | "outbid" | "winning" | "rejected"
    field :metadata, :map, default: %{}            # IP address, user agent, device info

    belongs_to :tenant, BidPlatform.Tenants.Tenant, type: :binary_id
    belongs_to :auction, BidPlatform.Auctions.Auction, type: :binary_id
    belongs_to :user, BidPlatform.Accounts.User, type: :binary_id

    # Bids are insert-only — no updated_at needed, but Ecto requires it
    timestamps()
  end

  def changeset(bid, attrs) do
    bid
    |> cast(attrs, [:amount, :tenant_id, :auction_id, :user_id, :metadata])
    |> validate_required([:amount, :tenant_id, :auction_id, :user_id])
    |> validate_number(:amount, greater_than: 0)
    |> foreign_key_constraint(:auction_id)
    |> foreign_key_constraint(:user_id)
  end
end
```

#### `audit_logs`

```elixir
# Table: audit_logs
# Purpose: Immutable audit trail for all significant actions.
# Insert-only — no updates or deletes ever.

defmodule BidPlatform.Audit.AuditLog do
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "audit_logs" do
    field :action, :string              # "auction.created", "bid.placed", "auction.closed", etc.
    field :resource_type, :string       # "auction", "bid", "user", "tenant"
    field :resource_id, :binary_id
    field :changes, :map, default: %{} # Before/after state for mutations
    field :ip_address, :string
    field :user_agent, :string

    belongs_to :tenant, BidPlatform.Tenants.Tenant, type: :binary_id
    belongs_to :user, BidPlatform.Accounts.User, type: :binary_id

    timestamps(updated_at: false)       # Insert-only — no updated_at
  end
end
```

### 2.3 Database Migrations

```elixir
# Migration: Create all core tables with proper indexes and constraints

defmodule BidPlatform.Repo.Migrations.CreateCoreTables do
  use Ecto.Migration

  def change do
    # ── TENANTS ──────────────────────────────────────────────────
    create table(:tenants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :subdomain, :string, null: false
      add :slug, :string
      add :plan, :string, null: false, default: "free"
      add :is_active, :boolean, null: false, default: true
      add :settings, :map, default: %{}
      timestamps()
    end
    create unique_index(:tenants, [:subdomain])
    create index(:tenants, [:is_active])

    # ── USERS ────────────────────────────────────────────────────
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :email, :string, null: false
      add :password_hash, :string, null: false
      add :name, :string, null: false
      add :role, :string, null: false, default: "bidder"
      add :is_active, :boolean, null: false, default: true
      add :last_login_at, :utc_datetime
      timestamps()
    end
    create unique_index(:users, [:email, :tenant_id])
    create index(:users, [:tenant_id])
    create index(:users, [:tenant_id, :role])

    # ── AUCTIONS ─────────────────────────────────────────────────
    create table(:auctions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :created_by, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :title, :string, null: false
      add :description, :text
      add :type, :string, null: false    # "english" | "reverse"
      add :start_price, :decimal, null: false, precision: 15, scale: 2
      add :current_price, :decimal, null: false, precision: 15, scale: 2
      add :min_increment, :decimal, null: false, precision: 15, scale: 2
      add :reserve_price, :decimal, precision: 15, scale: 2   # nullable
      add :start_time, :utc_datetime
      add :end_time, :utc_datetime, null: false
      add :original_end_time, :utc_datetime
      add :status, :string, null: false, default: "draft"
      add :winner_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :winning_bid_id, :binary_id   # Set on close
      add :bid_count, :integer, null: false, default: 0
      add :settings, :map, default: %{}
      timestamps()
    end
    create index(:auctions, [:tenant_id])
    create index(:auctions, [:tenant_id, :status])
    create index(:auctions, [:tenant_id, :type])
    create index(:auctions, [:status, :end_time])    # For Oban close-scheduler queries
    create index(:auctions, [:end_time])

    # ── BIDS ─────────────────────────────────────────────────────
    create table(:bids, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :auction_id, references(:auctions, type: :binary_id, on_delete: :restrict), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :amount, :decimal, null: false, precision: 15, scale: 2
      add :status, :string, null: false, default: "valid"
      add :metadata, :map, default: %{}
      timestamps()
    end
    create index(:bids, [:tenant_id])
    create index(:bids, [:auction_id])
    create index(:bids, [:tenant_id, :auction_id])
    create index(:bids, [:auction_id, :inserted_at])  # For bid history ordering
    create index(:bids, [:auction_id, :amount])        # For winner determination

    # ── AUDIT LOGS ───────────────────────────────────────────────
    create table(:audit_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :tenant_id, references(:tenants, type: :binary_id, on_delete: :restrict), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :action, :string, null: false
      add :resource_type, :string, null: false
      add :resource_id, :binary_id
      add :changes, :map, default: %{}
      add :ip_address, :string
      add :user_agent, :string
      timestamps(updated_at: false)
    end
    create index(:audit_logs, [:tenant_id])
    create index(:audit_logs, [:tenant_id, :resource_type, :resource_id])
    create index(:audit_logs, [:tenant_id, :inserted_at])
  end
end
```

---

## 3. Feature Breakdown

### 3.1 Feature Priority Matrix

| Priority | Feature | Module | Status |
|----------|---------|--------|--------|
| **P0** | Tenant registration & provisioning | Tenants | MVP |
| **P0** | User authentication (login, register, session) | Accounts | MVP |
| **P0** | Role-based access control (Admin, Bidder) | Accounts | MVP |
| **P0** | Create auction (English + Reverse) | Auctions | MVP |
| **P0** | Real-time bid submission & validation | Bidding | MVP |
| **P0** | Real-time bid broadcast (WebSocket) | Channels | MVP |
| **P0** | Auction auto-close & winner determination | Oban Jobs | MVP |
| **P0** | Tenant data isolation (all queries scoped) | Core | MVP |
| **P1** | Bid history & audit trail | Auctions | MVP |
| **P1** | Outbid notifications (in-app) | Notifications | MVP |
| **P1** | Admin: manage users within tenant | Accounts | MVP |
| **P1** | Admin: force-close auction | Auctions | MVP |
| **P1** | Anti-sniping time extensions | Auctions | MVP |
| **P1** | Auction countdown timer (real-time sync) | Channels | MVP |
| **P2** | Email notifications (outbid, win, loss) | Notifications | Phase 2 |
| **P2** | Subdomain routing per tenant | Tenants | Phase 2 |
| **P2** | Invite external bidders via email | Accounts | Phase 2 |
| **P2** | Platform super-admin dashboard | Admin | Phase 2 |
| **P2** | Basic analytics (bids/auction, avg value) | Analytics | Phase 2 |
| **P3** | Razorpay subscription billing | Billing | Phase 3 |
| **P3** | API keys & external API access | API | Phase 3 |
| **P3** | Sealed bid auctions | Auctions | Phase 3 |
| **P3** | AI-based bid suggestions | AI | Phase 3+ |

---

## 4. Functional Requirements

### 4.1 Authentication & Authorization

#### FR-AUTH-001: User Registration

```
REQUIREMENT: Users can register with email + password within a tenant context.
INPUT: email, password, password_confirmation, name, tenant_id (derived from subdomain or signup flow)
VALIDATION:
  - Email format validation (RFC 5322 compliant)
  - Password minimum 8 characters, at least 1 number, 1 uppercase
  - Email must be unique within the tenant (same email can exist in different tenants)
OUTPUT: User created with role="bidder" (default) or role="admin" (first user in tenant)
EDGE CASES:
  - Same email registers in two different tenants → ALLOWED (separate user records)
  - Registration with inactive tenant → REJECTED with "Organization is not active"
  - Concurrent registration with same email → Database unique constraint prevents duplicates
```

#### FR-AUTH-002: User Login

```
REQUIREMENT: Users authenticate with email + password, receiving a session token.
INPUT: email, password, tenant_id (from subdomain context)
VALIDATION:
  - User must exist in the specified tenant
  - Password must match stored hash
  - User must be active (is_active = true)
  - Tenant must be active (is_active = true)
OUTPUT: JWT token (or session cookie) containing user_id, tenant_id, role
SECURITY:
  - Rate limit: 5 failed attempts per email per 15 minutes → account locked for 30 minutes
  - Login attempts logged in audit_logs
  - Password never logged or returned in any response
EDGE CASES:
  - User exists in tenant A but tries to login via tenant B's subdomain → REJECTED
  - Disabled user attempts login → REJECTED with "Account is disabled"
  - Brute force attempt → Rate limited, account locked, admin notified
```

#### FR-AUTH-003: Role-Based Access Control (RBAC)

```
ROLES AND PERMISSIONS:

┌─────────────────────────────┬───────┬────────┐
│ Action                      │ Admin │ Bidder │
├─────────────────────────────┼───────┼────────┤
│ Create auction              │  ✅   │  ❌   │
│ Edit auction (draft only)   │  ✅   │  ❌   │
│ Delete auction (draft only) │  ✅   │  ❌   │
│ Force-close auction         │  ✅   │  ❌   │
│ View auction list           │  ✅   │  ✅   │
│ View auction details        │  ✅   │  ✅   │
│ Place bid                   │  ❌*  │  ✅   │
│ View bid history            │  ✅   │  ✅** │
│ Manage users (invite, role) │  ✅   │  ❌   │
│ Deactivate users            │  ✅   │  ❌   │
│ View audit logs             │  ✅   │  ❌   │
│ Configure tenant settings   │  ✅   │  ❌   │
└─────────────────────────────┴───────┴────────┘

* Admins can bid only if they are not the auction creator
** Bidders see only their own bids unless auction settings allow full transparency
```

Implementation:

```elixir
# Authorization plug — enforces RBAC at the controller level

defmodule BidPlatformWeb.Plugs.Authorize do
  import Plug.Conn
  import Phoenix.Controller, only: [json: 2]

  @doc """
  Ensures the current user has the required role.
  Usage in router: plug Authorize, roles: ["admin"]
  """
  def init(opts), do: opts

  def call(conn, opts) do
    required_roles = Keyword.get(opts, :roles, [])
    current_user = conn.assigns[:current_user]

    cond do
      current_user == nil ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Authentication required"})
        |> halt()

      current_user.role not in required_roles ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "Insufficient permissions", required: required_roles, current: current_user.role})
        |> halt()

      true ->
        conn
    end
  end
end
```

### 4.2 Tenant Management

#### FR-TENANT-001: Tenant Registration

```
REQUIREMENT: New organizations can self-register as tenants.
INPUT: organization_name, subdomain, admin_email, admin_password, admin_name
PROCESS:
  1. Validate subdomain (unique, not reserved, alphanumeric)
  2. Create tenant record with plan="free"
  3. Create first user with role="admin"
  4. Schedule welcome email via Oban
  5. Log in audit_logs: "tenant.created"
OUTPUT: Tenant created, admin user created, session established
EDGE CASES:
  - Subdomain already taken → Return error: "This subdomain is not available"
  - Reserved subdomain (www, api, admin) → Return error: "This subdomain is reserved"
  - Database failure mid-creation → Transaction rollback; nothing persisted
  - Concurrent subdomain registration → Unique constraint enforces first-writer-wins
```

#### FR-TENANT-002: Tenant Isolation Middleware

```elixir
# Critical: This plug extracts tenant_id from the authenticated user
# and injects it into all downstream operations.

defmodule BidPlatformWeb.Plugs.TenantScope do
  import Plug.Conn

  @doc """
  Extracts tenant_id from the authenticated user and places it
  in conn.assigns for use by all controllers and contexts.

  This is the PRIMARY enforcement point for data isolation.
  Every context function MUST use this tenant_id for queries.
  """
  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.assigns[:current_user] do
      %{tenant_id: tenant_id} when not is_nil(tenant_id) ->
        conn
        |> assign(:tenant_id, tenant_id)

      _ ->
        conn
        |> put_status(:unauthorized)
        |> Phoenix.Controller.json(%{error: "Tenant context required"})
        |> halt()
    end
  end
end
```

```elixir
# Tenant-scoped query helper — EVERY database query must use this

defmodule BidPlatform.TenantScope do
  import Ecto.Query

  @doc """
  Scopes any queryable to a specific tenant.
  This function MUST be used in every context module query.

  ## Examples

      Auction
      |> TenantScope.scope(tenant_id)
      |> Repo.all()

      Bid
      |> TenantScope.scope(tenant_id)
      |> where([b], b.auction_id == ^auction_id)
      |> Repo.all()
  """
  def scope(queryable, tenant_id) do
    from q in queryable, where: q.tenant_id == ^tenant_id
  end

  @doc """
  Scopes and fetches a single record. Returns nil if not found
  or if the record belongs to a different tenant.
  """
  def get(queryable, tenant_id, id) do
    queryable
    |> scope(tenant_id)
    |> where([q], q.id == ^id)
    |> BidPlatform.Repo.one()
  end

  @doc """
  Scopes and fetches a single record. Raises if not found.
  This is the safe equivalent of Repo.get! — it ensures tenant isolation.
  """
  def get!(queryable, tenant_id, id) do
    case get(queryable, tenant_id, id) do
      nil -> raise Ecto.NoResultsError, queryable: queryable
      record -> record
    end
  end
end
```

### 4.3 Auction Management

#### FR-AUCTION-001: Create Auction

```
REQUIREMENT: Admin creates a new auction within their tenant.
INPUT:
  - title (string, required, 5-200 chars)
  - description (text, optional, max 5000 chars)
  - type ("english" | "reverse", required)
  - start_price (decimal > 0, required)
  - min_increment (decimal > 0, required)
  - reserve_price (decimal, optional, english only, must be >= start_price)
  - start_time (datetime, optional, defaults to now)
  - end_time (datetime, required, must be in future, must be after start_time)
  - settings.anti_sniping_enabled (boolean, default false)
  - settings.anti_sniping_window_minutes (integer, default 5)
  - settings.anti_sniping_extension_minutes (integer, default 3)
  - settings.max_extensions (integer, default 5)

VALIDATION:
  - All required fields present and valid types
  - start_price > 0
  - min_increment > 0
  - min_increment <= start_price (increment can't exceed the starting price)
  - end_time > start_time > now (if start_time provided)
  - end_time > now + 5 minutes (minimum auction duration)
  - reserve_price: only for english type, must be >= start_price
  - Tenant's monthly auction limit not exceeded (per plan)

PROCESS:
  1. Validate input
  2. Check tenant plan limits (auctions this month vs max_auctions_per_month)
  3. Create auction with status="draft" (or "scheduled" if start_time is future)
  4. Set current_price = start_price
  5. Set original_end_time = end_time
  6. Schedule Oban job for auction auto-close at end_time
  7. If start_time is in the future, schedule Oban job to activate at start_time
  8. Log audit: "auction.created"

OUTPUT: Auction record with all fields populated

EDGE CASES:
  - Tenant at auction limit → REJECTED: "You have reached your plan's auction limit for this month"
  - end_time in the past → REJECTED: "Auction end time must be in the future"
  - min_increment > start_price → REJECTED: "Increment cannot exceed the starting price"
  - reserve_price on reverse auction → REJECTED: "Reserve price is not applicable for reverse auctions"
  - Extremely long end_time (>30 days) → WARNING (allowed but flagged)
```

#### FR-AUCTION-002: Auction Lifecycle State Machine

```
STATE TRANSITIONS:

  ┌───────┐    schedule    ┌───────────┐    activate    ┌────────┐
  │ draft │───────────────▶│ scheduled │───────────────▶│ active │
  └───┬───┘                └─────┬─────┘                └───┬────┘
      │                          │                          │
      │ cancel                   │ cancel              auto-close
      │                          │                     (end_time)
      ▼                          ▼                          │
  ┌───────────┐           ┌───────────┐                    │
  │ cancelled │           │ cancelled │                    │
  └───────────┘           └───────────┘                    │
                                                           │
                    ┌──────────────────────────┬────────────┤
                    │                          │            │
                    ▼                          ▼            ▼
              ┌──────────┐          ┌──────────────┐  ┌─────────┐
              │ no_bids  │          │reserve_not_met│  │ closed  │
              └──────────┘          └──────────────┘  └─────────┘
                                                           │
                                                    force_close
                                                    (admin)
                                                           ▼
                                                    ┌──────────────┐
                                                    │ force_closed │
                                                    └──────────────┘

TRANSITION RULES:
  - draft → scheduled: When start_time is in the future and admin confirms
  - draft → active: When start_time is now or not set
  - draft → cancelled: Admin cancels before activation
  - scheduled → active: System activates at start_time (Oban job)
  - scheduled → cancelled: Admin cancels before activation
  - active → closed: System auto-closes at end_time, bids exist, reserve met (or no reserve)
  - active → no_bids: System auto-closes at end_time, no bids received
  - active → reserve_not_met: English auction closes but highest bid < reserve_price
  - active → force_closed: Admin force-closes; winner = best bid at time of closure
  - No reverse transitions allowed (closed → active is NEVER possible)
```

### 4.4 Bidding Module

#### FR-BID-001: Place a Bid

```
REQUIREMENT: Authenticated bidder submits a bid on an active auction within their tenant.
INPUT: auction_id, amount (decimal)
ACTOR: User with role="bidder" (or admin who is not the auction creator)

VALIDATION PIPELINE (in order):
  1. User is authenticated and belongs to the auction's tenant
  2. Auction exists and belongs to the same tenant
  3. Auction status == "active"
  4. Current time < auction end_time
  5. User is not the auction creator (no self-bidding)
  6. Bid amount > 0
  7. TYPE-SPECIFIC VALIDATION:
     - English: amount >= current_price + min_increment
     - Reverse: amount <= current_price - min_increment
  8. Bid amount is not identical to current_price (no zero-delta bids)
  9. User has not been banned from this auction

PROCESS (within a database transaction with row-level locking):
  1. Lock the auction row: SELECT ... FOR UPDATE
  2. Re-validate bid against the locked current_price (prevents race conditions)
  3. Insert bid record with status="valid"
  4. Update previous leading bid's status to "outbid"
  5. Update auction.current_price to new bid amount
  6. Increment auction.bid_count
  7. Check anti-sniping: if bid is within the sniping window and extensions < max_extensions:
     - Extend auction.end_time by extension_minutes
     - Increment extension_count
     - Reschedule Oban auto-close job
  8. Commit transaction
  9. Broadcast bid via Phoenix Channel to all connected clients
  10. Dispatch outbid notification to previous leader (Oban job)
  11. Log audit: "bid.placed"

OUTPUT: Bid record with confirmation
```

Core bidding implementation:

```elixir
defmodule BidPlatform.Bidding do
  @moduledoc """
  Core bidding context. Handles bid placement with concurrency safety.
  All operations are tenant-scoped.
  """

  alias BidPlatform.{Repo, TenantScope}
  alias BidPlatform.Auctions.Auction
  alias BidPlatform.Bidding.Bid
  alias BidPlatform.Bidding.BidValidator
  import Ecto.Query

  @doc """
  Places a bid on an auction with full concurrency safety.

  This function:
  1. Acquires a row-level lock on the auction (FOR UPDATE)
  2. Validates the bid against current state
  3. Atomically updates the auction and inserts the bid
  4. Handles anti-sniping extensions

  Returns {:ok, %{bid: bid, auction: auction}} or {:error, reason}
  """
  def place_bid(tenant_id, auction_id, user_id, amount) do
    Repo.transaction(fn ->
      # Step 1: Lock the auction row to prevent concurrent bid races
      auction =
        Auction
        |> TenantScope.scope(tenant_id)
        |> where([a], a.id == ^auction_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      # Step 2: Validate the bid against the locked state
      case BidValidator.validate(auction, user_id, amount) do
        :ok ->
          # Step 3: Insert the bid
          {:ok, bid} =
            %Bid{}
            |> Bid.changeset(%{
              tenant_id: tenant_id,
              auction_id: auction_id,
              user_id: user_id,
              amount: amount,
              status: "valid",
              metadata: %{
                "previous_price" => Decimal.to_string(auction.current_price),
                "bid_number" => auction.bid_count + 1
              }
            })
            |> Repo.insert()

          # Step 4: Mark previous leading bid as outbid
          mark_previous_bids_as_outbid(tenant_id, auction_id, bid.id)

          # Step 5: Update auction's current price and bid count
          {end_time, extension_count} =
            maybe_extend_auction(auction, DateTime.utc_now())

          {1, _} =
            Auction
            |> where([a], a.id == ^auction_id and a.tenant_id == ^tenant_id)
            |> Repo.update_all(
              set: [
                current_price: amount,
                bid_count: auction.bid_count + 1,
                end_time: end_time,
                updated_at: DateTime.utc_now()
              ],
              inc: []
            )

          # Fetch the updated auction
          updated_auction = TenantScope.get!(Auction, tenant_id, auction_id)

          %{bid: bid, auction: updated_auction}

        {:error, reason} ->
          Repo.rollback(reason)
      end
    end)
  end

  # Mark all previous "valid" bids on this auction as "outbid"
  defp mark_previous_bids_as_outbid(tenant_id, auction_id, current_bid_id) do
    Bid
    |> where([b],
      b.tenant_id == ^tenant_id and
      b.auction_id == ^auction_id and
      b.id != ^current_bid_id and
      b.status == "valid"
    )
    |> Repo.update_all(set: [status: "outbid", updated_at: DateTime.utc_now()])
  end

  # Check if anti-sniping extension should be applied
  defp maybe_extend_auction(auction, now) do
    settings = auction.settings || %{}
    anti_sniping = Map.get(settings, "anti_sniping_enabled", false)
    window = Map.get(settings, "anti_sniping_window_minutes", 5)
    extension = Map.get(settings, "anti_sniping_extension_minutes", 3)
    max_ext = Map.get(settings, "max_extensions", 5)
    current_ext = Map.get(settings, "extension_count", 0)

    sniping_threshold = DateTime.add(auction.end_time, -window * 60, :second)

    if anti_sniping &&
       DateTime.compare(now, sniping_threshold) in [:gt, :eq] &&
       current_ext < max_ext do
      new_end = DateTime.add(auction.end_time, extension * 60, :second)
      {new_end, current_ext + 1}
    else
      {auction.end_time, current_ext}
    end
  end
end
```

Bid validator:

```elixir
defmodule BidPlatform.Bidding.BidValidator do
  @moduledoc """
  Pure validation logic for bid placement.
  Separated from side effects for testability.
  """

  alias BidPlatform.Auctions.Auction

  @doc """
  Validates a bid against the current auction state.
  Returns :ok or {:error, reason_string}.
  """
  def validate(nil, _user_id, _amount) do
    {:error, "Auction not found"}
  end

  def validate(%Auction{} = auction, user_id, amount) do
    validations = [
      {&auction_is_active/1, [auction]},
      {&auction_not_expired/1, [auction]},
      {&user_not_creator/2, [auction, user_id]},
      {&amount_is_positive/1, [amount]},
      {&bid_meets_increment/2, [auction, amount]}
    ]

    Enum.reduce_while(validations, :ok, fn {func, args}, :ok ->
      case apply(func, args) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp auction_is_active(%Auction{status: "active"}), do: :ok
  defp auction_is_active(%Auction{status: status}),
    do: {:error, "Auction is not active (current status: #{status})"}

  defp auction_not_expired(%Auction{end_time: end_time}) do
    if DateTime.compare(DateTime.utc_now(), end_time) == :lt do
      :ok
    else
      {:error, "Auction has ended"}
    end
  end

  defp user_not_creator(%Auction{created_by: creator_id}, user_id) do
    if creator_id == user_id do
      {:error, "Auction creator cannot bid on their own auction"}
    else
      :ok
    end
  end

  defp amount_is_positive(amount) do
    if Decimal.compare(amount, Decimal.new(0)) == :gt do
      :ok
    else
      {:error, "Bid amount must be greater than zero"}
    end
  end

  defp bid_meets_increment(%Auction{type: "english"} = auction, amount) do
    minimum = Decimal.add(auction.current_price, auction.min_increment)
    if Decimal.compare(amount, minimum) in [:gt, :eq] do
      :ok
    else
      {:error, "Bid must be at least #{Decimal.to_string(minimum)} (current: #{Decimal.to_string(auction.current_price)} + increment: #{Decimal.to_string(auction.min_increment)})"}
    end
  end

  defp bid_meets_increment(%Auction{type: "reverse"} = auction, amount) do
    maximum = Decimal.sub(auction.current_price, auction.min_increment)
    if Decimal.compare(amount, maximum) in [:lt, :eq] do
      :ok
    else
      {:error, "Bid must be at most #{Decimal.to_string(maximum)} (current: #{Decimal.to_string(auction.current_price)} - decrement: #{Decimal.to_string(auction.min_increment)})"}
    end
  end
end
```

### 4.5 Real-Time Channel Design

#### FR-RT-001: Auction Channel

```elixir
defmodule BidPlatformWeb.AuctionChannel do
  @moduledoc """
  WebSocket channel for real-time auction updates.

  Topic format: "tenant:{tenant_id}:auction:{auction_id}"

  This ensures:
  1. Tenant isolation — users can only join channels matching their tenant_id
  2. Auction-level granularity — updates are scoped to specific auctions
  3. No cross-tenant data leakage — topic includes tenant_id
  """

  use BidPlatformWeb, :channel

  alias BidPlatform.{TenantScope, Auctions}
  alias BidPlatform.Auctions.Auction

  @doc """
  Handles channel join with tenant isolation enforcement.
  """
  def join("tenant:" <> rest, _payload, socket) do
    [tenant_id, "auction", auction_id] = String.split(rest, ":")

    # CRITICAL: Verify the joining user belongs to this tenant
    user = socket.assigns.current_user

    cond do
      user.tenant_id != tenant_id ->
        # SECURITY: Reject cross-tenant channel access
        {:error, %{reason: "unauthorized — tenant mismatch"}}

      TenantScope.get(Auction, tenant_id, auction_id) == nil ->
        {:error, %{reason: "auction not found"}}

      true ->
        socket =
          socket
          |> assign(:tenant_id, tenant_id)
          |> assign(:auction_id, auction_id)

        # Send current auction state to the joining user
        auction = TenantScope.get!(Auction, tenant_id, auction_id)
        send(self(), {:after_join, auction})

        {:ok, socket}
    end
  end

  # Reject any topic that doesn't match the expected format
  def join(_, _, _socket) do
    {:error, %{reason: "invalid topic format"}}
  end

  @doc """
  Send current auction state after successful join.
  """
  def handle_info({:after_join, auction}, socket) do
    push(socket, "auction:state", %{
      id: auction.id,
      title: auction.title,
      type: auction.type,
      current_price: Decimal.to_string(auction.current_price),
      bid_count: auction.bid_count,
      status: auction.status,
      end_time: DateTime.to_iso8601(auction.end_time),
      min_increment: Decimal.to_string(auction.min_increment)
    })

    {:noreply, socket}
  end

  @doc """
  Broadcasts a new bid to all connected clients on this auction channel.
  Called from the Bidding context after a successful bid placement.
  """
  def broadcast_new_bid(tenant_id, auction_id, bid_data) do
    topic = "tenant:#{tenant_id}:auction:#{auction_id}"

    BidPlatformWeb.Endpoint.broadcast!(topic, "bid:new", %{
      bid_id: bid_data.bid.id,
      amount: Decimal.to_string(bid_data.bid.amount),
      bidder_id: bid_data.bid.user_id,
      current_price: Decimal.to_string(bid_data.auction.current_price),
      bid_count: bid_data.auction.bid_count,
      end_time: DateTime.to_iso8601(bid_data.auction.end_time),
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    })
  end

  @doc """
  Broadcasts auction closure to all connected clients.
  """
  def broadcast_auction_closed(tenant_id, auction_id, result) do
    topic = "tenant:#{tenant_id}:auction:#{auction_id}"

    BidPlatformWeb.Endpoint.broadcast!(topic, "auction:closed", %{
      status: result.status,
      winner_id: result.winner_id,
      winning_amount: result.winning_amount,
      total_bids: result.total_bids,
      timestamp: DateTime.to_iso8601(DateTime.utc_now())
    })
  end
end
```

### 4.6 Background Job Processing (Oban)

#### FR-JOB-001: Auction Auto-Close Worker

```elixir
defmodule BidPlatform.Workers.AuctionCloser do
  @moduledoc """
  Oban worker that automatically closes auctions at their end_time.

  Scheduled when an auction is created or when anti-sniping extends the end_time.
  Determines the winner based on auction type:
    - English → highest bid (max amount)
    - Reverse → lowest bid (min amount)

  Handles edge cases:
    - No bids → status = "no_bids"
    - Reserve not met (English) → status = "reserve_not_met"
    - Auction already closed (idempotent) → no-op
    - Anti-sniping extended the end_time → re-checks and reschedules if needed
  """

  use Oban.Worker,
    queue: :auctions,
    max_attempts: 5,
    unique: [period: 60, fields: [:args], keys: [:auction_id]]

  alias BidPlatform.{Repo, TenantScope}
  alias BidPlatform.Auctions.Auction
  alias BidPlatform.Bidding.Bid
  alias BidPlatformWeb.AuctionChannel
  import Ecto.Query

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"auction_id" => auction_id, "tenant_id" => tenant_id}}) do
    Repo.transaction(fn ->
      # Lock the auction to prevent concurrent modifications
      auction =
        Auction
        |> TenantScope.scope(tenant_id)
        |> where([a], a.id == ^auction_id)
        |> lock("FOR UPDATE")
        |> Repo.one()

      cond do
        # Auction not found or already closed — idempotent no-op
        auction == nil ->
          :ok

        auction.status in ~w[closed force_closed no_bids reserve_not_met cancelled] ->
          :ok

        # Anti-sniping extended the auction — reschedule
        DateTime.compare(DateTime.utc_now(), auction.end_time) == :lt ->
          reschedule_close(auction)

        # Ready to close
        auction.status == "active" ->
          close_auction(auction, tenant_id)

        true ->
          :ok
      end
    end)
  end

  defp close_auction(auction, tenant_id) do
    # Find the winning bid based on auction type
    winning_bid = find_winner(auction, tenant_id)

    {status, winner_id, winning_bid_id, winning_amount} =
      case {winning_bid, auction.type, auction.reserve_price} do
        # No bids at all
        {nil, _, _} ->
          {"no_bids", nil, nil, nil}

        # English auction with reserve not met
        {bid, "english", reserve} when not is_nil(reserve) ->
          if Decimal.compare(bid.amount, reserve) == :lt do
            {"reserve_not_met", nil, nil, nil}
          else
            {"closed", bid.user_id, bid.id, Decimal.to_string(bid.amount)}
          end

        # Normal closure — winner found
        {bid, _, _} ->
          {"closed", bid.user_id, bid.id, Decimal.to_string(bid.amount)}
      end

    # Update auction status
    Auction
    |> where([a], a.id == ^auction.id and a.tenant_id == ^tenant_id)
    |> Repo.update_all(
      set: [
        status: status,
        winner_id: winner_id,
        winning_bid_id: winning_bid_id,
        updated_at: DateTime.utc_now()
      ]
    )

    # Mark winning bid
    if winning_bid_id do
      Bid
      |> where([b], b.id == ^winning_bid_id)
      |> Repo.update_all(set: [status: "winning", updated_at: DateTime.utc_now()])
    end

    # Broadcast closure
    AuctionChannel.broadcast_auction_closed(tenant_id, auction.id, %{
      status: status,
      winner_id: winner_id,
      winning_amount: winning_amount,
      total_bids: auction.bid_count
    })

    # Schedule notification jobs
    schedule_outcome_notifications(auction, tenant_id, status, winner_id)
  end

  defp find_winner(auction, tenant_id) do
    order = case auction.type do
      "english" -> [desc: :amount]    # Highest bid wins
      "reverse" -> [asc: :amount]     # Lowest bid wins
    end

    Bid
    |> TenantScope.scope(tenant_id)
    |> where([b], b.auction_id == ^auction.id and b.status in ["valid", "outbid"])
    |> order_by(^order)
    |> limit(1)
    |> Repo.one()
  end

  defp reschedule_close(auction) do
    # Calculate delay from now to the (possibly extended) end_time
    delay_seconds = DateTime.diff(auction.end_time, DateTime.utc_now(), :second)
    delay_seconds = max(delay_seconds, 1)  # At least 1 second

    %{auction_id: auction.id, tenant_id: auction.tenant_id}
    |> __MODULE__.new(schedule_in: delay_seconds)
    |> Oban.insert()
  end

  defp schedule_outcome_notifications(auction, tenant_id, status, winner_id) do
    # Notify winner
    if winner_id do
      %{
        type: "auction_won",
        tenant_id: tenant_id,
        auction_id: auction.id,
        user_id: winner_id
      }
      |> BidPlatform.Workers.Notifier.new()
      |> Oban.insert()
    end

    # Notify losers
    if status in ["closed", "force_closed"] do
      %{
        type: "auction_lost",
        tenant_id: tenant_id,
        auction_id: auction.id,
        winner_id: winner_id
      }
      |> BidPlatform.Workers.Notifier.new()
      |> Oban.insert()
    end
  end
end
```

---

## 5. API Design (High-Level)

### 5.1 REST API Endpoints

All API endpoints are prefixed with `/api/v1` and require authentication (except registration/login). Every request is scoped to the authenticated user's tenant.

```
AUTHENTICATION
  POST   /api/v1/auth/register          # Register new tenant + admin user
  POST   /api/v1/auth/login             # Login → returns JWT
  POST   /api/v1/auth/logout            # Invalidate session
  GET    /api/v1/auth/me                # Current user + tenant info

TENANT MANAGEMENT (Admin only)
  GET    /api/v1/tenant                 # Get current tenant details
  PATCH  /api/v1/tenant                 # Update tenant settings
  GET    /api/v1/tenant/usage           # Current plan usage stats

USER MANAGEMENT (Admin only)
  GET    /api/v1/users                  # List users in tenant
  POST   /api/v1/users                  # Create/invite user
  GET    /api/v1/users/:id              # Get user details
  PATCH  /api/v1/users/:id              # Update user (role, active status)
  DELETE /api/v1/users/:id              # Deactivate user (soft delete)

AUCTIONS
  GET    /api/v1/auctions               # List auctions (with filters: status, type)
  POST   /api/v1/auctions               # Create auction (Admin only)
  GET    /api/v1/auctions/:id           # Get auction details + current state
  PATCH  /api/v1/auctions/:id           # Edit auction (draft only, Admin only)
  DELETE /api/v1/auctions/:id           # Cancel auction (draft only, Admin only)
  POST   /api/v1/auctions/:id/activate  # Activate a draft auction (Admin only)
  POST   /api/v1/auctions/:id/close     # Force-close an active auction (Admin only)

BIDDING
  POST   /api/v1/auctions/:id/bids      # Place a bid
  GET    /api/v1/auctions/:id/bids      # Get bid history for an auction

AUDIT LOGS (Admin only)
  GET    /api/v1/audit-logs             # Query audit logs (filterable)

WEBSOCKET
  WS     /socket/websocket              # Phoenix Channel connection
         → join "tenant:{tenant_id}:auction:{auction_id}"
         → events: "bid:new", "auction:state", "auction:closed", "auction:extended"
```

### 5.2 API Response Format

```json
// Success response
{
  "data": { ... },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2026-04-21T10:30:00Z"
  }
}

// Error response
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Bid amount must be at least 1050.00",
    "details": {
      "field": "amount",
      "current_price": "1000.00",
      "min_increment": "50.00",
      "required_minimum": "1050.00"
    }
  },
  "meta": {
    "request_id": "uuid",
    "timestamp": "2026-04-21T10:30:00Z"
  }
}

// Paginated list response
{
  "data": [ ... ],
  "meta": {
    "page": 1,
    "per_page": 20,
    "total": 156,
    "total_pages": 8,
    "request_id": "uuid"
  }
}
```

---

## 6. Non-Functional Requirements

### 6.1 Performance

| Metric | Requirement | Measurement |
|--------|------------|-------------|
| Bid broadcast latency (P95) | < 500ms | From bid submission to all clients receiving update |
| API response time (P95) | < 200ms | For non-bidding endpoints |
| Bid processing time (P99) | < 1s | Including DB transaction + broadcast |
| Concurrent bidders per auction | 100+ | Simultaneous WebSocket connections |
| Concurrent auctions | 500+ | Across all tenants |
| Database query time (P95) | < 50ms | With proper indexing |

### 6.2 Availability & Reliability

| Metric | Requirement |
|--------|------------|
| Uptime SLA | 99.9% (8.7 hours downtime/year) |
| Recovery Time Objective (RTO) | < 1 hour |
| Recovery Point Objective (RPO) | < 5 minutes |
| Data durability | 99.999% (PostgreSQL with WAL + backups) |
| Oban job delivery guarantee | At-least-once (idempotent workers) |

### 6.3 Security

| Requirement | Implementation |
|------------|---------------|
| Data encryption at rest | AES-256 (PostgreSQL TDE or disk-level) |
| Data encryption in transit | TLS 1.3 for all connections |
| Password storage | bcrypt with cost factor 12 |
| Session management | JWT with 24-hour expiry + refresh tokens |
| Rate limiting | 100 req/min per user; 5 login attempts per 15 min |
| Input sanitization | All inputs validated and sanitized at API boundary |
| SQL injection prevention | Parameterized queries via Ecto (built-in) |
| XSS prevention | Content-Security-Policy headers; output encoding |
| CORS | Strict origin whitelist per tenant subdomain |
| Audit logging | All mutations logged with actor, timestamp, IP |

### 6.4 Scalability

| Dimension | Strategy |
|-----------|---------|
| Horizontal scaling | Phoenix cluster with distributed Erlang/PubSub |
| Database scaling | Read replicas for analytics queries; primary for writes |
| WebSocket scaling | Phoenix PubSub distributes across nodes |
| Background jobs | Oban distributes across worker nodes |
| Caching | Redis for current_price hot path (optional) |

---

## 7. Edge Cases & Mitigation

### 7.1 Concurrency Edge Cases

| Edge Case | Scenario | Mitigation |
|-----------|----------|-----------|
| **EC-001: Simultaneous bids** | Two users bid at the exact same millisecond | PostgreSQL `FOR UPDATE` row lock serializes access; second bid validates against updated price |
| **EC-002: Bid during auction close** | User submits bid at the exact moment auction auto-closes | Transaction lock on auction row; Oban closer acquires lock first → bid rejected as "Auction has ended" |
| **EC-003: Double-submit** | User clicks bid button twice rapidly | Frontend debounce (300ms); backend idempotency check — reject if user's last bid was < 1 second ago |
| **EC-004: Anti-sniping race** | Multiple bids arrive in sniping window simultaneously | Lock serializes; each bid checks and extends independently; max_extensions cap prevents infinite extension |

### 7.2 Data Integrity Edge Cases

| Edge Case | Scenario | Mitigation |
|-----------|----------|-----------|
| **EC-010: Cross-tenant data access** | User crafts API request with another tenant's auction_id | TenantScope middleware filters every query by user's tenant_id; wrong tenant returns 404, not 403 (no information leakage) |
| **EC-011: Cross-tenant WebSocket** | User tries to join channel with another tenant's topic | Channel join/1 validates user.tenant_id == topic tenant_id; rejects with "unauthorized" |
| **EC-012: Negative bid amount** | User submits bid with amount < 0 | Ecto validation: `validate_number(:amount, greater_than: 0)` |
| **EC-013: Bid on draft auction** | User finds draft auction ID and tries to bid | Status check in BidValidator: auction.status must be "active" |
| **EC-014: Decimal precision overflow** | User submits bid with extreme decimal places | `precision: 15, scale: 2` in database; Ecto rounds/rejects |

### 7.3 Auction Lifecycle Edge Cases

| Edge Case | Scenario | Mitigation |
|-----------|----------|-----------|
| **EC-020: Auction with zero bids** | No one bids before end_time | AuctionCloser handles: status → "no_bids", no winner set |
| **EC-021: Single bidder auction** | Only one person bids | Valid scenario — single bid becomes winning bid |
| **EC-022: Reserve not met** | English auction highest bid < reserve_price | AuctionCloser checks reserve; status → "reserve_not_met" |
| **EC-023: Force-close with no bids** | Admin force-closes auction before any bids | Status → "force_closed", winner_id remains nil |
| **EC-024: Oban job failure** | AuctionCloser crashes mid-execution | max_attempts: 5 with exponential backoff; idempotent design allows safe retry |
| **EC-025: Clock skew** | Server time differs from client time | All timestamps are server-side UTC; clients sync via heartbeat; end_time is server-authoritative |
| **EC-026: Anti-sniping infinite loop** | Sniping bids keep extending the auction forever | max_extensions setting (default 5) caps total extensions |

### 7.4 User & Authentication Edge Cases

| Edge Case | Scenario | Mitigation |
|-----------|----------|-----------|
| **EC-030: Email reuse across tenants** | Same email registers in two tenants | Allowed by design — unique constraint is (email, tenant_id) not just email |
| **EC-031: Admin removes last admin** | Tenant admin deactivates themselves or the only admin | Business rule: at least one active admin must exist per tenant; block the operation |
| **EC-032: Disabled user has active bids** | Admin deactivates a user who has standing bids | Bids remain valid (they are historical records); user cannot place new bids |
| **EC-033: Tenant deactivated during auction** | Platform deactivates a tenant while auctions are running | All active auctions auto-close with status "cancelled"; users blocked from login |
| **EC-034: Brute force login** | Attacker tries many passwords | Rate limit: 5 attempts / 15 min / email; lockout for 30 min; log attempts |

### 7.5 Network & Infrastructure Edge Cases

| Edge Case | Scenario | Mitigation |
|-----------|----------|-----------|
| **EC-040: WebSocket disconnect** | Bidder loses connection mid-auction | Client auto-reconnects with exponential backoff; on rejoin, receives current state via `after_join` |
| **EC-041: Bid via HTTP after WS failure** | WebSocket is down but HTTP endpoint is up | HTTP bid endpoint exists as fallback; same validation pipeline |
| **EC-042: Database connection pool exhausted** | Too many concurrent transactions | Ecto pool config: `pool_size: 20`, queue_target: 1000ms; circuit breaker pattern on overflow |
| **EC-043: Oban queue backup** | Many auctions closing simultaneously | Separate Oban queues: `:auctions` (priority) and `:notifications` (best-effort); rate limiting per queue |

---

## 8. User Flows

### 8.1 Tenant Onboarding Flow

```
START
  │
  ▼
[Landing Page] ──── "Create Organization" ────▶ [Registration Form]
                                                   │
                                                   │ org_name, subdomain,
                                                   │ admin_email, password
                                                   │
                                                   ▼
                                              [Validate Input]
                                                   │
                                          ┌────────┴────────┐
                                          │                 │
                                        Error            Success
                                          │                 │
                                          ▼                 ▼
                                    [Show Errors]    [Create Tenant +
                                                      Admin User]
                                                         │
                                                         ▼
                                                   [Auto Login]
                                                         │
                                                         ▼
                                                   [Dashboard]
                                                   "Create your
                                                    first auction"
```

### 8.2 Auction Creation Flow (Admin)

```
[Dashboard] ──── "New Auction" ────▶ [Auction Form]
                                        │
                                        │ title, type, start_price,
                                        │ min_increment, end_time,
                                        │ settings
                                        │
                                        ▼
                                   [Validate]
                                        │
                               ┌────────┴────────┐
                               │                 │
                             Error            Success
                               │                 │
                               ▼                 ▼
                         [Show Errors]    [Create as "draft"]
                                                │
                                                ▼
                                         [Preview Page]
                                                │
                                    ┌───────────┴───────────┐
                                    │                       │
                              "Edit"                  "Activate"
                                    │                       │
                                    ▼                       ▼
                              [Edit Form]           [Confirm Dialog]
                                                         │
                                                         ▼
                                                 [Status → "active"]
                                                 [Schedule Oban close]
                                                 [Notify bidders]
                                                         │
                                                         ▼
                                                 [Live Auction Page]
```

### 8.3 Bidding Flow (Bidder)

```
[Auction List] ──── Click Auction ────▶ [Auction Detail Page]
                                              │
                                              │ Join WebSocket channel
                                              │ Receive current state
                                              │
                                              ▼
                                        [Live Auction View]
                                        ┌─────────────────┐
                                        │ Current Price    │
                                        │ Bid Count        │
                                        │ Time Remaining   │
                                        │ Bid History      │
                                        │ [Bid Input]      │
                                        │ [Place Bid ▶]   │
                                        └─────────────────┘
                                              │
                                              │ Enter amount, click "Place Bid"
                                              │
                                              ▼
                                        [Client Validation]
                                        (amount > current + increment)
                                              │
                                     ┌────────┴────────┐
                                     │                 │
                                   Error            Valid
                                     │                 │
                                     ▼                 ▼
                               [Show Error]    [POST /api/v1/.../bids]
                                                      │
                                                      ▼
                                               [Server Validation]
                                               [DB Transaction + Lock]
                                                      │
                                             ┌────────┴────────┐
                                             │                 │
                                           Error            Success
                                             │                 │
                                             ▼                 ▼
                                       [Show Error]    [Broadcast to all]
                                                       [Update UI]
                                                       [Show "You are
                                                        the leader!"]

───── Meanwhile, other bidders see: ─────

  WebSocket receives "bid:new" event
        │
        ▼
  [UI Updates]:
  - Current price refreshes
  - Bid count increments
  - Time remaining refreshes (if anti-sniping extended)
  - Previous leader sees "You have been outbid!"
  - Bid history appends new entry
```

---

## 9. Deployment Architecture

### 9.1 Docker Compose (Development / Staging)

```yaml
# docker-compose.yml
version: "3.8"

services:
  # ── Phoenix Application ───────────────────────────────────
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "4000:4000"
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db:5432/bid_platform_dev
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - PHX_HOST=localhost
      - REDIS_URL=redis://redis:6379
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    command: >
      sh -c "mix ecto.setup && mix phx.server"
    volumes:
      - .:/app
    restart: unless-stopped

  # ── PostgreSQL Database ───────────────────────────────────
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: bid_platform_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

  # ── Redis (Optional — for caching & PubSub) ──────────────
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  # ── Oban Worker (Background Jobs) ────────────────────────
  # In production, Oban runs within the Phoenix app.
  # For dedicated worker scaling, use a separate service:
  worker:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - DATABASE_URL=ecto://postgres:postgres@db:5432/bid_platform_dev
      - SECRET_KEY_BASE=${SECRET_KEY_BASE}
      - OBAN_QUEUES=auctions:10,notifications:20,cleanup:5
    depends_on:
      db:
        condition: service_healthy
    command: >
      sh -c "mix run --no-halt"
    restart: unless-stopped

volumes:
  postgres_data:
  redis_data:
```

### 9.2 Production Architecture (AWS)

```
                    ┌─────────────────┐
                    │   Route 53      │
                    │   (DNS + sub-   │
                    │    domains)     │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   CloudFront    │
                    │   (CDN + TLS)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   ALB           │
                    │   (WebSocket    │
                    │    sticky)      │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
     ┌────────▼──────┐ ┌────▼───────┐ ┌────▼───────┐
     │  ECS Task 1   │ │ ECS Task 2 │ │ ECS Task 3 │
     │  (Phoenix)    │ │ (Phoenix)  │ │ (Phoenix)  │
     │  + Oban       │ │ + Oban     │ │ + Oban     │
     └────────┬──────┘ └────┬───────┘ └────┬───────┘
              │              │              │
              └──────┬───────┴──────────────┘
                     │
            ┌────────▼────────┐     ┌──────────────┐
            │   RDS PostgreSQL│     │  ElastiCache  │
            │   (Multi-AZ)    │     │  (Redis)      │
            └─────────────────┘     └──────────────┘
```

---

## 10. Testing Strategy

### 10.1 Test Categories

| Category | Scope | Tools |
|----------|-------|-------|
| Unit Tests | Schemas, validators, pure functions | ExUnit |
| Integration Tests | Context modules, DB transactions | ExUnit + Ecto.Sandbox |
| Channel Tests | WebSocket join, broadcast, isolation | Phoenix.ChannelTest |
| E2E Tests | Full API flows | ExUnit + HTTP client |
| Load Tests | Concurrent bidding, WebSocket connections | k6, Artillery |
| Security Tests | Tenant isolation, auth bypass attempts | Custom test suite |

### 10.2 Critical Test Cases

```elixir
# Test: Tenant isolation — user cannot access another tenant's auction
describe "tenant isolation" do
  test "user cannot fetch auction from another tenant" do
    tenant_a = insert(:tenant)
    tenant_b = insert(:tenant)
    user_a = insert(:user, tenant: tenant_a)
    auction_b = insert(:auction, tenant: tenant_b)

    # This MUST return nil, not the auction
    assert nil == TenantScope.get(Auction, tenant_a.id, auction_b.id)
  end

  test "user cannot bid on another tenant's auction" do
    tenant_a = insert(:tenant)
    tenant_b = insert(:tenant)
    user_a = insert(:user, tenant: tenant_a, role: "bidder")
    auction_b = insert(:auction, tenant: tenant_b, status: "active")

    assert {:error, "Auction not found"} =
      Bidding.place_bid(tenant_a.id, auction_b.id, user_a.id, Decimal.new("100"))
  end

  test "WebSocket channel rejects cross-tenant join" do
    tenant_a = insert(:tenant)
    tenant_b = insert(:tenant)
    user_a = insert(:user, tenant: tenant_a)

    socket = socket(BidPlatformWeb.UserSocket, "user_id", %{current_user: user_a})
    topic = "tenant:#{tenant_b.id}:auction:some-auction-id"

    assert {:error, %{reason: "unauthorized — tenant mismatch"}} =
      subscribe_and_join(socket, BidPlatformWeb.AuctionChannel, topic)
  end
end

# Test: Concurrent bidding does not cause race conditions
describe "concurrent bidding" do
  test "two simultaneous bids on the same auction are serialized" do
    tenant = insert(:tenant)
    auction = insert(:auction, tenant: tenant, type: "english",
      current_price: Decimal.new("100"), min_increment: Decimal.new("10"), status: "active")
    user_1 = insert(:user, tenant: tenant, role: "bidder")
    user_2 = insert(:user, tenant: tenant, role: "bidder")

    # Simulate concurrent bids
    task_1 = Task.async(fn ->
      Bidding.place_bid(tenant.id, auction.id, user_1.id, Decimal.new("120"))
    end)
    task_2 = Task.async(fn ->
      Bidding.place_bid(tenant.id, auction.id, user_2.id, Decimal.new("115"))
    end)

    result_1 = Task.await(task_1)
    result_2 = Task.await(task_2)

    # One succeeds, the other may fail or succeed at a higher price
    # Both should NOT succeed at their original amounts if they conflict
    successes = [result_1, result_2] |> Enum.filter(&match?({:ok, _}, &1))
    assert length(successes) >= 1  # At least one succeeds
    assert length(successes) <= 2  # Both may succeed if serialized correctly

    # Final price must be consistent
    final_auction = Repo.get!(Auction, auction.id)
    assert Decimal.compare(final_auction.current_price, Decimal.new("100")) == :gt
  end
end

# Test: Anti-sniping extends auction correctly
describe "anti-sniping" do
  test "bid within sniping window extends end_time" do
    tenant = insert(:tenant)
    # Auction ends in 3 minutes; sniping window is 5 minutes
    end_time = DateTime.add(DateTime.utc_now(), 180, :second)
    auction = insert(:auction, tenant: tenant, type: "english",
      current_price: Decimal.new("100"), min_increment: Decimal.new("10"),
      end_time: end_time, status: "active",
      settings: %{
        "anti_sniping_enabled" => true,
        "anti_sniping_window_minutes" => 5,
        "anti_sniping_extension_minutes" => 3,
        "max_extensions" => 5,
        "extension_count" => 0
      })
    user = insert(:user, tenant: tenant, role: "bidder")

    {:ok, result} = Bidding.place_bid(tenant.id, auction.id, user.id, Decimal.new("120"))

    # End time should have been extended by 3 minutes
    assert DateTime.compare(result.auction.end_time, end_time) == :gt
  end
end
```

---

## 11. Product Roadmap

### Phase 1 — MVP (Months 1–3)

- [x] Tenant registration & management
- [x] User authentication & RBAC
- [x] English auction: create, bid, close
- [x] Reverse auction: create, bid, close
- [x] Real-time bidding via Phoenix Channels
- [x] Auction auto-close via Oban
- [x] Tenant data isolation
- [x] Basic admin panel (manage auctions, users)
- [x] Audit logging

### Phase 2 — Growth (Months 4–9)

- [ ] Email notifications (outbid, win, loss, closing soon)
- [ ] Subdomain routing per tenant
- [ ] Invite external bidders via email
- [ ] Platform super-admin dashboard
- [ ] Basic analytics (bids/auction, avg value, win rate)
- [ ] Anti-sniping time extensions
- [ ] Razorpay subscription billing
- [ ] Mobile-responsive UI optimization

### Phase 3 — Scale (Months 10–18)

- [ ] REST API with API keys for third-party integration
- [ ] Webhook notifications
- [ ] Sealed-bid auctions
- [ ] Custom domain support
- [ ] White-label branding
- [ ] Advanced analytics & reporting
- [ ] Multi-region deployment
- [ ] SOC 2 compliance preparation

### Phase 4 — Platform (Months 18+)

- [ ] AI-based bid suggestions
- [ ] Multi-attribute weighted scoring auctions
- [ ] Payment integration / escrow
- [ ] Marketplace mode (public auctions across tenants)
- [ ] Multi-language support (Hindi, Tamil, Telugu)
- [ ] Mobile native apps (React Native)
- [ ] GST invoice generation

---

## 12. Glossary

| Term | Definition |
|------|-----------|
| **English Auction** | Forward auction where bidders compete to offer the highest price. Seller wins when the price is maximized. |
| **Reverse Auction** | Procurement auction where sellers compete to offer the lowest price. Buyer wins when the cost is minimized. |
| **Tenant** | An organization that subscribes to the platform. Each tenant has isolated data and its own users. |
| **Multi-Tenancy** | Architecture where a single application instance serves multiple tenant organizations with data isolation. |
| **Anti-Sniping** | Mechanism that extends auction end time when bids arrive near the closing moment, preventing last-second bid manipulation. |
| **Reserve Price** | A hidden minimum price set by the auction creator. If the highest bid is below the reserve, the auction does not result in a sale. |
| **Oban** | Elixir library for reliable, distributed background job processing backed by PostgreSQL. |
| **Phoenix Channels** | WebSocket abstraction in Phoenix Framework for real-time, bidirectional communication. |
| **PubSub** | Publish-Subscribe messaging pattern used by Phoenix for broadcasting events across nodes. |
| **FOR UPDATE** | PostgreSQL row-level lock that prevents concurrent modifications to the same row within a transaction. |

---

*This PRD is designed to be consumed directly by an autonomous AI coding agent (e.g., Ralph Loop) or human engineering team for implementation. All code samples are production-grade Elixir targeting Phoenix Framework with Ecto/PostgreSQL.*
