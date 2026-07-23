do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'apple_auth_tokens_apple_user_id_unique'
      and conrelid = 'public.apple_auth_tokens'::regclass
  ) then
    alter table public.apple_auth_tokens
    add constraint apple_auth_tokens_apple_user_id_unique
    unique (apple_user_id);
  end if;
end $$;
