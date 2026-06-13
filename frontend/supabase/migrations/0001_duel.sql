-- ════════════════════════════════════════════════════════════════════════════
-- Duel / Versus mode — async challenge model.
--
-- Two tables:
--   • duel_players — every app instance self-registers one row (a stable local
--     UUID + display name), so challenges, the friends list and the leaderboard
--     all resolve to real rows instead of hardcoded mock data.
--   • duels        — one challenge. The challenger creates it and plays first;
--     the opponent loads the SAME question set (by stored question_ids) later
--     via the duel's short code (QR / manual entry) or a targeted challenge,
--     plays, and the winner is computed. No live realtime — purely async.
--
-- RLS NOTE (hackathon trade-off): identity here is a client-generated UUID, not
-- a Supabase auth user, so we cannot key rows to auth.uid(). The policies below
-- are intentionally permissive for the anon role. To harden later: migrate the
-- duel identity onto real auth (auth.users), add owner columns referencing
-- auth.uid(), and replace these policies with auth.uid()-scoped ones.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Players ──────────────────────────────────────────────────────────────────
create table if not exists public.duel_players (
  id           uuid primary key,
  display_name text not null,
  initials     text not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- "Online now" is a recency heuristic: rows touched recently are treated as
-- online by the client. Index the freshness column for that query.
create index if not exists duel_players_updated_at_idx
  on public.duel_players (updated_at desc);

-- ── Duels ────────────────────────────────────────────────────────────────────
create table if not exists public.duels (
  id                    uuid primary key default gen_random_uuid(),
  code                  text not null unique,
  topic                 text not null,
  -- Explicit, ordered question ids so both players answer an identical set
  -- (resolved client-side against the bundled question bank).
  question_ids          jsonb not null,

  challenger_id         uuid not null references public.duel_players(id) on delete cascade,
  challenger_name       text not null,
  -- Per-question correctness of the challenger's run, replayed as a "ghost"
  -- race for the opponent. e.g. [true, false, true, true, false]
  challenger_answers    jsonb,
  challenger_score      int,
  challenger_finished_at timestamptz,

  -- Null until someone accepts (open challenge) or pre-set for a targeted one.
  opponent_id           uuid references public.duel_players(id) on delete set null,
  opponent_name         text,
  opponent_score        int,
  opponent_finished_at  timestamptz,

  winner_id             uuid references public.duel_players(id) on delete set null,
  -- 'awaiting_opponent' once the challenger has played; 'completed' once both
  -- scores are in.
  status                text not null default 'awaiting_opponent',

  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create index if not exists duels_code_idx        on public.duels (code);
create index if not exists duels_challenger_idx   on public.duels (challenger_id);
create index if not exists duels_opponent_idx     on public.duels (opponent_id);
create index if not exists duels_status_idx       on public.duels (status);

-- ── Row Level Security (permissive — see RLS NOTE above) ──────────────────────
alter table public.duel_players enable row level security;
alter table public.duels        enable row level security;

create policy "duel_players_anon_read"
  on public.duel_players for select to anon, authenticated using (true);
create policy "duel_players_anon_write"
  on public.duel_players for insert to anon, authenticated with check (true);
create policy "duel_players_anon_update"
  on public.duel_players for update to anon, authenticated using (true) with check (true);

create policy "duels_anon_read"
  on public.duels for select to anon, authenticated using (true);
create policy "duels_anon_write"
  on public.duels for insert to anon, authenticated with check (true);
create policy "duels_anon_update"
  on public.duels for update to anon, authenticated using (true) with check (true);

-- ── Leaderboard view: wins / losses / played per player ───────────────────────
create or replace view public.duel_leaderboard as
select
  p.id,
  p.display_name,
  p.initials,
  count(d.*) filter (where d.status = 'completed'
        and (d.challenger_id = p.id or d.opponent_id = p.id))            as played,
  count(d.*) filter (where d.winner_id = p.id)                          as wins,
  count(d.*) filter (where d.status = 'completed'
        and d.winner_id is not null and d.winner_id <> p.id
        and (d.challenger_id = p.id or d.opponent_id = p.id))           as losses
from public.duel_players p
left join public.duels d
  on d.challenger_id = p.id or d.opponent_id = p.id
group by p.id, p.display_name, p.initials
order by wins desc, played desc;
