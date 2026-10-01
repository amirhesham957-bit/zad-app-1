-- The acceptance probe's account (zad-brain `acceptance_probe`, 2026-10-01).
--
-- The owner's acceptance lines run against the live brain after every deploy, on this
-- account and never on a customer's. It has no password and no identity provider, so
-- nobody can sign in as it; it has no phone token and no Telegram binding, so nothing it
-- does reaches a person; and it never signs in, so the daily greeting jobs skip it.
-- The auth.users triggers provision its zad_users and entitlement rows.
insert into auth.users (instance_id, id, aud, role, email, raw_app_meta_data, raw_user_meta_data, created_at, updated_at)
values (
  '00000000-0000-0000-0000-000000000000',
  'a11ce000-0000-4000-8000-00000000a11a',
  'authenticated', 'authenticated', 'acceptance-probe@zad.invalid',
  '{"provider":"acceptance_probe","providers":[]}'::jsonb, '{"country":"EG","currency":"EGP"}'::jsonb, now(), now()
)
on conflict (id) do nothing;

update public.zad_users
   set country = 'EG', currency = 'EGP'
 where id = 'a11ce000-0000-4000-8000-00000000a11a';

-- The probe must not be stopped by the free plan's monthly chat count.
update public.zad_entitlements
   set tier = 'pro', tier_expires_at = '2099-01-01T00:00:00Z'
 where user_id = 'a11ce000-0000-4000-8000-00000000a11a';

-- web_search answers cached before the relevance filter (keys without «v2»): the gold
-- question was cached as «حفل زفاف الأمير وليم». New keys never read them; drop them.
delete from public.ai_response_cache
 where action = 'web_search' and cache_key not like 'web_search:v2:%';
