-- «انت في أنهي بلد؟» بيتسأل مرة واحدة لحساب تليجرام من غير بلد (countryAsk.ts).
-- العمود ده هو «مرة واحدة»: بيتكتب لما السؤال يتبعت، والبوت مابيسألش تاني بعده
-- حتى لو العميل ماردّش — توقيت القاهرة الافتراضي فضل شغال.
alter table public.telegram_bindings
  add column if not exists country_asked_at timestamptz;
