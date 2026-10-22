-- Learn module: book-based lessons (read-only content) and per-user completion progress.
create table if not exists public.lessons (
  id text primary key,
  book_id text not null,
  title text not null check (length(title) between 3 and 200),
  dimensions text[] not null check (dimensions <@ array['emotional','physical','occupational','social','spiritual','intellectual','environmental','financial']::text[] and cardinality(dimensions) between 1 and 2),
  content jsonb not null,           -- {idea, cards[], tryThis, sensitive}
  reference jsonb not null,         -- {title, author, year, publisher, isbn}
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.lessons enable row level security;
create policy "lessons readable" on public.lessons for select to anon, authenticated using (is_active);
revoke insert, update, delete on public.lessons from anon, authenticated;

create table if not exists public.learn_progress (
  user_id uuid not null references auth.users (id) on delete cascade default auth.uid(),
  lesson_id text not null check (length(lesson_id) <= 80),
  completed_at timestamptz not null default now(),
  primary key (user_id, lesson_id)
);
alter table public.learn_progress enable row level security;
create policy "own progress read" on public.learn_progress for select to authenticated using (user_id = auth.uid());
create policy "own progress insert" on public.learn_progress for insert to authenticated with check (user_id = auth.uid());
create policy "own progress update" on public.learn_progress for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own progress delete" on public.learn_progress for delete to authenticated using (user_id = auth.uid());
