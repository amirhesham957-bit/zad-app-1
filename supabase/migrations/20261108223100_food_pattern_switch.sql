-- ZAD_PLAN ٥.١٠ (٦): صورة أكل البيت من المشتريات، باختيار صريح ومقفولة افتراضياً، والمفتاح في الإعدادات.
-- وصف مشتريات بس: من غير تشخيص ومن غير أي استنتاج عن فرد في البيت.
alter table public.zad_users add column if not exists food_pattern_enabled boolean not null default false;
