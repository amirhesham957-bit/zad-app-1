-- One pay day, from whichever side it is set (2026-10-10).
--
-- 20261001190000 made the budget cycle the pay day, but only one way: a change of
-- `zad_users.cycle_start_day` copies itself into `zad_customer_profile.pay_day`. «ملفي»
-- writes `pay_day` straight into the profile (Flutter `memory_remote.dart`), so a customer
-- who corrected their pay day there split the two again — the home card counting to one
-- day, the brain talking from another (the owner's 16 vs 30, measured 2026-10-01).
--
-- Now the profile's pay day moves the cycle too. The two triggers cannot loop: each writes
-- only when the other side differs, so the echo of a change finds nothing to do.

create or replace function public.zad_sync_cycle_from_pay_day()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
begin
  if new.pay_day is not null
     and new.pay_day between 1 and 31
     and (tg_op = 'INSERT' or new.pay_day is distinct from old.pay_day) then
    update public.zad_users
       set cycle_start_day = new.pay_day
     where id = new.user_id
       and cycle_start_day is distinct from new.pay_day;
  end if;
  return new;
end;
$function$;

revoke all on function public.zad_sync_cycle_from_pay_day() from public, anon, authenticated;

drop trigger if exists zad_customer_profile_sync_cycle on public.zad_customer_profile;
create trigger zad_customer_profile_sync_cycle
  after insert or update of pay_day on public.zad_customer_profile
  for each row execute function public.zad_sync_cycle_from_pay_day();
