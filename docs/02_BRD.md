# BUSINESS REQUIREMENTS DOCUMENT (BRD) — Multi-Tenant Real-Time Bidding SaaS Platform

> **Document ID:** BRD-BID-2026-001
> **Version:** 1.0
> **Date:** April 21, 2026
> **Author:** Product Strategy Team
> **Status:** Draft for Review
> **Classification:** Internal — Product Planning
> **Related Documents:** MKT-BID-2026-001 (Market Analysis), PRD-BID-2026-001 (Product Requirements)

---

## 1. Product Vision

### 1.1 Vision Statement

Build a **multi-tenant, real-time bidding SaaS platform** that enables any organization to run transparent, competitive auctions — both English (forward/sell-side) and Reverse (procurement/buy-side) — with sub-500ms latency, tenant-isolated data, and self-serve onboarding. The platform serves as horizontal auction infrastructure that verticals can adopt without custom development.

### 1.2 Problem Statement

Organizations today face fragmented, expensive, and technically complex options for running competitive bidding events:

- **Enterprise tools** (SAP Ariba, Coupa) are prohibitively expensive for SMEs and require months of implementation.
- **Marketplace platforms** (eBay, GeM) are destination sites — organizations cannot run auctions under their own brand or rules.
- **Custom builds** require 6–12 months of engineering investment and ongoing maintenance.
- **Manual processes** (email RFQs, spreadsheet comparisons) lack transparency, audit trails, and real-time competition.

There is no self-serve, affordable, multi-tenant SaaS platform that lets organizations spin up branded auction environments in minutes with both forward and reverse bidding capabilities.

### 1.3 Strategic Objectives

| Objective | Target | Timeline |
|-----------|--------|----------|
| Launch MVP with core bidding | Functional English + Reverse auctions | Month 3 |
| Onboard first 10 paying tenants | Validated product-market fit | Month 6 |
| Achieve ₹4L MRR | Sustainable unit economics | Month 12 |
| Expand to 200 tenants | Pan-India presence | Month 24 |
| API ecosystem launch | Third-party integrations | Month 18 |

---

## 2. Stakeholders

### 2.1 Stakeholder Map

#### Platform Owner (You — SaaS Operator)

- **Role:** Operates the multi-tenant infrastructure, manages billing, ensures uptime
- **Goals:** Revenue growth, tenant acquisition, platform reliability
- **Responsibilities:** Infrastructure, tenant provisioning, subscription management, compliance, security
- **Success Criteria:** ARR growth, tenant retention >85%, platform uptime >99.9%

#### Tenant Organization (Customer)

- **Role:** An organization that subscribes to the platform to run its own auctions
- **Goals:** Run competitive, transparent auctions under their own brand/subdomain
- **Responsibilities:** Auction creation, user management within their org, bidding rule configuration
- **Success Criteria:** Cost savings (reverse), revenue maximization (English), process transparency

#### Tenant Admin

- **Role:** Administrator within a tenant organization
- **Goals:** Manage auctions, invite users, configure rules, view analytics
- **Responsibilities:** Day-to-day auction operations, user role management
- **Success Criteria:** Operational efficiency, auction completion rate

#### Bidder (End User within Tenant)

- **Role:** A user invited by a tenant to participate in auctions
- **Goals:** Place competitive bids, win auctions, receive timely notifications
- **Responsibilities:** Bid submission, compliance with auction rules
- **Success Criteria:** Fair bidding experience, real-time feedback, clear auction outcomes

#### Super Admin (Platform Operations)

- **Role:** Internal operations team managing the SaaS platform
- **Goals:** Monitor all tenants, handle escalations, manage billing
- **Responsibilities:** Tenant provisioning, system health monitoring, abuse prevention
- **Success Criteria:** Mean time to resolve issues <4 hours, zero cross-tenant data leaks

---

## 3. Business Use Cases

### 3.1 Use Case Matrix

