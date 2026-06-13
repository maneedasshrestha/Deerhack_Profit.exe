-- ════════════════════════════════════════════════════════════════════════════
-- Duel avatars — store a shareable (network) avatar URL alongside each player so
-- the "Online now" list and the "Challenges for you" inbox can show real faces
-- instead of initials. Local file paths are never stored here (they're
-- meaningless on another device); the client only writes http(s) URLs — the
-- signed-in Google avatar, or an uploaded photo that's already a remote URL.
--
-- Additive and idempotent: safe to run on top of 0001_duel.sql.
-- ════════════════════════════════════════════════════════════════════════════

-- ── Player avatar ─────────────────────────────────────────────────────────────
alter table public.duel_players
  add column if not exists photo_url text;

-- ── Per-duel avatars (denormalised so the inbox needs no extra join) ──────────
alter table public.duels
  add column if not exists challenger_photo_url text;
alter table public.duels
  add column if not exists opponent_photo_url text;

-- ── Surface the avatar on the leaderboard view too ────────────────────────────
-- NOTE: `create or replace view` can only APPEND columns (Postgres won't let
-- you reorder/rename existing ones), so photo_url goes last — after losses.
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
        and (d.challenger_id = p.id or d.opponent_id = p.id))           as losses,
  p.photo_url
from public.duel_players p
left join public.duels d
  on d.challenger_id = p.id or d.opponent_id = p.id
group by p.id, p.display_name, p.initials, p.photo_url
order by wins desc, played desc;
