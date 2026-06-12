# Feynman — "Teach a Student"

Practice the Feynman technique: pick a concept and explain it out loud as if
teaching a curious ~12-year-old. An AI "student" listens, reacts, and asks the
naive follow-up questions that expose the gaps in your understanding. Ending a
session leaves behind a reviewable artifact — the full transcript, every flagged
gap, and your clarity trend — because **reflection is the payoff of the
technique**.

```
m:\Projects\deer_hack_profit_exe
├── backend/    Node/Express proxy that holds the LLM key (never the app)
└── frontend/   Flutter app (the feature module)
```

---

## The loop (a state machine)

```
idle → listening → transcribing → studentThinking → studentSpeaking → idle
                                                          ↑__________repeat__________|
        (end session) → reflection
```

Modelled explicitly as a sealed `FeynmanPhase` hierarchy
(`lib/features/feynman/domain/models/feynman_phase.dart`) owned by a single
`FeynmanController` (a Riverpod `StateNotifier`). **The UI is a pure function of
the current state.** Exactly one of speech-to-text / text-to-speech is active at
a time — the controller stops the recognizer before TTS plays and only reopens
the mic once playback finishes, which kills the mic→speaker→mic feedback loop.

Two screens:

- **Live voice mode** (`live_voice_screen.dart`) — a full-screen immersive
  experience built around an amplitude-reactive **orb** with three visually
  distinct states (idle / listening / speaking, plus a gentle thinking pulse so
  the LLM pause never reads as frozen). Custom-painter driven
  (`widgets/orb/`). Minimal overlay: a status pill + elapsed timer, a single
  line of live caption, and a bottom bar (gaps counter → transcript, transcript
  icon, type-instead, end-session).
- **Reflection view** (`reflection_screen.dart`) — chat-style transcript with
  inline **wavy jargon underlines** (paired with a warning icon, so colour is
  never the sole signal), a large clarity score with a trend sparkline, the
  `1 Explain → 2 Gaps → 3 Simplify` indicator, a `v1 → v2 → v3` attempts strip,
  and **teach it again** (which versions the next attempt).

A shared-element **Hero** transition (`tag: 'feynman-orb'`) collapses the orb
into the reflection header rather than hard-swapping screens.

---

## Backend proxy contract

**No LLM/API key ships in the app** — it would be extractable from the binary.
The Flutter client only ever talks to the proxy you run; the proxy holds the key
and calls the model provider (Google Gemini, free tier).

### `POST /v1/student/turn`

Request:

```jsonc
{
  "concept": "photosynthesis",
  "explanation": "Plants take in light and turn it into food using chlorophyll…",
  "history": [
    { "role": "user",    "text": "earlier explanation…" },
    { "role": "student", "text": "earlier question…" }
  ]
}
```

- `concept` (string, required) — what's being taught.
- `explanation` (string, required, non-empty) — the latest spoken turn.
- `history` (array, optional) — prior turns for context. `role` is `"user"`
  (the learner) or `"student"` (the AI).

Response `200`:

```json
{
  "reaction": "Oh okay, that kind of makes sense...",
  "question": "But what actually is 'chlorophyll' — what does it do?",
  "clarity": 72,
  "jargon": ["chlorophyll", "thylakoid membrane"]
}
```

- `reaction` (string) — a short, human reaction spoken before the question.
- `question` (string) — exactly one naive follow-up.
- `clarity` (integer 0–100) — how clearly the learner explained.
- `jargon` (string[]) — terms used without explanation, copied verbatim so the
  client can underline them in the learner's own words.

Errors: `400` (bad request), `422` (model refusal), `5xx` (upstream error). The
client parses defensively regardless — it clamps `clarity` to 0–100, tolerates
missing fields, and falls back to a graceful question if parsing fails, so the
loop never dead-ends.

### `GET /health` → `{ "ok": true, "model": "gemini-2.0-flash" }`

The server (`backend/server.js`) asks Gemini for strict JSON via a
**`responseSchema`** (`responseMimeType: application/json`) and still
validates/clamps before responding.

---

## The `StudentEngine` seam (streaming upgrade path)

The UI and state machine depend only on:

```dart
abstract interface class StudentEngine {
  Future<StudentTurn> respond(StudentRequest request);
}
```

(`lib/features/feynman/domain/student_engine.dart`)

Two implementations exist today:

- `TurnBasedStudentEngine` — POSTs to the proxy contract above (the default
  production path).
