---
title: خطة ٨.٥ — نقل pg_net وvector من public
date: 2026-11-13
tags:
  - zad/plan
  - zad/security
related:
  - "[[ZAD_PLAN]]"
---

# خطة ٨.٥ — نقل `pg_net` و`vector` من `public` لـ`extensions`

> [!info] الحالة
> خطة مكتوبة بس — **مااتنفذش منها حاجة**. كل الأرقام اتقاست على الحي ١٣/١١/٢٠٢٦.
> كل امتداد في PR لوحده، و`vector` الأول لأنه أسهل يترجع.

## ليه

مستشار Supabase بيعلّم `extension_in_public` على الاتنين. الامتداد في `public` معناه إن دواله وأنواعه
بتتشاف من الـAPI ومن أي `search_path` فيه `public`. الهدف بتاع Supabase نفسها: `create extension … with schema extensions`.

## اللي اتقاس (١٣/١١)

| | `pg_net` 0.20.3 | `vector` 0.8.2 |
|---|---|---|
| ينفع `ALTER EXTENSION … SET SCHEMA`؟ | لأ (`extrelocatable = false`) | أيوه |
| حاجاته في `public` | **ولا حاجة** — الـ٢٨ حاجة كلهم في schema `net` | النوع `vector` و~٤٥ دالة وعامل (`<=>`…) |
| مين بيستعمله | ٢٦ كرون + ٦ دوال بتنادي `net.http_post` بالاسم الكامل | عمود `zad_memory.embedding` + فهرس `idx_zad_memory_embedding` (ivfflat) + ٣ دوال |
| الطابور وقت القياس | `http_request_queue` = ٠، `_http_response` = ٤١ صف (ردود قديمة) | — |

دوال `vector`:
- `zad_memory_semantic_search(p_user, p_query_embedding vector, p_limit)` — بيستعمل `<=>`، و`search_path=public` ⇐ **هيقع** بعد النقل.
- `zad_memory_set_embedding(p_user, p_note, p_vec vector)` — `search_path=public`، مفيش عوامل؛ الباراميتر مربوط بالـOID فمش هيقع، بس يتصلّح للاتساق.
- `zad_memory_review_candidates` — `search_path` فيه `extensions` أصلاً، سليم.

دوال `pg_net` (كلها `search_path=public`، وبتنادي `net.http_post` بالاسم الكامل فمش بتتأثر بالمسار):
`notify_telegram_on_transaction`، `zad_push_family_message`، `zad_family_zone_event` جواهم `EXCEPTION`؛
**`zad_notify_admin` و`notify_telegram_on_low_stock` و`notify_telegram_on_insight` مافيهمش** ⇐ لو اتنادوا في نفس لحظة
النقل، الكتابة اللي ندهتهم (تريجر) هتقع.

صلاحيات `net` دلوقتي: `USAGE` لـ`anon` و`authenticated` و`service_role` و`postgres` و`supabase_functions_admin`،
و`net.http_post/get/delete` من غير ACL = `EXECUTE` لـ`PUBLIC`. ده الوضع الافتراضي بتاع Supabase — مش
ثغرة لوحده لأن `net` مش متعرّض في الـAPI، بس نكتبه زي ما هو ونرجّعه زي ما هو بعد إعادة الإنشاء.

## الخطوة ١ — `vector` (مايجريشن لوحده)

```sql
alter extension vector set schema extensions;
alter function public.zad_memory_semantic_search(uuid, extensions.vector, integer)
  set search_path = public, extensions, pg_temp;
alter function public.zad_memory_set_embedding(uuid, text, extensions.vector)
  set search_path = public, extensions, pg_temp;
```

- العمود والفهرس مربوطين بالـOID، فبيمشوا مع النوع من غير إعادة بناء.
- **قبل:** دوّر في `supabase/migrations/` على أي `create function` جديد بيستعمل `vector` من غير `extensions` في المسار.
- **التست:** `memory_heals_test.sql` و`memory_time_entities_test.sql` على postgres فيه pgvector في docker (زي ما اتعملوا قبل كده)،
  مرة قبل المايجريشن ومرة بعده، وتست جديد: `zad_memory_semantic_search` بيرجّع نتيجة بعد النقل. (CI مافيهوش pgvector.)
- **بعد النشر:** `select extnamespace::regnamespace from pg_extension where extname='vector'` = `extensions`، ولوج
  `[dream] memory healed` الليلة دي، ونداء بحث ذاكرة حقيقي من الشات بيرجّع.
- **الرجوع:** `alter extension vector set schema public;` (نفس الأمر بالعكس).

## الخطوة ٢ — `pg_net` (مايجريشن لوحده، بعد ما الخطوة ١ تعدّي ليلة)

١. **أول PR:** نحط `EXCEPTION WHEN others THEN` حوالين نداء `net.http_post` في الدوال التلاتة اللي مالهاش
   (`zad_notify_admin`، `notify_telegram_on_low_stock`، `notify_telegram_on_insight`) — تنبيه ضايع أهون من معاملة
   أو صنف ماتسجّلش. ده يتعمل بغض النظر عن النقل.
   **اتعمل ١٣/١١:** `20261113160000_net_calls_never_block_writes.sql` — قراية السر والنداء جوه البلوك، و`raise warning`.
   التست `net_calls_never_block_writes_test.sql` (في CI) بـ`net.http_post` بيرمي دايماً: الكتابة بتنزل والنداء اتجرّب؛
   اتجرّب بالكسر (من غير EXCEPTION وقع عند تريجر المخزن).

٢. **المايجريشن:**

```sql
drop extension pg_net;
create extension pg_net with schema extensions;
-- نفس صلاحيات النهارده بالظبط (اتقاست ١٣/١١):
grant usage on schema net to postgres, anon, authenticated, service_role, supabase_functions_admin;
```

- `drop`/`create` في نفس الترانزاكشن. اللي بيضيع: `_http_response` (ردود قديمة) وأي طلب في الطابور لحظتها.
- **التوقيت:** بعد تكّة `agent-tasks-processor` (كل ٥ دقايق) بدقيقة، وبعيد عن ٠٢:٠٠–٠٤:٠٠ UTC (التقييم الليلي) وعن ساعة
  تحية الصبح. CI بيطبّق المايجريشن مع الدمج — فالدمج نفسه هو التوقيت.
- **الصلاحية:** `drop extension pg_net` محتاج صاحب الامتداد. لو رن CI رجّع `must be owner of extension pg_net`،
  مانعملش حاجة بإيدينا من الداشبورد (ده بيكسر تاريخ المايجريشن — شوف CLAUDE.md): يترجع الـPR، ونطلب من دعم Supabase
  ينفذ نفس الـSQL، أو نسيب `pg_net` مكانه ونقفل البند على `vector` بس.
- **بعد النشر:** `extnamespace` = `extensions`؛ أول تكّة لـ`agent-tasks-processor` ترجع 200
  (`select status_code from net._http_response order by id desc limit 5`)؛ و`cron.job_run_details` من غير `failed`
  لمدة ساعة؛ ورسالة تليجرام على معاملة حقيقية.
- **الرجوع:** نفس الاتنين بالعكس (`drop extension pg_net; create extension pg_net with schema public;` + الصلاحيات).

## اللي برّه الخطة دي

حماية الباسوردات المسربة (Pro، ٨.١)، وتدوير الأسرار، وSentry — فاضلين في ٨.٥ زي ما هم.
