-- _agent_proactive_kind_label (ZAD_PLAN 10.5): every kind the scanner sends has a spoken name,
-- so a button's reply never says «pet_call». Add a new kind here when a migration starts sending it.
\set ON_ERROR_STOP on
do $$
declare k text; l text;
begin
  foreach k in array array['home_weekly_digest','spend_forecast','spending_ahead','med_followup','bill_reminder',
    'warranty_reminder','listener_gap_alert','goal_review','store_arrival','pet_call','memory_check','restock_link',
    'predicted_shortage','habit_budget','habit_trial','habit_trial_result'] loop
    l := public._agent_proactive_kind_label(k);
    if l = k or l ~ '[a-z_]' then raise exception 'kind % has no spoken label (got %)', k, l; end if;
  end loop;
  if public._agent_proactive_kind_label('pet_call') <> 'نداء زادو' then raise exception 'pet_call label'; end if;
end $$;
