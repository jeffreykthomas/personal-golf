# Continuity Ledger - Coach Agent Integration

Last updated: 2026-03-04
Project: `personal-golf`
Primary goal: Floating in-app golf coach with onboarding interview, in-round assistance, pre/post-round support, tip recommendation + save/dismiss actions, and sibling Claw integration.

## 1) Current Status Snapshot

Implementation is partially complete and runnable:

- Coach UI shell is integrated and rendered globally for authenticated users.
- Backend coach session/message APIs are implemented.
- DB schema and models for coach sessions/messages/profiles are added and migrated.
- ActionCable channel for coach streaming events is in place.
- Tip recommendation/save/dismiss flows are wired through coach actions.
- Voice endpoints and client scaffolding exist, but provider integration is still placeholder-driven.
- Sibling `claw-service` exists and runs locally, but its response logic is currently deterministic/stubbed (not full NanoClaw runtime behavior yet).

## 2) Completed Work (Files Added/Changed)

### Backend domain + contracts
- `app/services/coach/event_contract.rb`
- `app/models/coach_session.rb`
- `app/models/coach_message.rb`
- `app/models/coach_profile.rb`
- `app/models/user.rb` (coach associations + AI profile extension)

### Migrations
- `db/migrate/20260304110000_create_coach_sessions.rb`
- `db/migrate/20260304110100_create_coach_messages.rb`
- `db/migrate/20260304110200_create_coach_profiles.rb`
- `db/migrate/20260304110300_change_coach_json_columns.rb`

### Controllers/services/channels
- `app/controllers/coach_sessions_controller.rb`
- `app/controllers/coach_messages_controller.rb`
- `app/controllers/coach_tip_actions_controller.rb`
- `app/controllers/coach_voice_sessions_controller.rb`
- `app/controllers/concerns/coach_feature.rb`
- `app/controllers/concerns/request_rate_limiter.rb`
- `app/services/claw_bridge_service.rb`
- `app/services/coach_tip_action_service.rb`
- `app/services/voice_session_service.rb`
- `app/channels/application_cable/channel.rb`
- `app/channels/coach_session_channel.rb`

### Frontend coach shell + channels + voice client
- `app/views/shared/_coach_fab.html.erb`
- `app/javascript/controllers/coach_panel_controller.js`
- `app/javascript/controllers/coach_launcher_controller.js`
- `app/javascript/channels/consumer.js`
- `app/javascript/channels/index.js`
- `app/javascript/channels/coach_session_channel.js`
- `app/javascript/lib/voice/convai_client.js`
- `app/javascript/application.js`
- `config/importmap.rb`

### Flow integration points
- `config/routes.rb`
- `app/controllers/onboarding_controller.rb`
- `app/controllers/users_controller.rb`
- `app/controllers/sessions_controller.rb`
- `app/controllers/application_controller.rb`
- `app/controllers/courses_controller.rb`
- `app/controllers/tips_controller.rb`
- `app/views/onboarding/welcome.html.erb`
- `app/views/onboarding/coach_interview.html.erb` (new)
- `app/views/onboarding/first_tip.html.erb` (skip link fix)
- `app/views/courses/hole.html.erb` (open-coach action button)
- `app/views/courses/show.html.erb` (open-coach action button)
- `app/views/tips/index.html.erb` (open-coach action button)
- `app/views/layouts/application.html.erb` (mount coach + stream + launcher)
- `app/views/pwa/service-worker.js` (coach/cable paths in network-first; cache version bumped)
- `app/assets/tailwind/application.css` (coach button styles)

### Sibling Claw scaffold
- `claw-service/package.json`
- `claw-service/tsconfig.json`
- `claw-service/README.md`
- `claw-service/src/server.ts`
- `claw-service/src/contracts/coach_events.ts`
- `claw-service/src/tools/db/read_user_context.ts`
- `claw-service/src/tools/db/write_coach_artifacts.ts`
- `claw-service/src/tools/db/recommend_tip.ts`
- `claw-service/src/tools/db/save_tip_for_user.ts`
- `claw-service/src/tools/db/dismiss_tip_for_user.ts`
- `.env.example` (coach env template)
- `Procfile.dev` (adds `claw` process)
- `.gitignore` (ignores `claw-service/node_modules`)

## 3) Critical Bugs Found + Fixed