- `MockStudentEngine` — offline/dev engine that runs the **entire loop with no
  backend**; it heuristically pulls "jargon" from your own words and scores
  clarity, so the reflection view has real-looking data. This is the default so
  the app is runnable out of the box.

Because the orb, state machine, and UI never reference how a reply is produced,
a realtime **streaming** backend (Gemini Live / OpenAI Realtime over WebSocket)
can be dropped in later as a new `StreamingStudentEngine implements
StudentEngine` — no UI changes. The turn-based `Future<StudentTurn>` is the
lowest common denominator both satisfy. During `studentThinking`, the orb keeps
a gentle animation so the turn-based pause is never visible as a freeze.

---

## Setup

### Frontend

```bash
cd frontend
flutter pub get
flutter run
```

Runs against the **mock engine** by default — full loop, no backend needed.
To use the real proxy, edit `appConfigProvider` in
`lib/features/feynman/application/providers.dart`:

```dart
const AppConfig(
  proxyBaseUrl: 'http://10.0.2.2:8787', // Android emulator; localhost on iOS/desktop
  useMockEngine: false,
);
```

Mic + speech permissions are declared in `android/.../AndroidManifest.xml` and
`ios/Runner/Info.plist`.

### Backend

```bash
cd backend
cp .env.example .env        # then put your GEMINI_API_KEY in .env
npm install
npm start                   # → http://localhost:8787
```

Get a free Gemini key at <https://aistudio.google.com/apikey>.

## Troubleshooting

**Gemini `429 RESOURCE_EXHAUSTED` / "quota of 0".** The key is valid but its
Google Cloud project has no free-tier quota in its region (you'll see
`quota_limit_value: "0"`). Fix it on Google's side — the code is correct:

- Create the key from **Google AI Studio** (<https://aistudio.google.com/apikey>)
  using the project AI Studio provisions for you — those get free-tier quota.
  Keys minted in a bare GCP project often have RPM = 0.
- Or, in Google Cloud, enable the **Generative Language API** and request quota.
- While quota is unavailable, flip `useMockEngine: true` in
  `lib/features/feynman/application/providers.dart` to run fully offline.

**Speech-to-text does nothing on an Android emulator.** Almost always the
emulator, not the app:

- Use an emulator image **with Google Play** (the AOSP images have no speech
  recognizer). Install/enable "Speech Services by Google".
- Emulator **…** (Extended controls) → **Microphone** → enable
  *"Virtual microphone uses host audio input"*, and grant your OS mic permission
  to the emulator.
- Grant the app the microphone permission when prompted.
- **A physical device is the reliable path** for STT/TTS — emulator audio is
  flaky. The app gives explicit "I didn't hear anything" feedback and a
  keyboard fallback when nothing is captured, so you can still drive the full
  loop by typing.

---

## Package choices (one-line justifications)

| Package          | Why |
|------------------|-----|
| `flutter_riverpod` | State management required by the brief; the loop is a `StateNotifier` exposing immutable state. |
| `speech_to_text`   | STT with a sound-level callback — used to drive the orb's listening amplitude. |
| `flutter_tts`      | TTS configured to a higher pitch / slower rate so the student reads as a character. |
| `hive` + `hive_flutter` | Local persistence: pure-Dart, **no native build step or codegen** (we store JSON), ideal for our small, structured sessions + versioned attempts. Chosen over Isar/Drift for that simplicity. |
| `http`             | Minimal client for the proxy call. |
| `google_fonts`     | Inter variable font for the typographic hierarchy. |

---

## Accessibility & robustness

- Every control has a semantic label; the live caption is a live region; the
  jargon underline is paired with an icon (colour is never the only signal).
- **Reduce-motion** is honoured — the orb holds a calm steady state and rings
  stop looping when the OS setting is on.
- Graceful handling of: denied mic permission (offer typing), no speech
  detected (gentle return to idle), network failure (recoverable error + retry,
  transcript preserved), and malformed model output (defensive parse + fallback
  question).
- Both **light and dark** themes (dark designed first), switchable at runtime.

## Architecture

```
frontend/lib/
├── app.dart                      MaterialApp + theme mode
├── main.dart                     Hive init + Riverpod overrides
├── core/                         theme, motion, haptics (cross-cutting)
└── features/feynman/
    ├── domain/                   models (sealed phase, state, session) + engine interface
    ├── data/                     engine impls (turn-based + mock) + Hive repository
    ├── application/              controller (state machine), services (STT/TTS), providers
    └── presentation/             screens + widgets (orb, transcript, sparkline, …)
```
