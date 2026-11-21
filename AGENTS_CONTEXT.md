# AGENTS_CONTEXT — ابدأ من هنا

ملخص مضغوط لأي جلسة أو عامل جديد. **حدّثه في نفس الكومِت** لما حاجة هنا تتغير.
التفاصيل والتاريخ في `CLAUDE.md` و`docs/agent/ZAD_OR_PLAN.md` و`docs/agent/SESSION_LOG.md`. افتحهم لما تحتاج تفصيلة، مش في أول الجلسة.
آخر تحديث: ٢٠٢٦-١١-٢٢.

## المنتج والريبو

- زاد: مساعد مالي ومنزلي للعيلة، عربي (لهجة البيت)، على Google Play. Flutter بس (`zad_flutter/lib/`)، والسيرفر Supabase.
- **الدمج في `main` بينشر** المايجريشنز والـedge functions على الإنتاج (`.github/workflows/edge-functions.yml`). الـCI بيشغّل `deno check` و`deno test` وتستات SQL قبل النشر.
- الريبو اللي بيتشحن: `amirhesham957-bit/zad-app-1` (فرع من `main`، وPR، ودمج لما الـCI يخضر وبطلب المالك).

## المعمارية (٤ طبقات)

1. **الحواس:** موديل lite بيحوّل الكلام والفاتورة والإشعار لنية. مابيكتبش في أي جدول.
2. **نواة البيانات:** Postgres. `zad_events` دفتر مابيتمسحش. `zad_commit_intent(p_intent jsonb)` هو **الباب الوحيد للكتابة**.
3. **المحرك الحسابي** (م٣ وم٥، لسه): تنبؤ ومخزون وفلوس وتحسين (TS + SQL + HiGHS WASM).
4. **العقل المتكلم:** `supabase/functions/zad-brain/index.ts` (حوالي ١١٬٧٠٠ سطر)، بيحكي النتيجة. أي رقم في الرد لازم يكون ليه مصدر.

## الباب الوحيد (م٢.٥ خلص ٢٢/١١)

- النية: `{user_id, kind, client_event_id (≤١٠٠ حرف، مفتاح التكرار), source (manual|receipt|bank|model|cron), payload, member_id?, confidence?, occurred_at?}`.
- الباب بيتأكد من صاحب الطلب والشكل والتكرار. التكرار بيرجع `duplicate:true` من غير كتابة.
- بعد كده بيندَه `zad_intent_<المجال>(p_uid, p_kind, p_payload, p_occurred)` وبيكتب الحدث في نفس الترانزاكشن. أي رفض بيتسجل في `zad_guard_events`.
- المجالات: inventory، shopping، pharmacy، money، subscription، debt، obligation، maintenance، document، appointment، settings، goal. التوزيع بـ`if/elsif` (`case` بيقع لو دالة مجال لسه مش موجودة).
- دالة المجال بترجع `{ok:true,row_id,payload:{...,before,after}}` أو `{ok:false,reason:'snake_code'}`. الصف بيتدوّر عليه بـ`id` و`user_id = p_uid` مع `for update`.
- آخر المايجريشن: `revoke all … from public, anon, authenticated, service_role`.
- في TS: `commitIntent(sb, userId, scope, tool, input, kind, payload)` في `zad-brain/commitIntent.ts`. الرفض بيرجع `refusalText(reason)`، والكود لازم يتضاف لـ`REASONS` بالعربي، **ومن غير تكرار مفاتيح**. التكرار بيرجع `DUPLICATE_REPLY`.
- المصدر من `intentSource(scope)`: لفة شات = `model`، كرون = `cron`، زرار أو تأكيد = `manual`. أدوات الفلوس (`CONFIRM_REQUIRED_TOOLS`) بتتسجل `manual`.
- `recordAction(...)` لازم يفضل بنفس الجدول والـid والـprevious/next، عشان `zad_agent_undo` يعرف يرجّع.
- `oneDoor_test.ts` بيفشل لو أي ملف في `zad-brain` (أو `_shared/doseDoor.ts`) كتب مباشرة في جدول من الـ١٦ اللي ورا الباب.

## التستات (محلي، قبل أي كومِت)