| ID | Use Case | Actor | Auction Type | Priority |
|----|----------|-------|-------------|----------|
| BUC-001 | Organization runs a procurement auction to find lowest-cost vendor | Tenant Admin | Reverse | P0 — Critical |
| BUC-002 | Organization auctions surplus equipment to highest bidder | Tenant Admin | English | P0 — Critical |
| BUC-003 | Bidder places a real-time bid and receives instant confirmation | Bidder | Both | P0 — Critical |
| BUC-004 | Bidder receives outbid notification and can respond immediately | Bidder | Both | P0 — Critical |
| BUC-005 | Auction closes automatically and winner is determined | System | Both | P0 — Critical |
| BUC-006 | Admin views bid history and audit trail for an auction | Tenant Admin | Both | P1 — Important |
| BUC-007 | Admin force-closes an auction early due to irregularities | Tenant Admin | Both | P1 — Important |
| BUC-008 | Organization invites external vendors/bidders via email | Tenant Admin | Both | P1 — Important |
| BUC-009 | Platform owner views cross-tenant analytics and billing | Super Admin | N/A | P1 — Important |
| BUC-010 | Organization configures anti-sniping rules (time extension on late bids) | Tenant Admin | Both | P2 — Nice to Have |

### 3.2 Detailed Use Case: BUC-001 — Procurement Reverse Auction

```
TITLE: Run a Procurement Reverse Auction
ACTOR: Tenant Admin
PRECONDITIONS:
  - Admin is authenticated and belongs to a tenant
  - Tenant subscription is active
  - At least 2 bidders are registered under the tenant

MAIN FLOW:
  1. Admin creates a new auction with type = "reverse"
  2. Admin sets: title, description, starting price (ceiling), minimum decrement, end time
  3. Admin invites bidders (internal users or external via email)
  4. System validates auction parameters and saves as "scheduled"
  5. At start time, auction status changes to "active"
  6. Bidders receive notification that auction is live
  7. Bidders submit bids; each bid must be lower than current_price - min_decrement
  8. System validates bid, updates current_price, broadcasts to all participants via WebSocket
  9. If anti-sniping is enabled and a bid arrives within the final N minutes, end_time extends
  10. At end_time, system closes auction and determines winner (lowest valid bid)
  11. All participants receive outcome notification (win/loss)
  12. Admin can view full bid history and audit trail

POSTCONDITIONS:
  - Auction status = "closed"
  - Winner determined and recorded
  - Bid history immutable and auditable

ALTERNATIVE FLOWS:
  A1. No bids received → Auction closes with status = "no_bids"
  A2. Only one bidder → Auction proceeds; single bid = winner (admin discretion)
  A3. Admin force-closes → Auction status = "force_closed"; winner = best bid at time of closure
  A4. Identical bids → Earlier bid wins (timestamp-based tiebreaker)

EXCEPTION FLOWS:
  E1. Bid amount < 0 → Rejected with validation error
  E2. Bid submitted after auction closes → Rejected; user notified
  E3. WebSocket disconnection → Bid via HTTP fallback; reconnect prompt shown
  E4. Database lock contention → Retry with exponential backoff (max 3 retries)
```

### 3.3 Detailed Use Case: BUC-002 — English Forward Auction

```
TITLE: Run an English Forward Auction
ACTOR: Tenant Admin
PRECONDITIONS:
  - Admin is authenticated and belongs to a tenant
  - Tenant subscription is active

MAIN FLOW:
  1. Admin creates a new auction with type = "english"
  2. Admin sets: title, description, starting price (floor), minimum increment, end time
  3. Admin optionally sets a reserve price (hidden minimum)
  4. Admin invites bidders
  5. At start time, auction becomes "active"
  6. Bidders submit bids; each bid must exceed current_price + min_increment
  7. System validates, updates current_price, broadcasts in real-time
  8. Anti-sniping extensions apply if configured
  9. At end_time, auction closes; highest valid bid wins
  10. If reserve price is set and not met, auction closes with status = "reserve_not_met"
  11. Notifications dispatched to all participants

POSTCONDITIONS:
  - Auction status = "closed" or "reserve_not_met"
  - Winner recorded if reserve met
  - Complete audit trail preserved
```

---

## 4. Revenue Model

### 4.1 Primary Revenue Streams

