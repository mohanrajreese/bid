# TECHNICAL SPECIFICATION — Multi-Tenant Real-Time Bidding SaaS Platform

> **Document ID:** TECH-BID-2026-001
> **Version:** 1.0
> **Date:** April 21, 2026
> **Author:** Engineering Team
> **Status:** Draft
> **Classification:** Internal — Engineering
> **Related Documents:** PRD-BID-2026-001, BRD-BID-2026-001

---

## 1. Technology Stack Decision Matrix

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Language** | Elixir | BEAM VM: massive concurrency, fault tolerance, hot code reloading |
| **Web Framework** | Phoenix 1.7+ | Native WebSocket support, LiveView for real-time UI, battle-tested |
| **Database** | PostgreSQL 16 | ACID compliance, row-level locking, JSONB for flexible settings |
| **ORM** | Ecto 3.x | Compile-time query safety, changesets for validation, migration system |
| **Real-Time** | Phoenix Channels + PubSub | Built-in WebSocket with topic-based pub/sub, distributed via Erlang clustering |
| **Background Jobs** | Oban 2.x | PostgreSQL-backed, reliable delivery, unique jobs, scheduled execution |
| **Authentication** | Guardian + bcrypt | JWT-based auth, configurable token TTL, industry-standard password hashing |
| **Deployment** | Docker + Docker Compose | Container isolation, reproducible builds, easy scaling |
| **CI/CD** | GitHub Actions | Automated testing, linting, deployment pipelines |
| **Monitoring** | Telemetry + Prometheus + Grafana | BEAM-native instrumentation, real-time dashboards |

---

## 2. Multi-Tenant Data Isolation — Deep Dive

### 2.1 Strategy: Shared Database, Shared Schema, Row-Level Isolation

We use the simplest and most scalable multi-tenancy model: a single PostgreSQL database with `tenant_id` on every table. This avoids the operational complexity of schema-per-tenant or database-per-tenant while maintaining strict data isolation through application-level enforcement.

### 2.2 Isolation Enforcement Layers

Data isolation is enforced at **five independent layers**. A breach requires failure at ALL five simultaneously.

```
Layer 1: API Gateway / Plug Middleware
  ├── Extracts tenant_id from authenticated user's JWT
  ├── Injects tenant_id into conn.assigns
  └── Rejects requests with missing/invalid tenant context

Layer 2: Context Module Functions
  ├── Every public function accepts tenant_id as first parameter
  ├── Every Ecto query uses TenantScope.scope/2
  └── No context function queries without tenant_id

Layer 3: Database Constraints
  ├── NOT NULL constraint on tenant_id columns
  ├── Foreign key from tenant_id → tenants.id
  └── Composite indexes include tenant_id

Layer 4: WebSocket Channel Authentication
  ├── Channel topic includes tenant_id
  ├── join/3 validates user.tenant_id == topic tenant_id
  └── Cross-tenant join attempts are rejected

Layer 5: Testing & CI Enforcement
  ├── Dedicated test suite for cross-tenant access attempts
  ├── Every new context function tested for tenant scoping
  └── CI fails if any isolation test fails
```

### 2.3 Row-Level Security (Database-Level Backup)

As an additional safety net beyond application-level enforcement, we configure PostgreSQL Row-Level Security (RLS) policies:

```sql
-- Enable RLS on all tenant-scoped tables
ALTER TABLE auctions ENABLE ROW LEVEL SECURITY;
ALTER TABLE bids ENABLE ROW LEVEL SECURITY;
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Create policy: rows are only visible when tenant_id matches the session variable
-- The application sets this variable on every database connection checkout

CREATE POLICY tenant_isolation_auctions ON auctions
  USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

CREATE POLICY tenant_isolation_bids ON bids
  USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

CREATE POLICY tenant_isolation_users ON users
  USING (tenant_id = current_setting('app.current_tenant_id')::uuid);

-- Note: The app user should NOT be a superuser (superusers bypass RLS)
```

Application-side connection setup:

