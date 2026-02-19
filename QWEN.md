# Metroid Mania - Project Context

## Project Overview

**Metroid Mania** is a Ruby on Rails 8.1 application that powers the **You Ship We Ship (YSWS)** program for Hack Club. It's a platform where users can manage projects, log development time, request shipments, and earn credits based on their work.

### Core Features

- **User Management**: OAuth authentication via Hack Club and Slack, with admin roles
- **Project Management**: Create, track, and manage user projects with GitHub integration
- **Devlogs**: Log development time and progress for projects
- **Hackatime Integration**: Real-time time tracking API integration
- **Ship Requests**: Users request shipments; admins approve/reject
- **Order Management**: Handle YSWS orders with credit-based spending
- **Leaderboards**: Display top contributors and projects
- **Admin Dashboard**: Centralized controls for user/project/order management
- **Audit System**: Track administrative actions via `Audit` model

### Tech Stack

| Layer | Technology |
|-------|------------|
| **Framework** | Rails 8.1.2 |
| **Language** | Ruby 3.4.3 |
| **Database** | SQLite3 (dev), PostgreSQL (production) |
| **Frontend** | Hotwired (Turbo + Stimulus), Importmap |
| **Assets** | Propshaft, esbuild |
| **Auth** | Omniauth (Hack Club, Slack OAuth) |
| **Background Jobs** | Solid Queue |
| **Caching** | Solid Cache |
| **WebSockets** | Solid Cable |
| **Deployment** | Kamal, Docker |

## Project Structure

```
Metroid-Mania/
├── app/
│   ├── controllers/      # Home, Users, Projects, Devlogs, Orders, Admin::
│   ├── models/           # User, Project, Devlog, Order, Ship, ShipRequest, Audit
│   ├── views/            # ERB templates with layouts
│   ├── services/         # External API integrations
│   ├── jobs/             # Solid Queue background jobs
│   ├── mailers/          # Email notifications
│   └── helpers/          # View helpers
├── config/
│   ├── routes.rb         # Main routing (admin namespace, RESTful resources)
│   ├── initializers/     # Rails initializers
│   └── deploy.yml        # Kamal deployment config
├── db/
│   ├── schema.rb         # Current database schema
│   └── migrate/          # Database migrations
├── test/                 # Rails tests (models, controllers, integration)
├── script/               # Custom scripts
├── bin/                  # Rails executables (dev, rails, jobs, kamal)
└── Dockerfile            # Multi-stage Docker build
```

## Key Models

| Model | Description |
|-------|-------------|
| `User` | Authentication, roles (user/admin), credits, Hackatime sync |
| `Project` | Projects with Hackatime integration, soft-delete, ship status |
| `Devlog` | Time logs linked to projects |
| `Ship` | Shipped projects with credits awarded |
| `ShipRequest` | User requests for shipping (pending/approved/rejected) |
| `Order` | User orders with cost tracking |
| `Audit` | Admin action logging |
| `SiteSetting` | Feature toggles and site configuration |

## Key Services

| Service | Purpose |
|---------|---------|
| `HackatimeService` | Hackatime API integration for time tracking |
| `SlackService` / `SlackOauthService` | Slack API and OAuth |
| `HackclubIpService` | IP-based region detection |
| `CdnService` | CDN integration |
| `SteamService` | Steam API integration |

## Building and Running

### Prerequisites

- Ruby 3.4.3 (managed via `.ruby-version`)
- Node.js (for asset compilation)
- SQLite3 (development) or PostgreSQL (production)
- Redis (for caching/background jobs)

### Local Development Setup

```bash
# Install dependencies
bundle install
npm install

# Setup environment
cp .env.example .env
# Edit .env with your credentials

# Setup database
bin/rails db:create
bin/rails db:migrate
bin/rails db:seed

# Start development server (with live reload)
bin/dev
```

The app runs at `http://localhost:3000`.

### Environment Variables