| Stream | Model | Pricing (India Market) |
|--------|-------|----------------------|
| **Subscription** | Monthly/annual per-tenant SaaS fee | ₹2,000–₹2,00,000/month based on tier |
| **Per-Auction Commission** | Percentage of winning bid value | 0.5%–2% (capped) |
| **Overage Charges** | Additional auctions beyond plan limits | ₹500 per extra auction |

### 4.2 Subscription Tiers

| Tier | Monthly Price | Auctions/Month | Users | Real-Time Bidding | Support |
|------|-------------|----------------|-------|------------------|---------|
| **Free** | ₹0 | 3 | 10 | ✅ (5 concurrent bidders) | Community |
| **Starter** | ₹5,000 | 20 | 50 | ✅ (25 concurrent) | Email |
| **Professional** | ₹15,000 | Unlimited | 200 | ✅ (100 concurrent) | Priority email + chat |
| **Enterprise** | Custom | Unlimited | Unlimited | ✅ (unlimited) | Dedicated + SLA |

### 4.3 Additional Revenue (Phase 2+)

- **Custom Domain** — ₹2,000/month (tenant gets `auctions.theircompany.com`)
- **White-Label Branding** — ₹5,000/month (remove platform branding)
- **API Access** — Included in Professional+; metered for Starter
- **Audit & Compliance Reports** — ₹1,000/report (auto-generated)

### 4.4 Unit Economics Target

| Metric | Target |
|--------|--------|
| Customer Acquisition Cost (CAC) | < ₹15,000 |
| Lifetime Value (LTV) | > ₹1,50,000 |
| LTV:CAC Ratio | > 10:1 |
| Monthly Churn | < 5% |
| Gross Margin | > 80% |

---

## 5. Success Metrics (KPIs)

### 5.1 Business KPIs

| KPI | Definition | Target (Year 1) |
|-----|-----------|-----------------|
| Tenants Onboarded | Total active paying tenants | 50 |
| Monthly Recurring Revenue (MRR) | Sum of all subscription fees | ₹4,00,000 |
| Tenant Retention Rate | % of tenants active after 3 months | >85% |
| Net Revenue Retention | MRR growth from existing tenants | >110% |
| Auctions Completed | Total successful auction closures | 1,000 |

### 5.2 Product KPIs

| KPI | Definition | Target |
|-----|-----------|--------|
| Bids Per Auction (Avg) | Average number of bids per completed auction | >8 |
| Real-Time Latency (P95) | Time from bid submission to broadcast receipt | <500ms |
| Auction Completion Rate | % of created auctions that receive ≥1 bid | >70% |
| User Activation Rate | % of invited bidders who place ≥1 bid | >60% |
| Mobile Participation Rate | % of bids placed from mobile devices | >40% |

### 5.3 Operational KPIs

| KPI | Definition | Target |
|-----|-----------|--------|
| Platform Uptime | % time system is available | >99.9% |
| Mean Time to Resolution (MTTR) | Average time to resolve P1 incidents | <4 hours |
| Cross-Tenant Data Leak Incidents | Security breach count | 0 (zero tolerance) |
| Support Ticket Resolution Time | Average first-response time | <2 hours (business hours) |

---

## 6. Business Rules

### 6.1 Tenant Isolation Rules

| Rule ID | Rule | Enforcement |
|---------|------|-------------|
| BR-001 | Every database record MUST have a `tenant_id` | Schema-level constraint |
| BR-002 | Every query MUST be scoped to the requesting user's `tenant_id` | Application middleware |
| BR-003 | No user can access, view, or interact with data from another tenant | API + DB + WebSocket channel level |
| BR-004 | WebSocket channels MUST include `tenant_id` in the topic | Channel authentication |
| BR-005 | File uploads (if any) MUST be stored in tenant-scoped paths | Storage layer |

### 6.2 Bidding Rules

| Rule ID | Rule |
|---------|------|
| BR-010 | English auction: `new_bid > current_price + min_increment` |
| BR-011 | Reverse auction: `new_bid < current_price - min_decrement` |
| BR-012 | A user cannot bid on their own auction (if they are also the creator) |
| BR-013 | Bids are immutable once submitted — no edits, no deletions |
| BR-014 | Bids submitted after `end_time` are rejected |
| BR-015 | Tie-breaking: earlier timestamp wins |
| BR-016 | Anti-sniping: if a bid arrives within the last N minutes of `end_time`, extend by M minutes (configurable per auction) |

