# Metroid Mania

## A WIP Hack Club *You Ship We Ship* draft
---

This project is a Ruby on Rails based system for managing the You Ship We Ship (YSWS) program, including admin controls, user projects, Hackatime integration, and more!

## Features

### Core Functionality
- **User Management**: Authentication and authorization system with admin roles
- **Project Management**: Create, track, and manage user projects
- **Devlogs**: Log development time and progress for projects
- **Hackatime Integration**: Sync project time tracking with Hackatime API
- **Leaderboards**: Display top contributors and projects
- **Order Management**: Handle YSWS orders and requests
- **Ship Requests**: Manage shipping requests for completed projects

### Admin Features
- **Admin Dashboard**: Centralized admin controls
- **User Management**: View and manage all users
- **Project Oversight**: Monitor all projects and their progress
- **Approval System**: Approve/reject projects and orders
- **Analytics**: View statistics and metrics

### Integration Features
- **Hackatime API**: Real-time time tracking integration
- **Slack Integration**: User authentication via Slack OAuth
- **Hack Club Integration**: OAuth integration with Hack Club

## Site Structure

### Controllers
- `app/controllers/`
  - `home_controller.rb` - Main landing page and dashboard
  - `users_controller.rb` - User profile and management
  - `projects_controller.rb` - Project CRUD operations
  - `devlogs_controller.rb` - Development log management
  - `orders_controller.rb` - Order management
  - `leaderboards_controller.rb` - Leaderboard display
  - `ship_requests_controller.rb` - Shipping request handling
  - `sessions_controller.rb` - Authentication sessions
  - `dev_sessions_controller.rb` - Developer sessions
  - `admin/` - Admin-specific controllers

### Models
- `app/models/`
  - `user.rb` - User model with authentication
  - `project.rb` - Project model with time tracking
  - `devlog.rb` - Development log entries
  - `order.rb` - Order model
  - `ship_request.rb` - Shipping request model

### Views
- `app/views/`
  - `layouts/` - Application layout templates
  - `home/` - Home page views
  - `users/` - User profile views
  - `projects/` - Project views (index, show, new, edit)
  - `devlogs/` - Devlog views
  - `orders/` - Order views
  - `leaderboards/` - Leaderboard views
  - `admin/` - Admin dashboard views

### Services
- `app/services/`
  - `hackatime_service.rb` - Hackatime API integration

### Jobs
- `app/jobs/` - Background jobs for processing

### Mailers
- `app/mailers/` - Email notifications

## Installation

### Prerequisites
- Ruby 3.4.3 (see `.ruby-version`)
- Rails 8.1.2
- SQLite3 (development) or PostgreSQL (production)
- Node.js (for asset compilation)
- Redis (for caching and background jobs)

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd Metroid-Mania
   ```

2. **Install dependencies**
   ```bash
   bundle install
   npm install
   ```

3. **Setup environment variables**
   ```bash
   cp .env.example .env
   ```
   Edit `.env` with your configuration:
   - `HACKCLUB_CLIENT_ID` and `HACKCLUB_CLIENT_SECRET` - From Hack Club OAuth app
   - `HACKATIME_API_KEY` - From Hackatime API
   - `APP_URL` - Your local development URL (e.g., `http://localhost:3000`)
   - `AUTO_ADMIN_EMAIL` and `AUTO_ADMIN_PASSWORD` - For admin user creation

4. **Setup database**
   ```bash
   bin/rails db:create
   bin/rails db:migrate
   bin/rails db:seed
   ```

5. **Start the development server**
   ```bash
   bin/dev
   ```
   The app will be available at `http://localhost:3000`

### Docker Setup

1. **Build the Docker image**
   ```bash
   docker build -t metroid_mania .
   ```

2. **Run the container**
   ```bash
   docker run -d -p 80:3000 \
     -e RAILS_MASTER_KEY=<your-master-key> \
     -e HACKCLUB_CLIENT_ID=<your-client-id> \
     -e HACKCLUB_CLIENT_SECRET=<your-client-secret> \
     -e HACKATIME_API_KEY=<your-api-key> \
     --name metroid_mania metroid_mania
   ```

### Environment Variables

Required environment variables:
- `HACKCLUB_CLIENT_ID` - Hack Club OAuth client ID
- `HACKCLUB_CLIENT_SECRET` - Hack Club OAuth client secret
- `HACKATIME_API_KEY` - Hackatime API key
- `APP_URL` - Application URL
- `RAILS_MASTER_KEY` - Rails master key for production

Optional environment variables:
- `AUTO_ADMIN_EMAIL` - Email for auto-created admin user
- `AUTO_ADMIN_PASSWORD` - Password for auto-created admin user
- `AUTO_ADMIN` - Set to `1` to enable auto-admin creation

## Usage

### Running Tests
```bash
bin/rails test
```

### Running Linters
```bash
# RuboCop
bundle exec rubocop

# ERB Lint
bundle exec erb_lint

# Security audit
bundle exec brakeman
bundle exec bundler-audit
```

### Background Jobs
```bash
# Start background job processor
bin/jobs
```

### Cable (WebSockets)
```bash
bin/rails cable
```

## Deployment

### Using Kamal
```bash
# Setup
kamal setup

# Deploy
kamal deploy

# View logs
kamal logs
```

### Using Docker
Build and push the image to your container registry, then deploy to your hosting provider.

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and questions, please open an issue on the repository.

