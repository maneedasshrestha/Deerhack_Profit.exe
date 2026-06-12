# ACELY

**A Duolingo for entrance-exam prep — adaptive, gamified, and built to beat burnout.**

ACELY turns competitive-exam preparation (starting with Nepal's **IOE engineering
entrance**) into a structured daily habit. Instead of handing aspirants a static
syllabus, it generates a **weekly study plan calibrated to each learner's current
level**, drives short daily MCQ practice, reinforces memory with spaced-repetition
flashcards, validates *real* understanding through a **Feynman coach**, and keeps
motivation high with streaks, stats, and live **duel battles**.

> The core bet: aspirants don't fail because the material is unavailable — they
> fail because they **burn out, lose consistency, and forget what they studied**.
> ACELY attacks those three failure modes directly.

---

## The problem

Competitive-exam aspirants in Nepal hit three recurring walls:

1. **Burnout & inconsistency** — long, unstructured marathons lead to dropped routines.
2. **Low motivation** — without feedback loops or accountability, daily study feels thankless.
3. **Poor retention** — material studied weeks ago is gone by exam day.

Most prep resources are content dumps (PDFs, video playlists, question banks). They
optimize for *coverage*, not for *habit, retention, or genuine understanding*.

| Problem | ACELY's mechanism |
|---|---|
| Burnout & inconsistency | Bite-sized daily sessions + streaks + winnable daily goals |
| Low motivation | XP, levels, leagues + social accountability via duels & leaderboards |
| Poor retention | Spaced-repetition flashcards triggered after a chapter is studied |
| Shallow understanding | Feynman coach — you explain a topic, it grades your comprehension |
| One-size-fits-all plans | An adaptive weekly plan engine driven by continuous assessment |

**Design principle:** keep daily load small and winnable, recalibrate weekly, and
make progress *feel* visible. **Consistency beats intensity.**

---

## What's in the app

The Flutter client is organised around three tabs plus a profile, all sharing one
light, purple-accented design language. A persistent top bar keeps the **exam
countdown** and **account** reachable from anywhere.

### 📚 Learn — the weekly plan
A Duolingo-style path for the current week, generated from the onboarding inputs.
Each week is a sequence of levels:

- **Daily MCQ levels** — mixed questions across English, Physics, Chemistry, and Maths,
  with **guided, Socratic feedback**: a wrong first attempt surfaces a *hint* that
  nudges you toward the answer rather than handing it over; only a second miss reveals
  the answer along with *why each distractor is wrong*. Questions can be **starred**
  for later revision.
- **Bonus flashcard level** — a Tinder-style true/false swipe deck for formulas and
  facts, on a spaced-repetition schedule.
- **Weekend mock test** — timed, exam-conditions, no feedback until submission.
  Tracks per-question time, surfaces where you stalled, and **its result drafts next
  week's plan** to reinforce the weak points it exposed.

