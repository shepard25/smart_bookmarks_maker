# n8n Smart Bookmark Pipeline

![Project cover](./assets/readme-cover.svg)

A local `n8n` setup that accepts a link from Telegram, checks duplicates in Postgres, pulls metadata via Firecrawl, classifies the resource with OpenAI, and saves the result to Notion and the local database.

The current repository contents look more like a smart bookmarking pipeline than a Twitter parser. This README describes what is actually in the repo right now.

## Features

- accepts a Telegram message and extracts a URL from it;
- checks whether the link already exists in the `bookmarks` table;
- if the link is new, scrapes the page through Firecrawl;
- extracts factual metadata using a dedicated AI agent;
- assigns `format`, `topic`, `function`, and `tech_stack` facets using values already present in the database;
- writes the result into Notion;
- stores the same facets and core fields in Postgres;
- sends a reply back to the user in Telegram.

## Architecture

Main flow:

`Telegram -> n8n workflow -> Postgres duplicate check -> Firecrawl -> OpenAI agents -> Notion + Postgres`

Services defined in `docker-compose.yaml`:

- `postgres` based on `postgres:18`;
- `pgadmin` for data inspection at `http://localhost:5050`;
- `n8n` at `http://localhost:5678`.

## Workflow Overview

Main workflow:

- [`bookmarks/workflow/website to bookmark _ AI tags -_ Notion upsert.json`](./bookmarks/workflow/website%20to%20bookmark%20_%20AI%20tags%20-_%20Notion%20upsert.json)

What it does:

1. A Telegram trigger receives a message.
2. A JS node extracts the URL and the remaining user text.
3. The sub-workflow [`bookmarks/workflow/Check link in DB.json`](./bookmarks/workflow/Check%20link%20in%20DB.json) checks whether the URL already exists in Postgres.
4. If the link already exists, the bot replies with `Already exists!`.
5. If the link is new, Firecrawl runs and, in parallel, the workflow loads the library of existing facets from the database.
6. `Agent: info extractor` pulls factual fields such as `Title`, `URL`, `Cover`, `Person`, and `Raw metadata`.
7. `Agent: Facet extractor` assigns facets while trying to reuse values already present in the database.
8. The outputs are merged, then:
   - a page is created in Notion;
   - a local row is inserted into `bookmarks`;
   - the user receives `Nice! Now you have it! ;)`.

## Database

The initialization schema is located at:

- [`bookmarks/db/schema_roll.sql`](./bookmarks/db/schema_roll.sql)

It creates:

- `bkmrk_users` for user configuration and subscription state;
- `bkmrk_user_auth` for Telegram ID mapping;
- `bookmarks` for links and facets;
- GIN indexes for facet arrays;
- `v_user_config` for fast access to user settings.

The `bookmarks` table currently uses these arrays:

- `facet_format`
- `facet_topic`
- `facet_function`
- `facet_tech_stack`

## Repository Structure

```text
.
|-- docker-compose.yaml
|-- bookmarks
|   |-- db
|   |   `-- schema_roll.sql
|   |-- prompts
|   |   |-- Agent Facet extractor
|   |   |-- Agent info extractor
|   |   `-- firecrawl_parser
|   |-- workflow
|   |   |-- Check link in DB.json
|   |   `-- website to bookmark _ AI tags -_ Notion upsert.json
|   `-- json
|       |-- layer1.json
|       `-- layer1_v2.json
|-- agency-agents
|-- n8n_data
|-- pgadmin_data
`-- postgres_data
```

## Quick Start

### 1. Start the services

```bash
docker compose up -d
```

After startup:

- `n8n`: `http://localhost:5678`
- `pgAdmin`: `http://localhost:5050`

Local default credentials from compose:

- `n8n`: `admin / admin`
- `pgAdmin`: `admin@admin.com / admin`
- `Postgres`: `n8n / n8n / n8n`

### 2. Import workflows into n8n

Import both JSON files from `bookmarks/workflow`.

Recommended order:

1. `Check link in DB.json`
2. `website to bookmark _ AI tags -_ Notion upsert.json`

### 3. Configure credentials in n8n

You need working credentials for:

- Telegram Bot API
- OpenAI
- Firecrawl
- Postgres
- Notion

### 4. Check the webhook URL

The compose file currently contains:

```env
WEBHOOK_URL=https://uncleavable-phung-nonfeeling.ngrok-free.dev
```

If this address is no longer valid, the Telegram trigger will not receive incoming messages correctly. For local development, this value should be updated to match the current tunnel.

## Things To Fix Before Real Use

- `docker-compose.yaml` currently hardcodes usernames, passwords, and `N8N_ENCRYPTION_KEY`.
- The workflow uses a test `user_id = 777` when inserting into `bookmarks`.
- The repo contains stateful directories such as `n8n_data`, `postgres_data`, and `pgadmin_data`; for a public repository this is usually unnecessary.
- One workflow contains direct references to a specific Notion database and named credentials from a local instance.

## Hero Image Idea

If you want to replace the current SVG with a more polished hero image, the best direction is a cinematic product scene rather than a logo-style graphic.

Suggested prompt:

```text
Cinematic product illustration of an AI bookmarking pipeline. Telegram chat on the left, glowing data stream in the center, structured knowledge cards and database facets on the right. Warm editorial lighting, tactile glass UI panels, orange-teal palette, modern workflow automation aesthetic, high detail, 16:9.
```

Suggested headline:

`Turn raw links into structured knowledge`

## Limitations

I can locally generate and save an illustration, banner, SVG diagram, or mock-style cover in the repo, like the one used in this README.

I cannot directly generate a photorealistic image "like Midjourney / Flux / DALL-E" in the current environment, because there is no connected image model here. But I can:

- prepare a precise prompt;
- create an SVG/PNG cover in code;
- embed the generated file into the README.
