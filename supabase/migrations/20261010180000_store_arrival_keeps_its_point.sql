-- «هات اللوكيشن» في الشات (الموجة ٣ من «خطة سد فجوات زاد»، ٢٠٢٦-١٠-١٠).
--
-- الموجة ١ (1710f0ae) حطت زرار «📍 افتح على الخريطة» تحت رسالة المحل في تليجرام، بس نقطة المحل كانت
-- بتروح للبوت وبس: لما العميل كتب «هات اللوكيشن» بعدها، العقل ماكانش عنده حاجة وسأله «انت في أنهي منطقة؟».
-- مهمة store_arrival بقت شايلة رابط الخرايط بتاع المحل (storeMapUrl) وأداة store_location بتقراه.
--
-- النقطة دي مركز نطاق المحل على الموبايل — مكان عام، مش مكان العميل. العمود بيقبل رابط
-- storeMapUrl بشكله بالظبط (٥ أرقام عشرية) وبس.

alter table public.agent_tasks add column if not exists map_url text;

alter table public.agent_tasks drop constraint if exists agent_tasks_map_url_is_a_store_link;
alter table public.agent_tasks add constraint agent_tasks_map_url_is_a_store_link check (
  map_url is null
  or map_url ~ '^https://www\.google\.com/maps/search/\?api=1&query=-?[0-9]{1,2}\.[0-9]{5},-?[0-9]{1,3}\.[0-9]{5}$'
);

comment on column public.agent_tasks.map_url is
  'store_arrival بس: رابط خرايط المحل (zad-brain storeMapUrl) — نقطة المحل نفسه، مش مكان العميل. بيتقري بأداة store_location.';
