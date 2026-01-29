# Ninetynine Staples

A Magic: The Gathering collection and deck management platform built with Rails 8 and Stimulus.js.

## Overview

Ninetynine Staples helps MTG players track their card collections, build decks, and monitor Commander game statistics. The name references the 99-card Commander format and the concept of "staples" (commonly played cards).

## Features

### Collection Management
- Create and manage multiple card collections
- Track card quantities (regular, foil, proxies)
- Record purchase prices and monitor collection value over time
- Bulk import cards via card scanner
- Public/private collection visibility

### Deck Building
- Build decks from your collections or add new cards
- Mainboard and sideboard support
- Deck staging system for cards in progress
- Swap card printings and sources between collections

### Commander Game Tracker
- Log games with detailed statistics (wins, turn count, win conditions)
- Track performance by deck, opponent, and bracket level
- Fun and performance ratings
- Dashboard with comprehensive stats and visualizations

### Preconstructed Decks
- Browse official precons from Magic sets
- View deck composition and import into your collection

### Card Database
- Full card metadata from Scryfall API
- Price tracking and history
- Format legality information

## Tech Stack

**Backend**
- Ruby on Rails 8.1
- PostgreSQL
- Solid Queue (background jobs)

**Frontend**
- Stimulus.js
- Turbo Rails
- Tailwind CSS 4

**Testing**
- RSpec
- Factory Bot
- Capybara

## Getting Started

### Prerequisites
- Ruby 3.x
- PostgreSQL
- Node.js

### Installation

1. Clone the repository
```bash
git clone https://github.com/denvermullets/ninetynine-staples-mono.git
cd ninetynine-staples-mono
```

2. Install dependencies
```bash
bundle install
npm install
```

3. Setup the database

**Important:** Solid Queue loads schema first instead of migrations, so run:
```bash
rails db:prepare
```

Then run migrations:
```bash
rails db:migrate:primary
```

To rollback:
```bash
rails db:rollback:primary
```

4. Start the server
```bash
bin/dev
```

5. Start background jobs (separate terminal)
```bash
bin/jobs
```

The application will be available at `http://localhost:3000`.

### Background Jobs

The app uses Solid Queue for background processing (card data syncing, price updates, value history recording). Jobs are managed through Mission Control at `/jobs`.

## Project Structure

```
app/
  controllers/     # Request handlers organized by feature
  models/          # Domain models (User, Collection, MagicCard, etc.)
  views/           # ERB templates
  javascript/
    controllers/   # Stimulus controllers for interactivity
  jobs/            # Background job processors
  services/        # Business logic (deck building, search, etc.)

config/
  database.yml     # Multi-database configuration
  routes.rb        # Application routing

db/
  schema.rb        # Primary database schema
  queue_schema.rb  # Job queue schema
```

## Key Models

- **User** - Account with collections, decks, and game records
- **Collection** - Container for cards with type variations (bulk, deck, commander)
- **MagicCard** - Card metadata from Scryfall
- **CollectionMagicCard** - Card ownership with quantities and prices
- **TrackedDeck** - Commander deck with statistics
- **CommanderGame** - Game record with win conditions and ratings
- **PreconDeck** - Official preconstructed deck listings

## External Integrations

- **Scryfall API** - Card data and pricing information

## License

This project is for personal use.
