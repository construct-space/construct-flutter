# Construct Companion — roadmap

_Last updated: 2026-05-07_

## Framing

**Construct Companion is the always-with-you remote for your already-running
workstation.** It is not a parallel construct. It is not a place to do
deep work. It is the device that's in your pocket while your desktop's
operator keeps running on the office Mac, and its job is to:

1. **Extend the operator's reach** to places the desktop can't go.
2. **Capture things the desktop wasn't ready for** — a photo, an idea
   on the train, a URL from another app.
3. **Receive ambient signals** — notifications, status, completions —
   on the device you're actually looking at.
4. **Voice-first** where typing is awkward.

What it explicitly **is not**:

- A second editing surface for spaces. Spaces that need a real cursor,
  a file system, or multi-pane layout stay on desktop. Mobile may show
  read-only summaries or hand off to the desktop, but it does not host
  the canvas.
- A divergent state store. The operator (and through it, delivery-api)
  is the source of truth for everything visible on mobile. Mobile may
  cache for offline read, but writes always round-trip.
- A separate product roadmap. Companion features shrink-wrap desktop
  features. If something doesn't make the desktop more useful, it
  probably doesn't belong here.

## What's built (2026-05-07)

| Capability                  | Where                              | Status |
| --------------------------- | ---------------------------------- | ------ |
| Email + passkey login       | `lib/src/auth`                     | ✅     |
| Notification inbox + push   | `lib/src/notifications` + FCM      | ✅     |
| Ask the Assistant (live)    | `lib/src/assistant` + WS           | ✅     |
| Cross-device chunk streaming | operator → bus → mobile           | ✅     |
| Construct theme parity      | `lib/src/theme/construct_theme.dart` | ✅   |

The cross-device bus shipped today — phone publishes `assistant.ask`,
operator on the desktop runs it, chunks stream back. That same channel
is the foundation for everything in the next sections.

## Tier 1 — Mobile handoff for actions (next)

When the assistant returns an action block today, mobile shows a chip
that toasts "opens on desktop, mobile handoff coming soon." The right
fix is a small set of `device.command` cmds the desktop subscribes to:

- `desktop.navigate {path}` — desktop routes to `/app/<space>` and
  brings the window forward.
- `desktop.open_url {url, mode: browser|panel|window}` — same as
  the desktop-internal `browser_open_host`.
- `desktop.space.run {spaceId, action, args}` — invoke a space's
  declared action (board create card, calendar add event, …).

Server work: extend `allowedRelayCmds`. Operator: ignore (these are
desktop-targeted). Desktop: a small dispatcher in `useDeviceBus` that
maps cmds to existing Tauri / router calls.

## Tier 2 — Capture surfaces

Things the operator should know about that are easier to capture on a
phone:

- **Share-sheet target** (iOS Share Extension / Android Intent filter):
  send a URL, selected text, photo, or document into a "send to
  operator" pipe. The operator stores it as a notification with
  `source:"capture"` and routes it to whichever space is currently
  active (or asks the user).
- **Camera → OCR**. Snap a whiteboard, code on a screen, a receipt;
  operator OCRs and ingests. Likely uses the existing assistant.ask
  pipe with an image attachment — bus envelope grows a `payload.image`
  field.
- **Voice memo → transcribe + ingest**. Long-press to record, send to
  operator, get a clean transcript routed to today's note / project.
- **Quick text** ("idea jar"). One-tap capture, lands in a known
  inbox space on desktop.

All four reuse the bus. The only new server work is whitelisting more
cmds; no new endpoints.

## Tier 3 — Ambient status & control

Make the phone aware of what the operator is doing without forcing the
user to open the app:

- **Live Activity** (iOS Dynamic Island + Lock Screen) when an
  assistant.ask is running — shows the current chunk stream, with
  cancel button.
- **Lock-screen widget**: unread notification count + last assistant
  answer headline.
- **Apple Watch companion**: notification glance + dictate a quick
  ask via Siri.
