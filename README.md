# BidPlatform — Multi-Tenant Bidding SaaS

A production-grade, multi-tenant bidding platform built with Phoenix 1.8, PostgreSQL, and Tailwind CSS v4.

## 🚀 Quick Start (Docker)

The fastest way to get started is using Docker Compose and the provided `Makefile`.

1.  **Start the environment**:
    ```bash
    make up
    ```
2.  **Run initial setup** (dependencies, migrations, seeds):
    ```bash
    make setup
    ```
3.  **Access the app**: [http://localhost:4000](http://localhost:4000)

## 👑 Default Credentials (Super Admin)

Use these credentials to log in as a Global Administrator to manage the whole platform:

*   **URL**: [http://localhost:4000/login](http://localhost:4000/login)
*   **Email**: `superadmin@bidplatform.com`
*   **Password**: `password1234`

## 🛠️ Local Development Setup

If you prefer to run the application outside of Docker or need local IDE support:

1.  **Version Management**: The project uses `asdf`.
    *   **Erlang**: 25.3.2.8
    *   **Elixir**: 1.17.3 (OTP 25)
2.  **Shell Configuration**: Your `.bashrc` has been updated with `asdf` integration. Run `source ~/.bashrc`.
3.  **Database**: Point your local `DATABASE_URL` to `ecto://postgres:postgres@localhost:5439/bid_dev`.

## 📂 Project Management

Use the `Makefile` for common tasks:
*   `make logs`: Stream application logs.
*   `make console`: Open an interactive Elixir shell (IEx).
*   `make migrate`: Run database migrations.
*   `make test`: Run the test suite.

## 🏗️ Multi-Tenancy Flow
New organizations can onboard themselves at [http://localhost:4000/register](http://localhost:4000/register), which creates a separate tenant silo and an admin user in one atomic transaction.
