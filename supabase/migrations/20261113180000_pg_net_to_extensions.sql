-- ٨.٥ step 2, part 2 (plan: docs/agent/PLAN_8_5_EXTENSIONS.md): move pg_net out of public.
-- The advisor flags extension_in_public; Supabase's own target is schema extensions.
--
-- Measured 13/11 on live: pg_net 0.20.3 is not relocatable (extrelocatable = false), so it is
-- dropped and created again. Its 28 objects all live in schema net, which the extension
-- recreates; nothing outside the extension depends on them (pg_depend). The six callers
-- (notify_telegram_on_transaction, zad_push_family_message, zad_family_zone_event,
-- zad_notify_admin, notify_telegram_on_low_stock, notify_telegram_on_insight) and the cron
-- jobs call net.http_post by its full name inside plpgsql/text, so they are not bound to the
-- old OIDs — and since 20261113160000 all six catch a failing call instead of rolling back
-- the write that fired them.
--
-- Lost on the way: net._http_response (old replies) and anything still queued in
-- net.http_request_queue at that instant. Both were 0/41 rows when measured.
--
-- Grants: Supabase's event trigger issue_pg_net_access (extensions.grant_pg_net_access)
-- grants USAGE on schema net to these same five roles on CREATE EXTENSION. Repeated here so
-- the result does not depend on that trigger existing.
--
-- Rollback: drop extension pg_net; create extension pg_net with schema public; + the grant below.

create schema if not exists extensions;

drop extension if exists pg_net;
create extension pg_net with schema extensions;

grant usage on schema net to postgres, anon, authenticated, service_role, supabase_functions_admin;
