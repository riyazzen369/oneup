-- Score bands aligned with the companion spec: 0–40 Needs Attention, 41–70 Developing, 71–100 Thriving.
create or replace function public.oneup_band(p_score int)
returns text language sql immutable as $$
  select case when p_score <= 40 then 'needs_attention'
              when p_score <= 70 then 'developing'
              else 'thriving' end
$$;

-- Re-derive stored bands with the new cut-offs, and keep them consistent going forward.
update public.dimension_scores set band = public.oneup_band(score);
alter table public.dimension_scores drop constraint if exists dimension_scores_band_matches_score;
alter table public.dimension_scores add constraint dimension_scores_band_matches_score
  check (band = public.oneup_band(score));

-- Companion sessions flagged for human review (only when the user consented).
-- Stores no message text: just a timestamp, risk level and the user id.
create table if not exists public.companion_flags (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  risk_level text not null check (risk_level in ('elevated','crisis')),
  created_at timestamptz not null default now()
);
alter table public.companion_flags enable row level security;
create policy "own flags insert" on public.companion_flags for insert to authenticated with check (user_id = auth.uid());
create policy "own flags read" on public.companion_flags for select to authenticated using (user_id = auth.uid());
