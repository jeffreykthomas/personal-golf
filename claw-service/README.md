# Sibling Claw Service

This folder contains a minimal sibling-service scaffold for the golf coach agent.

Transport model: **app-only**.  
This service is designed to communicate only with the Personal Golf app (Rails API + in-app websocket UI). It does not include Telegram/WhatsApp channel adapters.

## Contract

- Endpoint: `POST /v1/coach/respond`
- Endpoint: `POST /v1/report/respond`
- Auth: `Authorization: Bearer $CLAW_SIBLING_TOKEN` (optional in local dev)
- Request/response payloads: `src/contracts/coach_events.ts`, `src/contracts/report_events.ts`

## Local setup

```bash
cd claw-service
npm install
npm run dev
```

Service defaults to `http://127.0.0.1:4317`.

Run a one-off self-understanding report sync against Rails:

```bash
npm run reports:run
```

## Rails env wiring

Add these environment variables for Rails:

```bash
CLAW_SIBLING_URL=http://127.0.0.1:4317
CLAW_SIBLING_TOKEN=dev-claw-token
ENABLE_COACH_AGENT=true
```

And for the sibling service process:

```bash
CLAW_SIBLING_PORT=4317
CLAW_SIBLING_TOKEN=dev-claw-token
COACH_APP_URL=http://127.0.0.1:3000
AUTO_SELF_UNDERSTANDING_REPORTS_ENABLED=false
SELF_UNDERSTANDING_REPORT_INTERVAL_MS=86400000
SELF_UNDERSTANDING_REPORT_BATCH_SIZE=3
```

## Intended production wiring

- Keep service on private network only.
- Expose user-scoped DB tools through private Rails endpoints or constrained DB roles.
- Enforce write allowlists and append-only audit logs for all agent mutations.