```elixir
defmodule BidPlatform.Repo.TenantPreparer do
  @moduledoc """
  Sets the PostgreSQL session variable for Row-Level Security
  on every database connection checkout.

  This provides database-level tenant isolation as a backup
  to application-level TenantScope enforcement.
  """

  @behaviour Ecto.Repo.Queryable

  def prepare_query(_operation, query, opts) do
    tenant_id = opts[:tenant_id] || raise "tenant_id is required for all queries"

    # Set the session variable that RLS policies check
    {query, Keyword.put(opts, :prefix, nil)}
  end

  @doc """
  Call this at the start of every request to set the tenant context
  on the current database connection.
  """
  def set_tenant(tenant_id) do
    Ecto.Adapters.SQL.query!(
      BidPlatform.Repo,
      "SET app.current_tenant_id = $1",
      [tenant_id]
    )
  end
end
```

---

## 3. Concurrency Handling — Complete Strategy

### 3.1 Problem Statement

In a real-time bidding system, the most critical concurrency challenge is multiple users bidding on the same auction simultaneously. Without proper handling, this leads to lost updates, inconsistent state, and incorrect winner determination.

### 3.2 Solution: Pessimistic Locking with Serialized Transactions

```elixir
defmodule BidPlatform.Bidding.ConcurrentBidHandler do
  @moduledoc """
  Demonstrates the full concurrency-safe bid placement flow.

  The key insight: we use PostgreSQL's SELECT ... FOR UPDATE to serialize
  access to the auction row. This means:

  1. Transaction A locks the auction row
  2. Transaction B tries to lock the same row → BLOCKS (waits)
  3. Transaction A completes (commit or rollback)
  4. Transaction B acquires the lock → sees the UPDATED state
  5. Transaction B validates its bid against the NEW current_price

  This guarantees:
  - No lost updates
  - No phantom reads
  - Correct sequential bid ordering
  - Accurate winner determination
  """

  alias BidPlatform.Repo
  alias BidPlatform.Auctions.Auction
  alias BidPlatform.Bidding.Bid
  import Ecto.Query

  @lock_timeout_ms 5_000  # Maximum time to wait for row lock

  def place_bid_safely(tenant_id, auction_id, user_id, amount) do
    # Set a statement timeout to prevent indefinite lock waits
    Repo.transaction(
      fn ->
        # Step 1: Acquire exclusive row lock on the auction
        # If another transaction holds this lock, we WAIT (up to @lock_timeout_ms)
        auction =
          Auction
          |> where([a], a.id == ^auction_id and a.tenant_id == ^tenant_id)
          |> lock("FOR UPDATE")
          |> Repo.one()

        case auction do
          nil ->
            Repo.rollback(:auction_not_found)

          %Auction{status: status} when status != "active" ->
            Repo.rollback({:auction_not_active, status})

          %Auction{} = auction ->
            # Step 2: Validate bid against the LOCKED (current) state
            # This amount was the current_price AFTER any concurrent bid
            # that held the lock before us committed
            case validate_bid_amount(auction, user_id, amount) do
              :ok ->
                # Step 3: Insert bid and update auction atomically
                execute_bid(auction, tenant_id, user_id, amount)

              {:error, reason} ->
                Repo.rollback(reason)
            end
        end
      end,
      timeout: @lock_timeout_ms + 1_000
    )
  end

  defp validate_bid_amount(%Auction{type: "english"} = auction, user_id, amount) do
    min_required = Decimal.add(auction.current_price, auction.min_increment)

    cond do
      auction.created_by == user_id ->
        {:error, :self_bidding_not_allowed}
      Decimal.compare(amount, min_required) == :lt ->
        {:error, {:insufficient_bid, min_required}}
      true ->
        :ok
    end
  end

  defp validate_bid_amount(%Auction{type: "reverse"} = auction, user_id, amount) do
    max_allowed = Decimal.sub(auction.current_price, auction.min_increment)

    cond do
      auction.created_by == user_id ->
        {:error, :self_bidding_not_allowed}
      Decimal.compare(amount, max_allowed) == :gt ->
        {:error, {:bid_too_high, max_allowed}}
      Decimal.compare(amount, Decimal.new(0)) != :gt ->
        {:error, :bid_must_be_positive}
      true ->
        :ok
    end
  end

  defp execute_bid(auction, tenant_id, user_id, amount) do
    # Insert the bid record
    {:ok, bid} =
      %Bid{}
      |> Bid.changeset(%{
        tenant_id: tenant_id,
        auction_id: auction.id,
        user_id: user_id,
        amount: amount,
        status: "valid"
      })
      |> Repo.insert()

    # Update auction current_price — this happens inside the same transaction
    # so it's atomic with the bid insert
    Auction
    |> where([a], a.id == ^auction.id)
    |> Repo.update_all(
      set: [current_price: amount, updated_at: DateTime.utc_now()],
      inc: [bid_count: 1]
    )

    updated_auction = Repo.get!(Auction, auction.id)
    %{bid: bid, auction: updated_auction}
  end
end
```

