create table if not exists public.history (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  item_name text not null,
  category text,
  condition text,
  suggested_price numeric,
  image_thumbnail_base64 text,
  marketplace text not null,
  listing_text text not null,
  constraint history_item_name_not_blank check (btrim(item_name) <> ''),
  constraint history_marketplace_not_blank check (btrim(marketplace) <> ''),
  constraint history_listing_text_not_blank check (btrim(listing_text) <> ''),
  constraint history_suggested_price_positive check (suggested_price is null or suggested_price > 0)
);

create index if not exists history_user_created_at_idx
on public.history (user_id, created_at desc);

alter table public.history enable row level security;
alter table public.history force row level security;

drop policy if exists "Users can manage their own history" on public.history;
create policy "Users can manage their own history"
on public.history
for all
to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

revoke all on table public.history from anon;
grant select, insert, update, delete on table public.history to authenticated;
grant all on table public.history to service_role;

create table if not exists public.apple_auth_tokens (
  user_id uuid primary key references auth.users(id) on delete cascade,
  apple_user_id text not null,
  refresh_token text not null,
  access_token text,
  access_token_expires_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint apple_auth_tokens_apple_user_id_not_blank check (btrim(apple_user_id) <> ''),
  constraint apple_auth_tokens_refresh_token_not_blank check (btrim(refresh_token) <> '')
);

alter table public.apple_auth_tokens enable row level security;
alter table public.apple_auth_tokens force row level security;

revoke all on table public.apple_auth_tokens from anon;
revoke all on table public.apple_auth_tokens from authenticated;
grant all on table public.apple_auth_tokens to service_role;