Required for full functionality:
- `HACKCLUB_CLIENT_ID` / `HACKCLUB_CLIENT_SECRET` - Hack Club OAuth
- `HACKATIME_API_KEY` - Hackatime API
- `SLACK_CLIENT_ID` / `SLACK_CLIENT_SECRET` / `SLACK_SIGNING_SECRET` - Slack OAuth
- `APP_URL` - Application URL

### Docker

```bash
# Build
docker build -t metroid_mania .

# Run
docker run -d -p 80:3000 \
  -e RAILS_MASTER_KEY=<key> \
  -e HACKCLUB_CLIENT_ID=<id> \
  --name metroid_mania metroid_mania
```

### Deployment (Kamal)

```bash
kamal setup    # Initial setup
kamal deploy   # Deploy
kamal logs     # View logs
```

## Development Commands

```bash
# Run tests
bin/rails test

# Run linters
bundle exec rubocop
bundle exec erb_lint

# Security audit
bundle exec brakeman
bundle exec bundler-audit

# Start background job processor
bin/jobs

# Start WebSocket server (cable)
bin/rails cable
```

## Testing Practices

- **Test Framework**: Rails default (Minitest)
- **Test Structure**: Mirrors `app/` structure (`test/models/`, `test/controllers/`, etc.)
- **Fixtures**: Located in `test/fixtures/`
- **Integration Tests**: For end-to-end flows (auth, ship requests, admin actions)

## Coding Conventions

- **Style**: RuboCop Rails Omakase (see `.rubocop.yml`)
- **ERB Linting**: Enabled via `erb_lint`
- **Formatting**: Prettier configured (see `.prettierrc`)
- **Authorization**: Pundit for policy-based authorization
- **State Machines**: AASM for order state management
- **Versioning**: PaperTrail for model versioning

## Routes Overview

### Public Routes
- `GET /` - Home page
- `GET /leaderboard` - Leaderboards
- `GET /profile` - User profile
- `GET /users/:id` - User profiles
- `GET /auth/:provider/callback` - OAuth callback
- `DELETE /logout` - Logout
- `GET /gallery` - Gallery

### Resources
- `projects` - CRUD with nested `devlogs`, `ship_requests`
- `orders` - User orders
- `products` - Available products
- `comments` - Comments on devlogs/ships

### Admin Namespace (`/admin`)
- `dashboard` - Admin dashboard
- `users` - User management (with `revert_actions`)
- `orders` - Order management (fulfill/decline/pend)
- `projects` - Project approval (approve/reject/ship/unship)
- `ship_requests` - Approve/reject requests
- `audits` - Audit log
- `site_settings` - Feature toggles

### Development-Only
- `POST /dev_login` - Dev authentication bypass

## Important Notes

### Soft Deletes
- `Project` uses `deleted_at` timestamp for soft deletes
- `User` deletion reassigns records to `system_user` or anonymizes data

### Credits System
- Users earn credits based on `credits_per_hour * hours_logged`
- Credits stored on `User.currency`
- Spending tracked via `Order.cost` and `User.amount_spent`
- Available balance: `total_credits - amount_spent`

### Hackatime Integration
- Projects link to Hackatime projects via `hackatime_ids` (YAML array)
- Time sync via `HackatimeService`
- Trust status tracked per user (`hackatime_trust_status`)

### Ship Workflow
1. User creates `ShipRequest` (requires 15+ minutes devlogged)
2. Admin reviews and approves/rejects
3. On approval: `Ship` record created, credits awarded
4. Project status updated to `shipped`

### Admin Features
- Bulk project updates
- Force ship/unship projects
- Revert user actions
- Site-wide feature toggles

## Debug Scripts

Several debug scripts exist in the root for troubleshooting:
- `debug_counts.rb`, `debug_counts2.rb` - Count diagnostics
- `debug_script.rb` - General debugging
- `debug_verify.rb` - Verification checks
- `debug_projects_*.rb` - Project-specific debugging