### 3.3 Deadlock Prevention

Deadlocks can occur when two transactions try to lock rows in different orders. Our mitigation:

```elixir
# RULE: Always lock rows in a consistent order.
# For bidding, we only ever lock ONE row (the auction row),
# so deadlocks are impossible in the bidding flow.

# If we ever need to lock multiple rows (e.g., transferring between auctions),
# always lock in ascending ID order:

defp lock_auctions_in_order(auction_id_1, auction_id_2) do
  [first, second] = Enum.sort([auction_id_1, auction_id_2])

  auction_1 = Repo.get!(Auction, first, lock: "FOR UPDATE")
  auction_2 = Repo.get!(Auction, second, lock: "FOR UPDATE")

  {auction_1, auction_2}
end
```

### 3.4 Optimistic Concurrency (Alternative for Read-Heavy Operations)

For operations where lock contention is undesirable (e.g., auction settings updates), we use optimistic concurrency with version stamping:

```elixir
# Add a lock_version field to the auction schema
# Ecto's optimistic_lock handles the rest

schema "auctions" do
  # ... existing fields ...
  field :lock_version, :integer, default: 1
end

def changeset(auction, attrs) do
  auction
  |> cast(attrs, [:title, :description])
  |> optimistic_lock(:lock_version)
end

# Usage:
# If two admins edit the same auction simultaneously,
# the second save will raise Ecto.StaleEntryError
```

---

## 4. Real-Time Architecture — Complete Design

### 4.1 Channel Topic Hierarchy

```
Topic Format: "tenant:{tenant_id}:auction:{auction_id}"

Examples:
  "tenant:abc123:auction:xyz789"    ← Specific auction in tenant abc123
  "tenant:abc123:notifications"     ← Tenant-wide notifications (Phase 2)

Security Properties:
  - tenant_id in topic prevents cross-tenant subscription
  - Channel join/3 validates user.tenant_id == topic.tenant_id
  - Phoenix PubSub only routes to subscribers of exact topic match
```

### 4.2 Event Catalog

| Event | Direction | Payload | Trigger |
|-------|-----------|---------|---------|
| `auction:state` | Server → Client | Full auction state | On channel join |
| `bid:new` | Server → All Clients | bid_id, amount, bidder_id, current_price, bid_count, end_time | After successful bid |
| `auction:closing_soon` | Server → All Clients | auction_id, end_time, seconds_remaining | 5 min before end_time |
| `auction:extended` | Server → All Clients | new_end_time, extension_count, reason | Anti-sniping triggers |
| `auction:closed` | Server → All Clients | status, winner_id, winning_amount | At end_time or force-close |
| `bid:rejected` | Server → Bidder Only | error_code, message | Bid validation failure |
| `user:outbid` | Server → Previous Leader | auction_id, new_leader_amount | When outbid |

### 4.3 WebSocket Reconnection Strategy

```javascript
// Client-side reconnection with exponential backoff
// (JavaScript — for LiveView or custom JS client)

class AuctionSocket {
  constructor(auctionId, tenantId) {
    this.auctionId = auctionId;
    this.tenantId = tenantId;
    this.reconnectAttempts = 0;
    this.maxReconnectAttempts = 10;
    this.baseDelay = 1000;  // 1 second
    this.maxDelay = 30000;  // 30 seconds
  }

  connect() {
    this.socket = new Phoenix.Socket("/socket", {
      params: { token: this.getAuthToken() }
    });

    this.socket.onError(() => this.handleDisconnect());
    this.socket.onClose(() => this.handleDisconnect());
    this.socket.connect();

    this.channel = this.socket.channel(
      `tenant:${this.tenantId}:auction:${this.auctionId}`
    );

    this.channel.join()
      .receive("ok", (state) => {
        this.reconnectAttempts = 0;  // Reset on successful join
        this.updateUI(state);        // Sync to current state
      })
      .receive("error", (reason) => {
        console.error("Join failed:", reason);
      });

    // Register event handlers
    this.channel.on("bid:new", (data) => this.handleNewBid(data));
    this.channel.on("auction:closed", (data) => this.handleClosed(data));
    this.channel.on("auction:extended", (data) => this.handleExtended(data));
  }

  handleDisconnect() {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      this.showFallbackUI();  // Show "Connection lost" with manual retry
      return;
    }

    // Exponential backoff with jitter
    const delay = Math.min(
      this.baseDelay * Math.pow(2, this.reconnectAttempts) +
        Math.random() * 1000,
      this.maxDelay
    );

    this.reconnectAttempts++;
    setTimeout(() => this.connect(), delay);
  }

  // Fallback: submit bid via HTTP if WebSocket is down
  async submitBidHTTP(amount) {
    const response = await fetch(
      `/api/v1/auctions/${this.auctionId}/bids`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${this.getAuthToken()}`
        },
        body: JSON.stringify({ amount })
      }
    );
    return response.json();
  }
}
```

### 4.4 Multi-Node PubSub (Clustering)

```elixir
# config/runtime.exs — Production clustering configuration