```bash
cd supabase/functions && ~/.deno/bin/deno check zad-brain/index.ts zad-telegram-bot/index.ts && ~/.deno/bin/deno test -A zad-brain/ _shared/ _schema/
# SQL: حاوية Postgres اسمها zadpg. كل سطر في LIST بتاع edge-functions.yml = داتابيز جديدة والملفات بالترتيب، والأخير هو التست
db=t_x_$RANDOM; docker exec zadpg createdb -U postgres $db; for f in <chain>; do docker exec -i zadpg psql -U postgres -d $db -v ON_ERROR_STOP=1 -q < "$f"; done
# e2e (Postgres + PostgREST + كود العقل الحقيقي، مش الحي أبداً):
E2E_DB=t_e2e_x E2E_PORT=39xx E2E_REST=zad-e2e-rest-x bash supabase/sql/e2e/run_commit_intent_e2e.sh   # آخر سطر: e2e: all checks passed
```
- السقالة (`supabase/sql/tests/*_scaffold.sql`) بتعيد شكل الجداول **زي الحي**: اقرا `information_schema` و`pg_constraint` بـSELECT بس.
- Mutation check: التست الجديد لازم يوقع لو الميجريشن بتاعته اتشالت.
- Flutter: `flutter analyze` (لازم «No issues found!») و`flutter test`. ولو التغيير لمس أندرويد: `flutter build apk --release --split-per-abi --dart-define-from-file=env.json`. اقرا `EXIT=` الحقيقي، مش آخر سطر في `| tail`.

## قواعد مابتتكسرش

- شريحة واحدة = كومِت واحد = تحقق كامل. ماتقولش «خلص» من غير نتيجة تست اتشغّل **بعد** التغيير.
- الداتابيز الحية: SELECT بس للقياس. أي تغيير يبقى ميجريشن في الريبو والـCI ينشره. ممنوع `apply_migration` بإيدك، وممنوع `repair --status reverted`.
- RLS على أي جدول جديد. `family_id` اللي جاي من العميل مايتصدقش (`get_my_family_ids()`).
- النصوص العربي اللي **بتتطابق أو بتتخزن** (پارسر البنك، الفئات، الوحدات، البرومبتات) ماتتترجمش.
- الفلوس `Double` بـ`asMoney()`. مفيش DI framework.
- البرومبت: البيانات اللي جاية من العميل أو من الـOCR تفضل جوه بلوكات `=== SECTION ===`، والقواعد فوقها.
- Flutter: `ZadSpacing` و`ZadType` و`ZadColors`، وحالة فاضي حقيقية لكل لستة، والأهداف اللي بتتلمس ≥ ٤٤dp، و`showFieldDialog` للحقول. والـfeature مابيستوردش feature تانية (`feature_boundaries_test`).
- الوقت المدني = منطقة السوق بتاعة الحساب (`accountTimeZoneProvider`)، مش الجهاز.
- `supabase/config.toml` فيه `verify_jwt` لكل فانكشن، ماتشيلوش (بوت التليجرام هيقع).
- الموديلات: Gemini (٥ مفاتيح `ZAD_API_KEY_1..5`) وبعده Groq `openai/gpt-oss-120b`. الـsecret بيغلب الـdefault اللي في الكود. الرؤية مابتعديش على Groq أبداً.
- مفيش Mem0 ولا Graphiti ولا LangGraph (قرار م٩.٤). الذاكرة بتتبني جوه Postgres.

## فين إيه

| الحاجة | المكان |
|---|---|
| الخطة الأولى (أرقام المربعات م١…م٩، ج١، ج٢) | `docs/agent/ZAD_OR_PLAN.md`: «الحالة دلوقتي» وأول مربع فاضي |
| آخر جلسة وفخاخها | آخر قيد في `docs/agent/SESSION_LOG.md` |
| شغل الواجهة | `docs/agent/UI_OVERHAUL_STATUS.md` (حدّثه في نفس الكومِت) |
| Flutter: الاتفاقات والفجوات | `docs/agent/FLUTTER_MIGRATION.md` |
| قناة البنك (ماتشددش الفلترة من غير قياس) | `docs/agent/BANK_NOTIFICATION_CHANNEL.md` |
| توزيع الشغل على عمّال | `.claude/skills/orchestrate-workers/SKILL.md` |

## آخر الجلسة

علّم مربع الخطة في الكومِت اللي بيقفله، وضيف قيد في `SESSION_LOG.md` (اتعمل إيه، واتقاس إيه، والمالك قال إيه، وفاضل إيه، والفخاخ)، وحدّث الملف ده لو حاجة فيه اتغيرت.
