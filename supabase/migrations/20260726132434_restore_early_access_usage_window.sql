alter table public.entitlement_config
  drop constraint if exists entitlement_config_analysis_limit_range,
  drop constraint if exists entitlement_config_ai_action_limit_range;

alter table public.entitlement_config
  alter column daily_analysis_limit set default 18,
  alter column daily_ai_action_limit set default 54;

update public.entitlement_config
set
  daily_analysis_limit = least(greatest(daily_analysis_limit, 10), 20),
  daily_ai_action_limit = least(greatest(daily_ai_action_limit, 10), 120),
  updated_at = now()
where config_key = 'global';

alter table public.entitlement_config
  add constraint entitlement_config_analysis_limit_range
    check (daily_analysis_limit between 10 and 20),
  add constraint entitlement_config_ai_action_limit_range
    check (daily_ai_action_limit between 10 and 120);
