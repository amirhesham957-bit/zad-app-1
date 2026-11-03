-- وضع السفر لما السوق يتغير (٣/١١، بعد 20261103180000): حساب المالك الجديد اتعلّم «مسافر مصر» من موقعه وسوقه
-- السعودية، وبعدها السوق اتحوّل لمصر — والتريجر كان بيصحى على النقطة بس، فـ`travel_country = country = EG` فضلت،
-- وترحيب «حمد الله على السلامة في مصر» اللي في الطابور كان لسه بيعدّي فحص `isStillRelevant` (بيقارن بلد الرحلة بس).
-- دلوقتي نفس التريجر بيصحى على تغيير السوق كمان: السوق الجديد = البلد اللي هو فيه ⇒ الرحلة بتخلص.

drop trigger if exists zad_users_travel_from_location on public.zad_users;
create trigger zad_users_travel_from_location
  before update of last_lat, last_lon, country on public.zad_users
  for each row
  execute function public.zad_users_travel_from_location();

-- الصفوف اللي رحلتها بقت بلد السوق نفسه، وترحيبها اللي لسه ماتبعتش.
update public.zad_voice_moments m
   set status = 'skipped'
  from public.zad_users u
 where m.user_id = u.id and m.moment = 'travel_arrived' and m.status = 'pending'
   and upper(coalesce(m.facts ->> 'country', '')) = upper(coalesce(u.country, ''));
update public.zad_users
   set travel_country = null, travel_since = null
 where travel_country is not null and travel_country = upper(btrim(coalesce(country, '')));
