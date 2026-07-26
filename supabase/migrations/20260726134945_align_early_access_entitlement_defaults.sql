update public.entitlement_config
set
  daily_analysis_limit = 18,
  daily_ai_action_limit = 54,
  updated_at = now()
where config_key = 'global';