- **Notification action buttons**: approve / reject / snooze a
  notification inline (e.g. "Org invite — accept / decline" without
  opening the app).
- **Operator status indicator**: a small chip on Home that mirrors
  the desktop tray's 🟢/🔴 — useful when you sent an ask and it
  hasn't started, lets you see whether the office Mac is reachable
  before you stare at "thinking…" forever.

Bus envelopes already cover most of this; the missing piece is the
operator publishing low-frequency `operator.status` heartbeats so a
disconnected desktop is detectable from mobile. ~30s ping.

## Tier 4 — Read-only views

Mirror, don't edit:

- **Activity feed** — what agents have been doing today (last N turns
  across the operator). Powered by an existing/new
  `/api/operator/activity` REST endpoint.
- **Calendar / board / notes preview** — read-only summary. Tap a
  preview to "open on desktop" via the Tier 1 navigate cmd.
- **Cost / token usage today** — anchors the user to operator state
  without giving them controls.
- **Recent files / projects** — quick switch on desktop via "make
  this active".

These don't expand mobile's editing surface; they just make it a
useful glance device.

## Tier 5 — Continuity

Two-way handoff:

- **Continue on mobile** — long-press a desktop turn, "send to phone";
  phone receives via the bus and renders it as the head of a new
  AskScreen turn so the user can keep talking.
- **Continue on desktop** — typing on phone, tap "expand on desktop";
  it ships the draft over the bus and the desktop pre-fills the
  AssistantPanel input.
- **Pickup-where-you-left-off** — on next desktop launch, surface a
  notification "you started this on phone, continue?" Tied to a
  short-lived `pending_handoff` on the operator side.

## Cross-cutting

### Auth & identity

Already in place: cat_token in iOS Keychain (`first_unlock`). Token
survives reinstall (Keychain is bundle-id scoped). Sign-in supports
password + passkey + 2FA. No changes needed for the tiers above.

### Push delivery

FCM works for backgrounded / killed app. WS works while the AskScreen
is open. The notification inbox endpoint is the durable store. We do
not need a separate push provider.

### Networking

Phone goes through the my.construct.space gateway for REST (auth via
bearer header), and direct to api.construct.delivery for WS (because
the gateway's auth_request can't validate `?token=` on a WS
handshake). This split is documented in `lib/src/providers.dart` and
should stay until the gateway grows query-token auth.

### Offline

Pure offline mode is out of scope for v1. The operator IS the source
of truth, so anything the mobile shows offline is by definition stale.
We can cache the last inbox payload + last few turns for read-only
display, but writes (asks, captures) require connectivity.

## Non-goals

- **Local agent on mobile**. The runner runs on the desktop. Phones
  should not embed an LLM, even a small one.
- **Mobile space hosts**. Spaces are desktop-first. If a space wants
  mobile parity, it ships a mobile-flavored read view via this
  companion, not by porting its UI.
- **Replacing the desktop tray**. The tray on the desktop is the
  desktop's own status surface. Mobile observes via WS but doesn't
  own the lifecycle.

## Sequencing

Concrete next-up items, in order I'd ship:

1. **`desktop.navigate` cmd + chip wiring** — closes the loop on the
   action chips we already render. ~half-day, both ends.
2. **Operator status heartbeat** + a small chip on the AskScreen
   header showing "operator: 🟢 ready" / "🔴 unreachable" so users
   trust the silence (or don't). ~half-day.
3. **Share-sheet target on iOS** — biggest mobile-native win for the
   smallest server work. ~day on iOS (extension target + JSON pipe to
   the bus), zero on the operator/server side.
4. **Voice → ask via Siri Shortcut** — system-wide voice trigger.
   ~half-day.
5. **Live Activity for in-flight asks** — the visible payoff of the
   streaming infrastructure. ~day on iOS.

Tier 4 + 5 wait until the above land — the mobile shape will be
clearer by then, and we'll have signals about which read-only views
people actually want.
