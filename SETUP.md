# Commentable Setup Guide

## Prerequisites

- Swift 6.0+
- macOS 13+
- PostgreSQL
- OpenAI API Key

## Getting Started

### 1. Environment Variables

Create or update your `.env` file with the following variables:

```bash
# Database Configuration
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=vapor_username
DATABASE_PASSWORD=vapor_password
DATABASE_NAME=vapor_database

# OpenAI API Key (required for moderation)
OPENAI_API_KEY=your_openai_api_key_here
```

### 2. Database Setup

**Option A: Using Docker Compose**

```bash
# Start PostgreSQL
docker compose up db

# In another terminal, run migrations
docker compose run migrate
```

**Option B: Local PostgreSQL**

```bash
# Create the database
createdb commentable

# Run migrations
swift run commentable migrate
```

### 3. Build and Run

```bash
# Build the project
swift build

# Run the server
swift run
```

The server will start on `http://localhost:8080`

## Usage

### 1. Register a User

Visit `http://localhost:8080/register` and create an account with your email and password.

### 2. Login

After registration, you'll be redirected to `http://localhost:8080/login`. Login with your credentials.

### 3. Add a Website

Once logged in, click "Add Website" on the dashboard and provide:
- **Name**: A friendly name for your website
- **Domain**: Your website's domain (e.g., `example.com`)

### 4. Get Embed Code

After adding a website, expand the "Embed Code" section to copy the iframe code. This code includes:
- An iframe that loads the comment widget
- Auto-detection of the current page URL

### 5. Configure Moderation Prompts (Optional)

Navigate to the moderation prompts section for your website to add custom moderation rules. For example:
- "Reject comments containing profanity"
- "Reject spam or promotional content"
- "Reject comments that are off-topic"

### 6. Embed Comments on Your Site

Paste the embed code on any page where you want comments. The system will:
1. Automatically create a page entry when first loaded
2. Accept anonymous or named comments
3. Run OpenAI moderation on all comments
4. Apply your custom moderation prompts
5. Display only approved comments

## API Endpoints

### Authentication

- `POST /auth/register` - Register a new user
- `POST /auth/login` - Login (sets session cookie)
- `POST /auth/logout` - Logout
- `GET /auth/me` - Get current user

### Websites

- `GET /websites` - List user's websites
- `POST /websites` - Create a website
- `GET /websites/:id` - Get website details
- `DELETE /websites/:id` - Delete a website
- `GET /websites/:id/pages` - List pages for a website
- `GET /websites/:id/comments` - List all comments for a website

### Moderation Prompts

- `GET /websites/:websiteID/moderation-prompts` - List prompts
- `POST /websites/:websiteID/moderation-prompts` - Create prompt
- `PATCH /websites/:websiteID/moderation-prompts/:id` - Update prompt
- `DELETE /websites/:websiteID/moderation-prompts/:id` - Delete prompt
- `POST /websites/:websiteID/moderation-prompts/rerun` - Re-run moderation on pending comments

### Public Embed Endpoints

- `GET /embed/:websiteID?url=<page-url>` - Load comment widget
- `POST /embed/:websiteID/comment` - Post a new comment

## Features Implemented

✅ User authentication with email/password
✅ Website management
✅ Auto-created pages when embed is used
✅ Anonymous comments
✅ OpenAI moderation integration (omni-moderation-latest)
✅ Custom moderation prompts per website
✅ Re-run moderation after updating prompts
✅ Neo-brutalist design with minimal CSS
✅ Iframe embed support with auto URL detection
✅ Dashboard for managing websites, pages, and comments
✅ Session-based authentication with cookies

## Architecture

- **Backend**: Vapor 4 (Swift)
- **Database**: PostgreSQL with Fluent ORM
- **View Engine**: Leaf templates
- **Styling**: Neo-brutalist CSS (minimal, flat design with bold borders)
- **Moderation**: OpenAI API (moderation + custom GPT-4o-mini prompts)
- **Frontend**: Vanilla JavaScript (no frameworks)

## Neo-Brutalist Design

The comment widget and dashboard feature:
- Bold black borders (3-4px)
- Flat colors with no gradients
- Drop shadows for depth
- Monospace font (Courier New)
- High contrast design
- Uppercase labels
- Minimal animations (transform on hover)

## Security Notes

- Passwords are hashed with Bcrypt
- Sessions expire after 30 days
- HTTP-only cookies prevent XSS
- CSRF protection via SameSite cookies
- All comments are moderated before display
- OpenAI moderation checks for harmful content

## Development

```bash
# Run tests
swift test

# Run a single test
swift test --filter <TestName>

# Build for production
swift build -c release

# Run migrations
swift run commentable migrate

# Revert migrations
swift run commentable migrate --revert
```

## Troubleshooting

**Database connection issues:**
- Ensure PostgreSQL is running
- Check your `.env` file has correct credentials
- Verify the database exists

**OpenAI API errors:**
- Ensure `OPENAI_API_KEY` is set in `.env`
- Check your API key is valid and has credits
- View logs for detailed error messages

**Build errors:**
- Ensure you have Swift 6.0+
- Run `swift package clean` and rebuild
- Check all dependencies are fetched correctly