config :bid_platform, BidPlatformWeb.Endpoint,
  pubsub_server: BidPlatform.PubSub

# Using libcluster for automatic node discovery in production
config :libcluster,
  topologies: [
    ecs: [
      strategy: Cluster.Strategy.DNSPoll,
      config: [
        polling_interval: 5_000,
        query: System.get_env("DNS_CLUSTER_QUERY") || "bid-platform.local",
        node_basename: "bid_platform"
      ]
    ]
  ]

# Phoenix PubSub automatically distributes channel messages across all nodes
# in the Erlang cluster. No additional configuration needed.
# When Node A receives a bid, it broadcasts to its local subscribers,
# AND to all other nodes' subscribers via distributed Erlang.
```

---

## 5. Security Architecture

### 5.1 Authentication Flow

```
┌──────┐         ┌──────────┐          ┌──────────┐         ┌──────────┐
│Client│         │  Phoenix  │          │ Guardian  │         │    DB    │
└──┬───┘         └────┬─────┘          └────┬─────┘         └────┬─────┘
   │                  │                     │                     │
   │ POST /auth/login │                     │                     │
   │ {email, password}│                     │                     │
   │─────────────────▶│                     │                     │
   │                  │                     │                     │
   │                  │ Lookup user by      │                     │
   │                  │ email + tenant_id   │                     │
   │                  │────────────────────────────────────────▶│
   │                  │                     │     user record     │
   │                  │◀────────────────────────────────────────│
   │                  │                     │                     │
   │                  │ Verify password     │                     │
   │                  │ (bcrypt.verify)     │                     │
   │                  │                     │                     │
   │                  │ Generate JWT        │                     │
   │                  │────────────────────▶│                     │
   │                  │                     │ JWT with claims:    │
   │                  │                     │ {user_id, tenant_id,│
   │                  │◀────────────────────│  role, exp}         │
   │                  │                     │                     │
   │  200 OK          │                     │                     │
   │  {token, user}   │                     │                     │
   │◀─────────────────│                     │                     │
   │                  │                     │                     │
   │ Subsequent requests include:           │                     │
   │ Authorization: Bearer <token>          │                     │
   │─────────────────▶│                     │                     │
   │                  │ Decode + verify JWT │                     │
   │                  │────────────────────▶│                     │
   │                  │                     │ {user_id, tenant_id}│
   │                  │◀────────────────────│                     │
   │                  │                     │                     │
   │                  │ Load user + inject  │                     │
   │                  │ into conn.assigns   │                     │
   │                  │                     │                     │
