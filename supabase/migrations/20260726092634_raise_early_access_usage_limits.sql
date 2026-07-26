alter table public.entitlement_config
  drop constraint if exists entitlement_config_analysis_limit_range,
  drop constraint if exists entitlement_config_ai_action_limit_range;

alter table public.entitlement_config
  alter column daily_analysis_limit set default 100,
  alter column daily_ai_action_limit set default 300;

update public.entitlement_config
set
  daily_analysis_limit = 100,
  daily_ai_action_limit = 300,
  updated_at = now()
where config_key = 'global';

alter table public.entitlement_config
  add constraint entitlement_config_analysis_limit_range
    check (daily_analysis_limit between 10 and 250),
  add constraint entitlement_config_ai_action_limit_range
    check (daily_ai_action_limit between 10 and 500);
