alter table public.history
add column if not exists supplemental_photos jsonb;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'history_supplemental_photos_array'
      and conrelid = 'public.history'::regclass
  ) then
    alter table public.history
    add constraint history_supplemental_photos_array
    check (supplemental_photos is null or jsonb_typeof(supplemental_photos) = 'array');
  end if;
end $$;