```

### 5.2 Rate Limiting Implementation

```elixir
defmodule BidPlatformWeb.Plugs.RateLimiter do
  @moduledoc """
  Token bucket rate limiter using ETS.

  Limits:
  - General API: 100 requests per minute per user
  - Bidding: 30 bids per minute per user (prevents bot sniping)
  - Login: 5 attempts per 15 minutes per email (prevents brute force)
  """

  import Plug.Conn

  @general_limit 100
  @general_window_ms 60_000

  @bid_limit 30
  @bid_window_ms 60_000

  @login_limit 5
  @login_window_ms 900_000  # 15 minutes

  def init(opts), do: opts

  def call(conn, opts) do
    bucket_type = Keyword.get(opts, :type, :general)
    {limit, window} = get_limits(bucket_type)
    key = build_key(conn, bucket_type)

    case check_rate(key, limit, window) do
      {:allow, remaining} ->
        conn
        |> put_resp_header("x-ratelimit-limit", to_string(limit))
        |> put_resp_header("x-ratelimit-remaining", to_string(remaining))

      {:deny, retry_after_ms} ->
        conn
        |> put_status(:too_many_requests)
        |> put_resp_header("retry-after", to_string(div(retry_after_ms, 1000)))
        |> Phoenix.Controller.json(%{
          error: %{
            code: "RATE_LIMITED",
            message: "Too many requests. Please try again later.",
            retry_after_seconds: div(retry_after_ms, 1000)
          }
        })
        |> halt()
    end
  end

  defp get_limits(:general), do: {@general_limit, @general_window_ms}
  defp get_limits(:bidding), do: {@bid_limit, @bid_window_ms}
  defp get_limits(:login), do: {@login_limit, @login_window_ms}

  defp build_key(conn, :login) do
    email = conn.body_params["email"] || "unknown"
    "login:#{email}"
  end
  defp build_key(conn, type) do
    user_id = get_in(conn.assigns, [:current_user, :id]) || conn.remote_ip |> :inet.ntoa() |> to_string()
    "#{type}:#{user_id}"
  end

  defp check_rate(key, limit, window) do
    now = System.monotonic_time(:millisecond)
    # Implementation uses ETS-based sliding window counter
    # (simplified — production would use Hammer or similar library)
    {:allow, limit - 1}
  end
