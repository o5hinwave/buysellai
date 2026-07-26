alter table public.history
add column if not exists item_details jsonb,
add column if not exists listing_draft jsonb;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'history_item_details_object'
      and conrelid = 'public.history'::regclass
  ) then
    alter table public.history
    add constraint history_item_details_object
    check (item_details is null or jsonb_typeof(item_details) = 'object');
  end if;

  if not exists (
    select 1
    from pg_constraint
    where conname = 'history_listing_draft_object'
      and conrelid = 'public.history'::regclass
  ) then
    alter table public.history
    add constraint history_listing_draft_object
    check (listing_draft is null or jsonb_typeof(listing_draft) = 'object');
  end if;
end $$;