1. **Importmap module resolution error**
   - Symptom: browser error resolving `channels/index`.
   - Fix:
     - `config/importmap.rb` added `pin "channels", to: "channels/index.js"`.
     - `app/javascript/application.js` uses `import "channels"`.

2. **Coach open buttons no-op**
   - Cause: inline `onclick` usage vulnerable to CSP constraints.
   - Fix:
     - Added Stimulus `coach_launcher_controller.js`.
     - Replaced inline handlers with `data-action="coach-launcher#open"`.

3. **500 on `POST /coach_sessions`**
   - Error: `ArgumentError` in `request_rate_limiter`.
   - Fix:
     - Corrected `Rails.cache.increment` usage and added nil-initialize fallback.

4. **JSON persistence failure (NOT NULL on coach JSON fields)**
   - Symptom: inserts used `NULL` for `context_data`/`metadata`/`profile_data`.
   - Fix:
     - Added migration to change those columns to JSON type.
     - Updated model attributes to `attribute :..., :json, default: {}`.

## 4) Runtime/Verification Notes

Commands run successfully:

- `bin/rails db:migrate`
- `bin/rails zeitwerk:check`
- `bin/rails routes | rg coach`
- `npx --prefix claw-service tsc --noEmit -p claw-service/tsconfig.json`
- Sibling service smoke-tested with curl and Rails bridge call.

Known non-blocking noise in logs:
- `GET /.well-known/appspecific/com.chrome.devtools.json` routing errors (Chrome/DevTools probe).

## 5) Current Architecture Reality

### What is real now
- Rails + Stimulus + ActionCable chat shell and APIs are real.
- Sibling service can run locally and respond over `/v1/coach/respond`.
- Tip action execution in Rails is real (`recommend/save/dismiss` endpoints + service logic).

### What is still stubbed
- `claw-service/src/server.ts` does deterministic intent handling.
- `claw-service/src/tools/db/*` are placeholders and do not execute full DB toolchains.
- Full NanoClaw runtime orchestration is not yet integrated into sibling service.
- Voice provider endpoints remain env-dependent placeholders.

## 6) Immediate Next Steps for Next Agent

1. **Integrate real local NanoClaw runtime**
   - Replace deterministic branch in `claw-service/src/server.ts` with calls into local `nanoclaw`.
   - Preserve existing request/response contract to avoid Rails/frontend changes.
   - Keep `transport: "app"` only.

2. **Implement real DB tool calls in sibling service**
   - Replace stubs in `claw-service/src/tools/db/*` with:
     - private Rails API calls, or
     - direct DB access with strict user-scoped filters.
   - Enforce mutation allowlist (tips, saves, dismisses, coach artifacts).

3. **Strengthen action semantics**
   - `save_tip` should only execute on explicit imperative user intent.
   - Add confidence/intention checks in bridge or sibling layer.

4. **Finish onboarding behavior**
   - Ensure 5-question flow deterministically completes and redirects.
   - Confirm `User` fields + `CoachProfile` data both persist correctly.

5. **Complete voice integration**
   - Wire actual provider signed URL + STT/TTS endpoints.
   - Validate mic permission handling and fallback UX.

6. **Add tests**
   - Controller tests for coach session/message/tip actions.
   - Service tests for `ClawBridgeService` and `CoachTipActionService`.
   - System test for open coach -> ask tip -> save tip.

## 7) Environment Expectations

Local `.env` expected values:

```bash
ENABLE_COACH_AGENT=true
CLAW_SIBLING_URL=http://127.0.0.1:4317
CLAW_SIBLING_TOKEN=dev-claw-token
```

Optional voice env vars remain commented in `.env.example`.

## 8) Handoff Warnings

- Repository has many unrelated modified files from prior work; do not revert unrelated changes.
- `claw-service` currently coexists with existing app state and is intended as adapter shell.
- If coach click fails again, first check:
  - browser console import errors,
  - `POST /coach_sessions` response code and payload,
  - `request_rate_limiter` behavior.

## 9) Quick Bring-up Checklist

1. `bin/dev`
2. Ensure `claw` process from `Procfile.dev` starts.
3. Hard refresh browser.
4. Click coach FAB or `Ask Coach` button.
5. Verify:
   - `POST /coach_sessions` returns 200,
   - then `POST /coach_sessions/:id/coach_messages` on send,
   - recommendation card shows and save/dismiss actions work.