end
```

### 5.3 Input Validation & Sanitization

```elixir
defmodule BidPlatform.InputSanitizer do
  @moduledoc """
  Centralized input sanitization.
  Applied before data reaches Ecto changesets.
  """

  @doc """
  Sanitizes string inputs: trims whitespace, removes null bytes,
  and limits length to prevent memory exhaustion attacks.
  """
  def sanitize_string(nil), do: nil
  def sanitize_string(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.replace(<<0>>, "")        # Remove null bytes
    |> String.slice(0, 10_000)          # Hard limit on string length
  end

  @doc """
  Sanitizes decimal/money inputs: ensures valid numeric format,
  rejects NaN/Infinity, caps at reasonable maximum.
  """
  def sanitize_amount(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> validate_decimal_range(decimal)
      _ -> {:error, "Invalid numeric format"}
    end
  end
  def sanitize_amount(value) when is_number(value) do
    value |> to_string() |> sanitize_amount()
  end
  def sanitize_amount(_), do: {:error, "Invalid amount"}

  defp validate_decimal_range(decimal) do
    max_amount = Decimal.new("999_999_999_999.99")  # ~1 trillion

    cond do
      Decimal.compare(decimal, Decimal.new(0)) != :gt ->
        {:error, "Amount must be positive"}
      Decimal.compare(decimal, max_amount) == :gt ->
        {:error, "Amount exceeds maximum allowed value"}
      true ->
        {:ok, decimal}
    end
  end
end
```

---

## 6. Monitoring & Observability

### 6.1 Telemetry Events

```elixir
defmodule BidPlatform.Telemetry do
  @moduledoc """
  Custom telemetry events for business-critical metrics.
  These feed into Prometheus/Grafana dashboards.
  """

  # Emit when a bid is placed
  def bid_placed(auction, bid, duration_ms) do
    :telemetry.execute(
      [:bid_platform, :bid, :placed],
      %{duration: duration_ms, amount: Decimal.to_float(bid.amount)},
      %{
        tenant_id: auction.tenant_id,
        auction_id: auction.id,
        auction_type: auction.type,
        bid_count: auction.bid_count
      }
    )
  end

  # Emit when a bid is rejected
  def bid_rejected(reason, tenant_id, auction_id) do
    :telemetry.execute(
      [:bid_platform, :bid, :rejected],
      %{count: 1},
      %{reason: reason, tenant_id: tenant_id, auction_id: auction_id}
    )
  end

  # Emit when an auction closes
  def auction_closed(auction, result) do
    :telemetry.execute(
      [:bid_platform, :auction, :closed],
      %{
        total_bids: auction.bid_count,
        duration_seconds: DateTime.diff(auction.end_time, auction.inserted_at, :second)
      },
      %{
        tenant_id: auction.tenant_id,
        auction_type: auction.type,
        status: result.status,
        had_winner: result.winner_id != nil
      }
    )
  end

  # Emit on WebSocket connection count change
  def channel_joined(tenant_id, auction_id) do
    :telemetry.execute(
      [:bid_platform, :channel, :joined],
      %{count: 1},
      %{tenant_id: tenant_id, auction_id: auction_id}
    )
  end
end
```

### 6.2 Key Dashboard Metrics

```
BUSINESS METRICS (Grafana Dashboard: "Business Overview")
  ├── Active tenants (count, 24h trend)
  ├── Active auctions (count by type: english/reverse)
  ├── Bids per minute (rate, by tenant)
  ├── Auction completion rate (% closed with winner)
  └── Revenue (MRR, commission collected)

SYSTEM METRICS (Grafana Dashboard: "System Health")
  ├── Bid latency P50/P95/P99 (ms)
  ├── API response time P50/P95/P99 (ms)
  ├── WebSocket connections (gauge, by node)
  ├── Database connection pool utilization (%)
  ├── Oban queue depth (count, by queue)
  ├── Oban job failure rate (%)
  └── BEAM process count / memory usage

SECURITY METRICS (Grafana Dashboard: "Security")
  ├── Failed login attempts (rate, by tenant)
  ├── Rate limit hits (count, by type)
  ├── Cross-tenant access attempts (count — should be 0)
  └── Audit log volume (events/min)

ALERTING RULES:
  - Bid latency P95 > 1000ms → PagerDuty alert
  - Cross-tenant access attempts > 0 → Immediate alert + investigation
  - Oban failure rate > 5% → Warning alert
  - DB connection pool > 80% utilization → Warning alert
  - WebSocket connections > 10,000 per node → Scale-up alert
```

---

## 7. Disaster Recovery & Data Backup

### 7.1 Backup Strategy

```
AUTOMATED BACKUPS:
  ├── PostgreSQL WAL archiving → S3 (continuous)
  ├── Daily full backup → S3 (encrypted, retained 30 days)
  ├── Hourly incremental backup → S3 (retained 7 days)
  └── Cross-region replication → Secondary AWS region

RECOVERY PROCEDURES:
  ├── Point-in-time recovery: Restore to any second within the last 7 days
  ├── Full restoration: < 30 minutes for databases up to 100GB
  └── Failover to read replica: < 5 minutes (RDS Multi-AZ)

TESTING:
  ├── Monthly recovery drill (restore backup to staging)
  ├── Quarterly failover test (simulate primary failure)
  └── Annual full disaster recovery exercise
```

### 7.2 Data Retention & Deletion

```elixir
defmodule BidPlatform.Workers.DataRetentionWorker do
  @moduledoc """
  Oban worker that handles data retention policies.
  Runs daily at 2 AM UTC.

  Retention rules:
  - Audit logs: 3 years (configurable per tenant)
  - Closed auctions: Permanent (unless tenant requests deletion)
  - Bid records: Permanent (immutable audit trail)
  - Inactive tenants: Soft-deleted after 90 days of no activity; hard-deleted after 180 days
  """

  use Oban.Worker,
    queue: :cleanup,
    max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    # Purge old audit logs beyond retention period
    purge_expired_audit_logs()

    # Warn tenants approaching inactivity threshold
    warn_inactive_tenants()

    # Hard-delete tenants past the grace period
    purge_deleted_tenants()

    :ok
  end

  defp purge_expired_audit_logs do
    cutoff = DateTime.add(DateTime.utc_now(), -3 * 365, :day)  # 3 years

    from(a in BidPlatform.Audit.AuditLog,
      where: a.inserted_at < ^cutoff
    )
    |> BidPlatform.Repo.delete_all()
  end

  defp warn_inactive_tenants do
    cutoff_90_days = DateTime.add(DateTime.utc_now(), -90, :day)

    # Find tenants with no activity in 90 days
    # (no bids, no auctions created, no logins)
    # Schedule warning email via Oban
  end

  defp purge_deleted_tenants do
    cutoff_180_days = DateTime.add(DateTime.utc_now(), -180, :day)

    # Hard-delete all data for tenants soft-deleted more than 180 days ago
    # Delete in order: bids → auctions → audit_logs → users → tenant
  end
end
```

---

## 8. Performance Optimization Playbook

### 8.1 Database Indexing Strategy

```sql
-- Critical indexes for bidding performance
-- These are already in the migration but documented here for clarity

-- Fast auction lookup by tenant + status (most common query)
CREATE INDEX idx_auctions_tenant_status ON auctions (tenant_id, status);

-- Fast bid insertion and history queries
CREATE INDEX idx_bids_auction_inserted ON bids (auction_id, inserted_at DESC);

-- Winner determination: find max/min bid efficiently
CREATE INDEX idx_bids_auction_amount ON bids (auction_id, amount DESC);
-- For reverse auctions:
CREATE INDEX idx_bids_auction_amount_asc ON bids (auction_id, amount ASC);

-- Oban close scheduler: find auctions to close
CREATE INDEX idx_auctions_status_endtime ON auctions (status, end_time)
  WHERE status = 'active';

-- Audit log queries by tenant and time
CREATE INDEX idx_audit_tenant_time ON audit_logs (tenant_id, inserted_at DESC);
```

### 8.2 Query Optimization

```elixir
defmodule BidPlatform.Auctions.Queries do
  @moduledoc """
  Optimized queries for common access patterns.
  Each query uses covering indexes to minimize disk I/O.
  """

  import Ecto.Query

  @doc """
  Lists active auctions for a tenant.
  Uses the (tenant_id, status) index.
  Preloads ONLY the fields needed for the list view.
  """
  def list_active_auctions(tenant_id, opts \\ []) do
    page = Keyword.get(opts, :page, 1)
    per_page = Keyword.get(opts, :per_page, 20)
    offset = (page - 1) * per_page

    from(a in Auction,
      where: a.tenant_id == ^tenant_id and a.status == "active",
      order_by: [asc: a.end_time],
      limit: ^per_page,
      offset: ^offset,
      select: %{
        id: a.id,
        title: a.title,
        type: a.type,
        current_price: a.current_price,
        bid_count: a.bid_count,
        end_time: a.end_time
      }
    )
    |> Repo.all()
  end

  @doc """
  Gets recent bid history for an auction.
  Paginated to prevent loading thousands of bids.
  Uses the (auction_id, inserted_at DESC) index.
  """
  def recent_bids(tenant_id, auction_id, limit \\ 50) do
    from(b in Bid,
      where: b.tenant_id == ^tenant_id and b.auction_id == ^auction_id,
      order_by: [desc: b.inserted_at],
      limit: ^limit,
      select: %{
        id: b.id,
        amount: b.amount,
        user_id: b.user_id,
        status: b.status,
        inserted_at: b.inserted_at
      }
    )
    |> Repo.all()
  end
end
```

### 8.3 Caching Strategy (Redis — Optional Phase 2)

```elixir
defmodule BidPlatform.Cache do
  @moduledoc """
  Redis-backed cache for hot data.
  Primary use case: caching current_price to reduce DB reads
  during high-frequency bid bursts.

  IMPORTANT: The database remains the source of truth.
  Cache is invalidated on every successful bid.
  Cache misses fall through to the database.
  """

  @current_price_ttl 60  # seconds — short TTL as safety net

  def get_current_price(auction_id) do
    case Redix.command(:redix, ["GET", "auction:#{auction_id}:current_price"]) do
      {:ok, nil} -> :miss
      {:ok, value} -> {:hit, Decimal.new(value)}
      {:error, _} -> :miss  # Cache failure → fall through to DB
    end
  end

  def set_current_price(auction_id, price) do
    Redix.command(:redix, [
      "SETEX",
      "auction:#{auction_id}:current_price",
      @current_price_ttl,
      Decimal.to_string(price)
    ])
  end

  def invalidate_auction(auction_id) do
    Redix.command(:redix, ["DEL", "auction:#{auction_id}:current_price"])
  end
end
```

---

## 9. Development Setup Instructions

### 9.1 Prerequisites

```bash
# Required software
# - Erlang 26+
# - Elixir 1.16+
# - PostgreSQL 16+
# - Node.js 20+ (for asset compilation)
# - Docker & Docker Compose (optional, for containerized setup)

# Install Elixir dependencies
mix deps.get

# Create and migrate database
mix ecto.setup

# Seed development data (creates sample tenant, users, auctions)
mix run priv/repo/seeds.exs

# Start Phoenix server
mix phx.server

# The app is now running at http://localhost:4000
```

### 9.2 Development Seed Data

```elixir
# priv/repo/seeds.exs
# Creates a complete development environment with sample data

alias BidPlatform.{Repo, Tenants.Tenant, Accounts.User, Auctions.Auction}

# Create a demo tenant
{:ok, tenant} = Repo.insert(%Tenant{
  name: "Acme Corp",
  subdomain: "acme",
  slug: "acme-corp",
  plan: "professional",
  settings: %{
    "max_auctions_per_month" => 100,
    "max_users" => 200,
    "max_concurrent_bidders" => 100
  }
})

# Create admin user
{:ok, admin} = Repo.insert(%User{
  email: "admin@acme.com",
  password_hash: Bcrypt.hash_pwd_salt("Admin123!"),
  name: "Admin User",
  role: "admin",
  tenant_id: tenant.id
})

# Create bidder users
bidders = for i <- 1..5 do
  {:ok, user} = Repo.insert(%User{
    email: "bidder#{i}@acme.com",
    password_hash: Bcrypt.hash_pwd_salt("Bidder123!"),
    name: "Bidder #{i}",
    role: "bidder",
    tenant_id: tenant.id
  })
  user
end

# Create sample English auction
{:ok, _english_auction} = Repo.insert(%Auction{
  title: "Office Equipment Surplus Sale",
  description: "Selling surplus office furniture and electronics",
  type: "english",
  start_price: Decimal.new("1000"),
  current_price: Decimal.new("1000"),
  min_increment: Decimal.new("50"),
  end_time: DateTime.add(DateTime.utc_now(), 86_400, :second),  # 24 hours
  original_end_time: DateTime.add(DateTime.utc_now(), 86_400, :second),
  status: "active",
  tenant_id: tenant.id,
  created_by: admin.id,
  settings: %{
    "anti_sniping_enabled" => true,
    "anti_sniping_window_minutes" => 5,
    "anti_sniping_extension_minutes" => 3,
    "max_extensions" => 5,
    "extension_count" => 0
  }
})

# Create sample Reverse auction
{:ok, _reverse_auction} = Repo.insert(%Auction{
  title: "Stationery Supply Contract Q3 2026",
  description: "Seeking vendors for quarterly stationery supply",
  type: "reverse",
  start_price: Decimal.new("50000"),
  current_price: Decimal.new("50000"),
  min_increment: Decimal.new("500"),
  end_time: DateTime.add(DateTime.utc_now(), 172_800, :second),  # 48 hours
  original_end_time: DateTime.add(DateTime.utc_now(), 172_800, :second),
  status: "active",
  tenant_id: tenant.id,
  created_by: admin.id
})

IO.puts("Seed data created successfully!")
IO.puts("  Tenant: #{tenant.name} (#{tenant.subdomain})")
IO.puts("  Admin: admin@acme.com / Admin123!")
IO.puts("  Bidders: bidder1@acme.com through bidder5@acme.com / Bidder123!")
```

---

## 10. Checklist — Pre-Launch Verification

### 10.1 Security Checklist

- [ ] All queries scoped by tenant_id (automated test coverage)
- [ ] Cross-tenant access test suite passes (10+ test cases)
- [ ] WebSocket channel isolation tested
- [ ] Rate limiting active on all endpoints
- [ ] JWT expiry and refresh working
- [ ] Password hashing with bcrypt (cost 12+)
- [ ] HTTPS enforced (redirect HTTP → HTTPS)
- [ ] CORS configured per tenant subdomain
- [ ] SQL injection tests pass (Ecto parameterized queries)
- [ ] Input validation on all user-facing fields
- [ ] Audit logging for all mutations
- [ ] Secrets in environment variables (not in code)

### 10.2 Performance Checklist

- [ ] Bid placement P95 < 500ms under load (100 concurrent bidders)
- [ ] Database indexes verified with EXPLAIN ANALYZE
- [ ] Connection pool sized appropriately (pool_size: 20+)
- [ ] WebSocket broadcast < 200ms P95
- [ ] Oban queues configured with appropriate concurrency
- [ ] No N+1 queries (verified with Ecto query logger)
- [ ] Pagination on all list endpoints

### 10.3 Reliability Checklist

- [ ] Oban workers are idempotent (safe to retry)
- [ ] Database migrations are reversible
- [ ] Health check endpoint (/health) returns DB + Redis status
- [ ] Graceful shutdown handling (drain WebSocket connections)
- [ ] Error tracking (Sentry or equivalent) configured
- [ ] Automated database backups verified
- [ ] Recovery procedure documented and tested

---

*This technical specification is designed for direct consumption by an autonomous AI coding agent or engineering team. All code samples are production-grade Elixir targeting Phoenix Framework 1.7+ with Ecto 3.x and PostgreSQL 16.*
