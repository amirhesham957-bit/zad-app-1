-- Rejoin the pay days that split before 20261010150000 (2026-10-13).
--
-- 20261010150000 made a «ملفي» pay day move the budget cycle, but only for writes from
-- then on, and it fires only when `pay_day` changes. A customer who set the pay day there
-- before 2026-10-10 kept the old cycle, and saving the same day again does nothing. The
-- owner set 30 on 2026-10-06 and the home card still counted to the 16th that the brain
-- had confirmed on 2026-09-30.
--
-- Measured on live 2026-10-13: three accounts split, all three with the profile written by
-- the app after the cycle was last set, so the profile — what the customer typed — wins.
-- The `zad_users` trigger writes the same day back into the profile; the profile's trigger
-- then finds `pay_day` unchanged and stops there.

update public.zad_users u
   set cycle_start_day = p.pay_day
  from public.zad_customer_profile p
 where p.user_id = u.id
   and p.pay_day between 1 and 31
   and u.cycle_start_day is distinct from p.pay_day;