### 6.3 Auction Lifecycle Rules

| Rule ID | Rule |
|---------|------|
| BR-020 | An auction transitions: `draft` → `scheduled` → `active` → `closed` |
| BR-021 | Only Admins can create/edit auctions |
| BR-022 | Auctions in `active` status cannot be edited (only force-closed) |
| BR-023 | Force-close requires Admin confirmation and records reason |
| BR-024 | Winner is determined automatically at `end_time` based on auction type |
| BR-025 | An auction with 0 bids closes with status `no_bids` |

---

## 7. Compliance & Legal Requirements

### 7.1 Data Protection

- All personal data encrypted at rest (AES-256) and in transit (TLS 1.3)
- Tenant data logically isolated; no cross-tenant queries possible
- Data retention policies configurable per tenant (default: 3 years)
- Right to data export (tenant can download all their data)
- Right to deletion (tenant offboarding includes full data purge after grace period)

### 7.2 India-Specific Compliance

- **IT Act, 2000** — Electronic contracts and digital signatures recognized
- **Indian Contract Act** — Auction rules comply with Section 64 (sale by auction)
- **GST Compliance** — Platform must support GST invoice generation for commission charges
- **State Transparency Acts** — Audit trail and bid history features satisfy transparency requirements

### 7.3 Audit Trail Requirements

Every significant action must be logged with:

- Timestamp (UTC + IST)
- Actor (user_id, tenant_id, role)
- Action performed
- Before/after state (for mutations)
- IP address and device fingerprint

---

## 8. Assumptions & Constraints

### 8.1 Assumptions

| ID | Assumption |
|----|-----------|
| A-001 | Target customers have internet connectivity sufficient for real-time bidding |
| A-002 | Organizations will provide their own user base (bidders); platform is not a marketplace |
| A-003 | Initial launch focuses on India market with INR as primary currency |
| A-004 | Tenants manage their own user invitations; platform does not acquire bidders |
| A-005 | English and Reverse auction types cover 90%+ of initial use cases |

### 8.2 Constraints

| ID | Constraint |
|----|-----------|
| C-001 | MVP must be deliverable within 3 months with a solo/small engineering team |
| C-002 | Infrastructure costs must remain under ₹50,000/month for first 50 tenants |
| C-003 | Phoenix/Elixir stack is the chosen technology (non-negotiable) |
| C-004 | PostgreSQL is the chosen database (non-negotiable) |
| C-005 | No payment processing in MVP — subscription billing is manual/Razorpay link |

### 8.3 Dependencies

| ID | Dependency | Impact if Unavailable |
|----|-----------|---------------------|
| D-001 | PostgreSQL managed instance (AWS RDS or equivalent) | Cannot launch |
| D-002 | Email service provider (for notifications, invitations) | Degraded experience — no outbound notifications |
| D-003 | DNS/subdomain routing infrastructure | No tenant-specific subdomains |
| D-004 | SSL certificate management (wildcard or per-subdomain) | Security/trust issues |

---

## 9. Out of Scope (MVP)

The following capabilities are explicitly excluded from the initial release:

- Payment processing / escrow for auction transactions
- Sealed-bid auctions
- Multi-attribute (weighted scoring) auctions
- AI-based bid suggestions
- Multi-language support (English only in MVP)
- Mobile native apps (responsive web only)
- Advanced analytics dashboards
- Integration APIs for third-party systems
- Custom domain support
- White-label branding

These are planned for Phase 2+ as documented in the product roadmap.

---

## 10. Approval & Sign-Off

| Role | Name | Date | Signature |
|------|------|------|-----------|
| Product Owner | — | — | — |
| Technical Lead | — | — | — |
| Business Stakeholder | — | — | — |

---

*This BRD serves as the business-level foundation for the accompanying Product Requirements Document (PRD-BID-2026-001).*
