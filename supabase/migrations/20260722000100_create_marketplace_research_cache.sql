create table if not exists public.marketplace_research_cache (
  cache_key text primary key,
  marketplace text not null,
  category text not null,
  condition text not null,
  search_queries text[] not null default '{}',
  useful_findings text[] not null default '{}',
  official_sources text[] not null default '{}',
  research_summary text not null,
  model text not null,
  updated_at timestamptz not null default now(),
  expires_at timestamptz not null,
  constraint marketplace_research_cache_key_not_blank check (btrim(cache_key) <> ''),
  constraint marketplace_research_marketplace_not_blank check (btrim(marketplace) <> ''),
  constraint marketplace_research_category_not_blank check (btrim(category) <> ''),
  constraint marketplace_research_condition_not_blank check (btrim(condition) <> ''),
  constraint marketplace_research_summary_not_blank check (btrim(research_summary) <> ''),
  constraint marketplace_research_model_not_blank check (btrim(model) <> ''),
  constraint marketplace_research_expires_after_updated check (expires_at > updated_at)
);

create index if not exists marketplace_research_cache_marketplace_category_idx
on public.marketplace_research_cache (marketplace, category, expires_at desc);

alter table public.marketplace_research_cache enable row level security;
alter table public.marketplace_research_cache force row level security;

revoke all on table public.marketplace_research_cache from anon;
revoke all on table public.marketplace_research_cache from authenticated;
grant all on table public.marketplace_research_cache to service_role;
