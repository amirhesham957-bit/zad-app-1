-- 2ج (owner 13/11): never talked + no data ⇒ silent; one word or one row ⇒ not; 3 days of grace.
\set ON_ERROR_STOP on
insert into zad_users values
  ('00000000-0000-0000-0000-000000000001', now() - interval '10 days'),  -- silent, phone alive
  ('00000000-0000-0000-0000-000000000002', now() - interval '10 days'),  -- talked once
  ('00000000-0000-0000-0000-000000000003', now() - interval '10 days'),  -- one transaction
  ('00000000-0000-0000-0000-000000000004', now() - interval '1 day'),    -- new: grace
  ('00000000-0000-0000-0000-000000000005', now() - interval '10 days'),  -- household with someone
  ('00000000-0000-0000-0000-000000000006', now() - interval '10 days'),  -- in a family alone
  ('00000000-0000-0000-0000-000000000007', now() - interval '10 days'),  -- answered a check-in
  ('00000000-0000-0000-0000-000000000008', now() - interval '10 days'),  -- one pharmacy item
  ('00000000-0000-0000-0000-000000000009', now() - interval '10 days');  -- 5's partner, nothing else
insert into zad_fcm_tokens (user_id) select id from zad_users;           -- every phone refreshed its token
insert into zad_brain_runs values ('00000000-0000-0000-0000-000000000002', 'chat');
insert into zad_brain_runs values ('00000000-0000-0000-0000-000000000001', 'daily'); -- the daily run is not talk
insert into zad_transactions (user_id) values ('00000000-0000-0000-0000-000000000003');
insert into family_members values ('f0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000005'),
                                  ('f0000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000009'),
                                  ('f0000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000006');
insert into telegram_checkin_prompts values ('00000000-0000-0000-0000-000000000007', now());
insert into telegram_checkin_prompts values ('00000000-0000-0000-0000-000000000001', null); -- asked, never answered
insert into zad_pharmacy_items (user_id) values ('00000000-0000-0000-0000-000000000008');

do $$
declare
  expected jsonb := '{"1":true,"2":false,"3":false,"4":false,"5":false,"6":true,"7":false,"8":false,"9":false}';
  k text; got boolean;
begin
  for k in select jsonb_object_keys(expected) loop
    got := public.zad_account_silent(('00000000-0000-0000-0000-00000000000' || k)::uuid);
    if got is distinct from (expected ->> k)::boolean then
      raise exception 'account % silent=% expected %', k, got, expected ->> k;
    end if;
  end loop;
  -- the daily analysis: a refreshed token no longer makes a silent account active
  if exists (select 1 from public.zad_active_user_ids(7) a where a = '00000000-0000-0000-0000-000000000001') then
    raise exception 'silent account 1 is still in zad_active_user_ids';
  end if;
  if not exists (select 1 from public.zad_active_user_ids(7) a where a = '00000000-0000-0000-0000-000000000002') then
    raise exception 'account 2 (talked) dropped out of zad_active_user_ids';
  end if;
  -- the grace: a new account is active and not silent
  if not exists (select 1 from public.zad_active_user_ids(7) a where a = '00000000-0000-0000-0000-000000000004') then
    raise exception 'new account 4 dropped out of zad_active_user_ids';
  end if;
  -- only the server reads it
  if has_function_privilege('authenticated', 'public.zad_account_silent(uuid, integer)', 'execute')
     or has_function_privilege('anon', 'public.zad_account_silent(uuid, integer)', 'execute') then
    raise exception 'zad_account_silent is callable by the client';
  end if;
  raise notice 'silent_accounts_test: 13 checks passed';
end $$;