### 🧠 Coach — the Feynman technique
Pick a topic and explain it out loud (or by text). The coach listens, probes the
vague spots, and returns **constructive criticism on exactly where your explanation
fell short** — every unexplained term flagged, with a clarity trend across attempts.
A clean session history lets you re-explain and watch the score climb.
*(This is the one feature wired to a live LLM today — see [Architecture](#architecture).)*

### ⚔️ Duel — race a friend
Real-time, head-to-head rapid-fire MCQ: same questions, fastest correct answer wins.
A live scoreboard and dual progress tracks make it a fun accountability layer.

### 👤 Profile — your plan at a glance
- **Syllabus coverage** per subject with completion rings/bars.
- **Your plan** as a three-step timeline: last mock → this week's targeted weak points
  → the Sunday retest that drafts the next week.
- **Starred questions**, collapsed until you expand them, each revealing its answer on tap.

---

## End-to-end user flow

```
Register
   │
   ▼
Onboarding  (exam · days left · daily time · target marks · quick self-assessment)
   │
   ▼
Week 1 plan generated (provisional)
   │
   ▼
┌──────────── Daily loop (through the week) ───────────────────┐
│  MCQ practice  →  Flashcard review (spaced)  →  Feynman check │
│  (star questions · earn XP · keep streak · optional duels)    │
└───────────────────────────────────────────────────────────────┘
   │
   ▼
Weekend mock test (mirrors the real exam)
   │
   ▼
Performance analysis → next week's plan proposed
   │
   ▼
User reviews & edits the plan (select/deselect focus chapters)
   │
   └──────────────► back to the daily loop (until D-day)
```

---

## The adaptive engine (the differentiator)

A simple, **explainable rules-based engine** — no ML needed on day one.

**Per-chapter mastery score (0–100)** is updated from:
- MCQ accuracy (weighted by recency)
- Weekend-test performance (highest weight — the cleanest signal)
- Feynman comprehension score
- Spaced-repetition recall success

**Each week's plan is generated by:**
1. Computing the time budget = `days_left × daily_minutes`.
2. Ranking chapters by `priority = (1 − mastery) × syllabus_weight × exam_proximity`.
3. Allocating the week's sessions proportionally to priority.
4. Reserving a slice for maintenance review of mastered chapters.
5. Presenting the plan → applying user edits → locking it for the week.

As `days_left` shrinks, the `exam_proximity` factor shifts weight toward high-yield
chapters and away from low-mastery-but-low-weight topics (triage).

---

## Architecture

Three tiers. For the hackathon everything collapses into **one mobile app + one
backend + one database** — a modular monolith, *not* microservices.

```
┌─────────────────────────────┐     REST (plans, practice, scores, profile)
│  Flutter app  (this repo)   │ ───────────────────────────────────────────┐
│  Riverpod · light/purple UI │     WebSocket (duels only)                  │
└─────────────────────────────┘ ────────────────────────────────┐          │
                                                                 ▼          ▼
                                                  ┌──────────────────────────────┐
                                                  │  Node.js monolith (modules)   │
                                                  │  auth · plan engine · practice│
                                                  │  spaced-rep · gamification ·  │
                                                  │  Feynman grader · duel engine │
                                                  │  · notifications              │
                                                  └──────────────────────────────┘
                                                       │        │         │
                                                  ┌────▼──┐ ┌───▼───┐ ┌────▼────┐
                                                  │Postgres│ │ Redis │ │ LLM API │
                                                  └────────┘ └───────┘ └─────────┘
                                                                       (+ FCM push)
```

### Current implementation state (POC)

| Area | Today in this repo | Production target |
|---|---|---|
| **Frontend** | Full Flutter app, all four sections built, polished animations. Data is **mocked** in `lib/features/home/domain/` so screens are demo-able without a backend. | Wire each screen to the REST API; offline-first local store; design system. |
| **Feynman coach** | **Live** — `backend/` is a Node + Express proxy that holds the LLM key and calls **Google Gemini** for the "curious student" turn. | Curated per-topic rubrics, guardrails, quality monitoring, optional speech-to-text. |
| **Plan engine / practice / mock test** | Modelled with mock data on the client (weekly plan, questions, mastery, weak points). | Rules-based engine + `attempt_log` + mastery recompute, served from Postgres. |
| **Duel** | Mock matchmaking + a **scripted opponent** so the live race is demo-able end-to-end. | Socket.IO + in-memory state (hackathon) → Redis-backed, server-authoritative, anti-cheat (production). |
| **Auth / gamification / notifications** | Not yet built; streak/XP/countdown shown from mock data. | Firebase Auth/JWT, server-side counters, `node-cron` + FCM. |

### Hackathon vs. production at a glance

| Concern | Hackathon | Production |
|---|---|---|
| Backend shape | Single Node.js monolith (modules = folders) | Services split by load profile (duel + LLM scale independently) |
| Auth | Firebase Auth or simple JWT | Refresh rotation, OAuth, verification, revocation |
| Plan engine | Rules-based functions | Versioned service, eventually ML-assisted |
| Real-time duels | In-memory state + Socket.IO | Redis-backed, server-authoritative, anti-cheat |
| Leaderboards | DB query / in-memory | Redis sorted sets |
| Feynman grading | Direct LLM call + rubric prompt | Curated rubrics, guardrails, drift monitoring |
| Notifications | `node-cron` + FCM | BullMQ jobs, send-time optimization |
| Data | One Postgres, seeded deeply | Replicas, indexing, backups, partitioning |

> **Why the modular monolith?** A single Node process with internal modules demos
> identically to a "real" distributed system and is buildable in a hackathon window.
> Each module below is just a folder of routes + service functions, not a separate server.

### Backend modules (target)

- **Auth** — registration, login, endpoint protection (Firebase Auth or JWT).
- **Plan engine** *(differentiator)* — generates/regenerates weekly plans; applies user edits.
- **Practice & tests** — serves MCQ sets & the weekend test; logs every attempt; recomputes mastery.
- **Spaced repetition** — SM-2 / Leitner scheduling (`next_review_at`, `interval`, `ease`).
- **Gamification** — XP, levels, streaks (with **streak-freeze**), D-day countdown, leaderboards.
- **Feynman grader** *(live today)* — rubric-based LLM grading; key held server-side.
- **Duel engine** — Socket.IO namespace; in-memory duel state for the hackathon.
- **Notifications** — `node-cron` daily job → FCM. Encouraging, never guilt-tripping.

---

## High-level data model

- **User** — id, name, exam_type, exam_date, daily_minutes, target_marks, xp, level, streak_count, streak_freeze
- **Subject / Chapter** — id, name, syllabus_weight
- **Question** — id, chapter_id, type, body, options, correct_answer, explanation, difficulty
- **WeeklyPlan / PlanItem** — week_number, status; chapter_id, allocated/completed sessions
- **AttemptLog** — user_id, question_id, correct, time_taken, timestamp
- **MasteryScore** — user_id, chapter_id, score, last_updated
- **Flashcard / ReviewSchedule** — card_id, user_id, next_review_at, interval, ease
- **FeynmanAttempt** — user_id, topic_id, transcript, score, missed_points
- **SavedQuestion**, **Duel**, **Achievement / UserAchievement**

---

## Repo structure

```
Deerhack_Profit.exe/
├── backend/    Node + Express proxy that holds the LLM key and calls Gemini
│               (currently serves the Feynman coach; other modules to follow)
└── frontend/   Flutter app
    └── lib/
        ├── app.dart                     MaterialApp (light theme, ACELY)
        ├── shell/main_shell.dart        3-tab shell + shared top bar
        ├── core/
        │   ├── theme/                   palette, typography, theme tokens
        │   └── widgets/ui_kit.dart      shared cards, buttons, rings, gestures
        └── features/
            ├── home/                    Learn path, lessons, flashcards,
            │                            mock test, profile, plan/mock data
            ├── feynman/                 Coach: live voice loop + reflection
            └── duel/                    Duel lobby + live race
```

---

## Running it

### Frontend (Flutter)

```bash
cd frontend
flutter pub get
flutter run            # pick a device/emulator
```

The app runs standalone on mock data — every screen is explorable without the backend.
Only the **Coach** tab needs the backend (and an LLM key) to grade real explanations.

### Backend (Node — powers the Feynman coach)

```bash
cd backend
npm install
cp .env.example .env   # then set GEMINI_API_KEY
npm run dev            # http://localhost:8787
```

The server exposes:

```
POST /v1/student/turn
  body: { concept: string, explanation: string, history: Turn[] }
  200 : { reaction, question, clarity (0-100 int), jargon: string[] }
```

The LLM key lives **only** on the server — it never ships inside the Flutter binary,
where it would be trivially extractable.

---

## Build order (hackathon)

1. **Skeleton** — Flutter shell + Node backend + Postgres + auth, wired end-to-end.
2. **Core loop** — onboarding → plan engine → daily MCQ practice → attempt logging.
3. **Recalibration** — weekend test → mastery recompute → next week's plan with user edits *(the differentiator)*.
4. **Gamification quick wins** — streaks + XP + D-day countdown.
5. **One showcase feature** — the Feynman coach (best story-per-effort).
6. **Stretch** — duel battles (riskiest live demo; build last).

> A working *onboarding → adaptive plan → practice → recalibrated plan* loop plus a
> live Feynman demo beats ten half-finished features. **Depth on the core, not breadth.**

---

## Anti-burnout, on purpose

ACELY deliberately avoids the Duolingo mechanics that *increase* stress:

- **No hearts/lives** that lock you out after mistakes — punishing wrong answers
  discourages the exact practice we want.
- **Encouraging nudges, not shame** — notifications are framed as support.
- **Streak-freeze from day one** — removes the all-or-nothing pressure that makes
  people rage-quit after a single missed day.

---

## Roadmap

- ML-based plan optimization (replacing the rules engine once usage data exists)
- Voice-based Feynman coach with pronunciation-tolerant transcription
- Clans / study groups and group duels
- Localized content and Nepali-language support
- A predictive "exam-readiness score" projecting expected vs. target marks
