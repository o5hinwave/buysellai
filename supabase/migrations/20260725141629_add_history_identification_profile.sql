alter table public.history
add column if not exists identification_profile jsonb;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'history_identification_profile_object'
      and conrelid = 'public.history'::regclass
  ) then
    alter table public.history
    add constraint history_identification_profile_object
    check (identification_profile is null or jsonb_typeof(identification_profile) = 'object');
  end if;
end $$;
