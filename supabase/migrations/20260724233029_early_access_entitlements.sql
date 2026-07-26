create table if not exists public.entitlement_config (
  config_key text primary key default 'global',
  entitlement_state text not null default 'earlyAccess',
  complete_feature_access boolean not null default true,
  future_paid_access_enabled boolean not null default false,
  daily_analysis_limit integer not null default 18,
  daily_ai_action_limit integer not null default 54,
  cooldown_message text not null default 'You''ve analyzed a lot of items today. BuySell needs a little time before the next one. Your saved listings are still available.',
  updated_at timestamptz not null default now(),
  constraint entitlement_config_singleton check (config_key = 'global'),
  constraint entitlement_config_known_state check (entitlement_state in ('earlyAccess', 'free', 'plus', 'usagePack')),
  constraint entitlement_config_analysis_limit_range check (daily_analysis_limit between 10 and 20),
  constraint entitlement_config_ai_action_limit_range check (daily_ai_action_limit between 10 and 120),
  constraint entitlement_config_cooldown_message_not_blank check (btrim(cooldown_message) <> '')
);

insert into public.entitlement_config (
  config_key,
  entitlement_state,
  complete_feature_access,
  future_paid_access_enabled,
  daily_analysis_limit,
  daily_ai_action_limit
)
values (
  'global',
  'earlyAccess',
  true,
  false,
  18,
  54
)
on conflict (config_key) do nothing;

alter table public.entitlement_config enable row level security;
alter table public.entitlement_config force row level security;

revoke all on table public.entitlement_config from anon;
revoke all on table public.entitlement_config from authenticated;
grant all on table public.entitlement_config to service_role;

create table if not exists public.entitlement_usage_events (
  id uuid primary key default gen_random_uuid(),
  occurred_at timestamptz not null default now(),
  entitlement_state text not null,
  usage_action text not null,
  user_id uuid references auth.users(id) on delete set null,
  device_id text,
  ip_hash text,
  identity_key text not null,
  estimated_ai_cost_cents numeric(10, 4) not null default 0,
  grounded_search_count integer not null default 0,
  constraint entitlement_usage_known_state check (entitlement_state in ('earlyAccess', 'free', 'plus', 'usagePack')),
  constraint entitlement_usage_action_known check (usage_action in ('analysis', 'marketplace_research', 'listing_generation')),
  constraint entitlement_usage_identity_key_not_blank check (btrim(identity_key) <> ''),
  constraint entitlement_usage_device_id_not_blank check (device_id is null or btrim(device_id) <> ''),
  constraint entitlement_usage_ip_hash_not_blank check (ip_hash is null or btrim(ip_hash) <> ''),
  constraint entitlement_usage_estimated_cost_nonnegative check (estimated_ai_cost_cents >= 0),
  constraint entitlement_usage_grounded_search_nonnegative check (grounded_search_count >= 0)
);

create index if not exists entitlement_usage_identity_day_idx
on public.entitlement_usage_events (identity_key, occurred_at desc);

create index if not exists entitlement_usage_user_day_idx
on public.entitlement_usage_events (user_id, occurred_at desc)
where user_id is not null;

create index if not exists entitlement_usage_device_day_idx
on public.entitlement_usage_events (device_id, occurred_at desc)
where device_id is not null;

create index if not exists entitlement_usage_ip_day_idx
on public.entitlement_usage_events (ip_hash, occurred_at desc)
where ip_hash is not null;

alter table public.entitlement_usage_events enable row level security;
alter table public.entitlement_usage_events force row level security;

revoke all on table public.entitlement_usage_events from anon;
revoke all on table public.entitlement_usage_events from authenticated;
grant all on table public.entitlement_usage_events to service_role;
