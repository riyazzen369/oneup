-- Curated external articles (Updates & Articles). Read-only for app users;
-- rows are inserted by editors with the service role after verifying each URL.
create table if not exists public.articles (
  id text primary key,
  dimension text not null check (dimension in ('emotional','physical','occupational','social','spiritual','intellectual','environmental','financial')),
  title text not null check (length(title) between 3 and 300),
  source text not null check (length(source) <= 120),
  date_display text,
  published_on date,
  url text not null unique check (url ~ '^https://'),
  summary text not null check (length(summary) <= 600),
  type text not null default 'news',
  is_active boolean not null default true,
  verified_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
alter table public.articles enable row level security;
create policy "articles readable" on public.articles for select to anon, authenticated using (is_active);
-- No insert/update/delete policies: clients cannot write.
revoke insert, update, delete on public.articles from anon, authenticated;
