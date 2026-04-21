# BidPlatform API Documentation

## Authentication
All API requests (except health check and login) require a Bearer JWT.

### Login
`POST /api/v1/auth/login`
- Body: `{"email": "...", "password": "..."}`
- Response: `{"token": "JWT_HERE"}`

## Auctions

### List Auctions
`GET /api/v1/auctions`
- Headers: `Authorization: Bearer <token>`
- Isolation: Returns only auctions for the authenticated user's tenant.

### Create Auction
`POST /api/v1/auctions`
- Headers: `Authorization: Bearer <token>`
- Body:
```json
{
  "auction": {
    "title": "Vintage Watch",
    "type": "english",
    "start_price": "100.00",
    "min_increment": "5.00",
    "end_time": "2026-12-31T23:59:59Z"
  }
}
```
- RBAC: Only `admin` role allowed.

## Bidding

### Place Bid
`POST /api/v1/auctions/:auction_id/bids`
- Body: `{"amount": "110.00"}`
- Isolation: Enforced via `tenant_id`.
- Race Conditions: Handled via PostgreSQL row-level locks.

## Real-Time (WebSockets)

### Connection
`ws://localhost:4000/socket?token=JWT_HERE`

### Subscriptions
Topic: `tenant:{tenant_id}:auction:{auction_id}`
- Validates `tenant_id` matches the token.

### Events
- `bid:new`: Broadcasted when a valid bid is placed.
- `auction:closed`: Broadcasted when the auction ends and a winner is determined.

## System status
`GET /api/health`
- Public endpoint returns database and service health.
