alter table public.history
add column if not exists marketplace_comparison jsonb;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'history_marketplace_comparison_object'
      and conrelid = 'public.history'::regclass
  ) then
    alter table public.history
    add constraint history_marketplace_comparison_object
    check (marketplace_comparison is null or jsonb_typeof(marketplace_comparison) = 'object');
  end if;
end $$;
