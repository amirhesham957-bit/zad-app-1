# AGENTS_CONTEXT — ابدأ من هنا

ملخص مضغوط لأي جلسة أو عامل جديد. **حدّثه في نفس الكومِت** لما حاجة هنا تتغير.
التفاصيل والتاريخ في `docs/agent/CLAUDE_HISTORY.md` (بالـgrep) و`docs/agent/ZAD_OR_PLAN.md` و`docs/agent/SESSION_LOG.md`. افتحهم لما تحتاج تفصيلة، مش في أول الجلسة.
آخر تحديث: ٢٠٢٦-١١-٢٨ (مصفوفة الرؤية P2.5).

## المنتج والريبو

- زاد: مساعد مالي ومنزلي للعيلة، عربي (لهجة البيت)، على Google Play. Flutter بس (`zad_flutter/lib/`)، والسيرفر Supabase.
- **الدمج في `main` بينشر** المايجريشنز والـedge functions على الإنتاج (`.github/workflows/edge-functions.yml`). الـCI بيشغّل `deno check` و`deno test` وتستات SQL قبل النشر.
- الريبو اللي بيتشحن: `amirhesham957-bit/zad-app-1` (فرع من `main`، وPR، ودمج لما الـCI يخضر وبطلب المالك).

## المعمارية (٤ طبقات)

1. **الحواس:** موديل lite بيحوّل الكلام والفاتورة والإشعار لنية. مابيكتبش في أي جدول.
2. **نواة البيانات:** Postgres. `zad_events` دفتر مابيتمسحش. `zad_commit_intent(p_intent jsonb)` هو **الباب الوحيد للكتابة**.
3. **المحرك الحسابي** (م٣ وم٥، شغال جزئياً): دوال صافية في `supabase/functions/_shared/or/` (TSB، سؤال الأسبوع، ميزانية الانتباه، Hungarian، knapsack…). اتربط: تنبؤ المخزن في اللقطة (م٣.١)، والسؤال الأسبوعي في البوت (م٣.٣)، وميزانية الرسايل في المُرسِل (م٥.١).
   - كاشف التعارض (م٥): أداة قراءة `check_constraint_conflicts` (`zad-brain/constraintConflicts.ts`) بتقارن مبلغ وتاريخ بالمتاح والأقساط والالتزامات والاشتراكات والأدوية والمواعيد، وكل تعارض بمصدره. مابتكتبش، وعليها حارس الأرقام.
   - م٥.٢: `_shared/or/memberBusy.ts` (مواعيد الفرد -> مشغول للّمّة)، دالة صافية مش موصّلة لسه.
   - م٧.٨: `_shared/or/memberGoal.ts` (حالة هدف الفرد وتعديله لو وقف)، دوال صافية مش موصّلة لسه.
   - P1.3: دوال عرض `zad_view_home/money/house/family(member_id)` (ميجريشن `20261127140000`): jsonb، كل رقم `{value, source}` + `available_actions`، قراية بس، authenticated بس. money بتمرّر `zad_budget_state` كما هي. `zad_view_family`: ولي الأمر (صاحب `zad_household_members`) بيشوف أي فرد؛ الطفل لغيره لأ أبداً؛ بالغ بحساب (self/linked_user_id) بس بموافقة `zad_family_shares` وبنطاقاتها بس.
   - P2.5 (مصفوفة الرؤية، ميجريشن `20261128190000`): القاصر (`zad_is_minor_user`) مهامه وأهدافه بس؛ RLS restrictive تقفل الميزانية والصيدلية عليه (`zad_i_am_minor()`)، وولي الأمر (`zad_i_guard`) بيشوف مهام وأهداف القاصر، والبالغ للبالغ بموافقة `zad_family_shares` إلا الصيدلية (`zad_pharmacy_items.is_private`، مفتوحة للبالغين افتراضياً، تتقفل من الباب). `zad_view_family_home()` بيت العيلة. نسخة TS: `_shared/or/visibilityMatrix.ts`. فجوة: صف `zad_users` للطفل (أرقام ميزانية) لسه مقروء له؛ P2.5b مرحلة ١ عملت `zad_user_budget` (RLS، القاصر أعمى، تريجر بيعكس `zad_users`) والقراية لسه على `zad_users` لحد المرحلة ٢ (التفاصيل في صف P2.5b).
   - P2.5 (مصفوفة الرؤية، ميجريشن `20261128190000`): القاصر (`zad_is_minor_user`) مهامه وأهدافه بس؛ RLS restrictive تقفل الميزانية والصيدلية عليه (`zad_i_am_minor()`)، وولي الأمر (`zad_i_guard`) بيشوف مهام وأهداف القاصر، والبالغ للبالغ بموافقة `zad_family_shares` إلا الصيدلية (`zad_pharmacy_items.is_private`، مفتوحة للبالغين افتراضياً، تتقفل من الباب). `zad_view_family_home()` بيت العيلة. نسخة TS: `_shared/or/visibilityMatrix.ts`. فجوة: صف `zad_users` للطفل (أرقام ميزانية) لسه مقروء له.
   - P3.1: فلتر الهزار `_shared/or/jokeFilter.ts` شغال دايماً (قاعدة 4ب في برومبت الشات، وأدوات الكتابة `JOKE_BLOCKED_TOOLS` بتترفض في لفة الهزار، والمسار السريع بيتخطى). حقائق الفرد المستنتجة: `_shared/or/factInference.ts` (من `zad_events` ومن الشات) + `zad-brain/factCheckIn.ts` (ليلي، سؤال يومي لحظة `fact_checkin`، «آه» ⇒ `profile.fact_set` said، «لأ» ⇒ `profile.fact_deny` وماتتسألش ولا تتستنتج ١٨٠ يوم، ميجريشن `20261128210000`) خلف `ZAD_FACT_INFERENCE` (مقفول). P3.5: `zad_forecasts.low/high/in_range` + `zad_forecast_range_coverage` (ميجريشن `20261128220000`).
   - P3.12 (محفظة الكاش، ميجريشن `20261128210000`/`210100`): رصيد الكاش = `zad_cash_balance` (من الدفتر، مفيش جدول). نوعين من الباب: `money.cash_withdrawn` (تحويل لكاش، توأم نفس المبلغ ±٦ ساعات = `cash_withdrawal_duplicate_suspected`) و`money.cash_spent`/`money.purchase` بمحفظة cash (توأم إشعار بنك `private.zad_bank_twin` = `cash_spend_matches_bank_notice`)؛ الرفض سؤال واحد والرد `allow_duplicate`/`confirm_cash`. `zad_view_money.numbers.cash_on_hand` بمصدره. الأدوات (P3.12b): `log_cash_withdrawal`/`log_cash_spend` في `chatTools.ts` (تأكيد بزرار، والبوت بيستعمل نفس القايمة عبر zad-brain)؛ الرفضين = سؤال واحد، و`allow_duplicate`/`confirm_cash` مرفوضين في نفس اللفة اللي اترفضت فيها (`validateCashTool`)؛ «معايا كام كاش» من `cash_reconciliation.cash_on_hand` + `cash_on_hand_source` (قاعدة برومبت).
   - الـbandit (م٨): `zad-brain/banditWiring.ts` + `zad_bandit_state`، متوصّل في `proactiveTitle` خلف `ZAD_BANDIT_TONE` (مقفول)، من `APPROVED_VARIANTS` (فاضية). الحارة الحرجة (دوا/صحة، أمان/طوارئ، طقس قاسي بس) والطفل وأقل من ١٨ برا. تغذية المكافأة (`zad-brain/banditReward.ts` + `zad_bandit_shown`): إشعار اتقرا (`app_notifications.is_read`) = نجاح للقالب المعروض، بدالتين security definer، لفرد واحد معروف بس؛ الفشل: إشعار معروض من +٢٤ ساعة وغير مقروء = `failures+1` عبر `zad_bandit_settle_failure` (ميجريشن `20261127120000`، عمود `outcome`)، والصف بيتقفل فقراية متأخرة مابتكافئش.
   - م٤.٣: `ZAD_ONDEMAND_PROMPT=1` (مقفول افتراضياً) = أدوات كاملة بالنية بس، وقواعد النوايا بالنية، وأدوات التعديل/المسح لكل تخصص بفعل التعديل (`ONDEMAND_DEFERRED_TOOLS` في `specialists.ts`). p50 ٧٦٩٣ ← ٦٩٠٦، p90 ٩٦٧٨ ← ٨٠١٨ توكن؛ لسه بعيد عن ٣٠٠٠ ودقة الموديل مش مقاسة. ونفس الفلاج بيقصّ اللقطة بالنية (`promptSnapshot(snap, scope)`، `SNAPSHOT_KEY_SCOPE`، سقف الذاكرة ٨ للتخصص و١٢ للعام): p50 اللقطة ١٢٥١ ← ٦١٢ توكن على لقطة الاختبار. م٤.٣ب: نفس الفلاج بيشيل من برومبت القواعد بلوكات بالنية (قرارات كبيرة، شهر صعب، ظرف البيت، مناسبات، لوكيشن، تذكرة دعم، قنوات، أهداف، تفاصيل العيلة) عبر `INTENT_RULE_TOOLS` و`ruleIntentKeys` (`specialists.ts`)؛ القواعد على لقطة الاختبار ~٣٠٠٠ ← ~٢٦٦٠ توكن، وقواعد السلامة والتنفيذ والفلوس والدوا ثابتة. ملحوظة: تحت ٣٠٠٠ كلها مش ممكن بالقواعد لوحدها. م٤.٣ج: نفس الفلاج بيبعت أول لفة بأدوات النية + `log_transaction` و`read_house` + `load_tools` (`lazyTools.ts`) والباقي بالطلب: p50 ٦٥٠٦ ← ٤٢٦٧ توكن (مش وصل ٣٠٠٠، الباقي قواعد ~٢٤٠٠ وSOUL ~٩٠٠)؛ دقة طلب الأدوات مش مقاسة.
   - م٥.٢: `plan_gathering_time` بتقرا `zad_appointments` بتاعة العميل (مش حسابات تانية) وتدمجها مع كلامه. م٧.٨: `memberGoalWiring.ts` بيحط حالة الهدف الأسبوعية واقتراح التمديد في `life_goals` خلف `ZAD_MEMBER_GOALS` (مقفول)، قراية واقتراح بس. وأهداف العدّ من `agent_tasks`، وأداة `apply_goal_adjustment` (`memberGoalApply.ts`، خلف نفس الفلاج) بتمدّ ميعاد هدف واقف عبر `goal.set` من الباب، بشرط `goal_id` إلزامي + موافقة صريحة في رسالة اللفة + **عرض سيرفر** مفتوح (`zad_goal_offers`، ٢٤ ساعة، مرة واحدة، اتسجل في لفة قبل الموافقة، والطفل برا)، و«أيوه» لوحدها مابتنفّذش؛ أمثلة الأفراد دوال صافية في `_shared/or/memberGoalExamples.ts` مش موصّلة.
   - v2-3: `zad-brain/familyPersona.ts` بيرسونا العيلة خلف `ZAD_FAMILY_PERSONA` (مقفول، صفر توكن): بلوك برومبت + شيل أرقام باقي الأفراد من لقطة الشات (خصوصية م٧.٩).
   - v2-2: `zad-brain/nativeAlarm.ts` أداة `set_native_alarm` (FCM data-only `action:SET_NATIVE_ALARM` لأجهزة العميل) خلف `ZAD_NATIVE_ALARM` (مقفول لحد ما مستقبِل SET_ALARM Intent في Flutter يتشحن). مقفول = الأداة مش في القايمة والمنفّذ بيرفض؛ فشل/مفيش جهاز = `fallback_to_inapp_reminder`. بتقرا `zad_fcm_tokens` بس.
   - v2: `zad-brain/weatherDrift.ts` تنبيه الجو الاستباقي خلف `ZAD_WEATHER_ALERTS` (مقفول: صفر شبكة)، من أول `processDueAgentTasks`: لوكيشن `zad_users` الحديث + Open-Meteo بالساعة للـ٣ ساعات الجاية (مطر > ٤٠٪، حر/برد شديد) ⇒ لحظة `weather_alert` في `zad_voice_moments` (المعالج بيحترم الهدوء والسقف)، ومنع تكرار ٦ ساعات للنوع. مفيش جدول جديد.
4. **العقل المتكلم:** `supabase/functions/zad-brain/index.ts` (حوالي ١٠٬٠٠٠ سطر، والأدوات بقت في `toolDefs.ts` و`chatTools.ts`)، بيحكي النتيجة. أي رقم في الرد لازم يكون ليه مصدر.

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
- `member_id` إلزامي على المخزن والتفضيلات والأهداف (م٢.٦): trigger بيملاه بصف «أنا» لو مااتبعتش، و`payload.member_id` لازم يكون لنفس المستخدم وإلا `member_not_found` (بيتفحص عند إضافة صف جديد بس).
- Flutter بيكتب من غلاف الموبايل `zad_commit_my_intent(p_kind, p_client_event_id, p_payload, p_occurred_at, p_trace_id)` (المستخدم من الـJWT، المصدر manual): مساعد `core/data/commit_my_intent.dart`. الأنواع المسموحة: المخزن، وP1.6b: `money.logged/updated/deleted/limit_set/category_budget_set` و`settings.emergency_fund_set`، و`debt.added/updated/deleted` و`obligation.added/updated/deleted` و`subscription.added/updated/deleted` (الإضافة بـ`item_id` = id الصف من الـOutbox وتكراره مابيعملش صف تاني). نوع جديد لزرار = يتضاف في قايمة الغلاف بميجريشن (انسخ تعريف الغلاف من **آخر** ميجريشن بيعرّفه، حالياً `20261129010000`) + تست `money_buttons_test.sql` أو `debts_buttons_test.sql`.
- `oneDoor_test.ts` بيفشل لو أي ملف في `zad-brain` (أو `_shared/doseDoor.ts`) كتب مباشرة في جدول من الـ١٦ اللي ورا الباب.

## التستات (محلي، قبل أي كومِت)

```bash
cd supabase/functions && ~/.deno/bin/deno check zad-brain/index.ts zad-telegram-bot/index.ts && ~/.deno/bin/deno test -A zad-brain/ _shared/ _schema/
# SQL: حاوية Postgres اسمها zadpg. كل سطر في LIST بتاع edge-functions.yml = داتابيز جديدة والملفات بالترتيب، والأخير هو التست
db=t_x_$RANDOM; docker exec zadpg createdb -U postgres $db; for f in <chain>; do docker exec -i zadpg psql -U postgres -d $db -v ON_ERROR_STOP=1 -q < "$f"; done
# e2e (Postgres + PostgREST + كود العقل الحقيقي، مش الحي أبداً):
E2E_DB=t_e2e_x E2E_PORT=39xx E2E_REST=zad-e2e-rest-x bash supabase/sql/e2e/run_commit_intent_e2e.sh   # آخر سطر: e2e: all checks passed (بيشغّل كمان ساندوتش الزرار P1.6a: button_manifest.json + button_e2e.ts؛ حارسه في _schema/button_manifest_test.ts؛ job button-e2e في الـCI)
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
| **الخطة الشغالة** (شرايح P0…P4، القرارات، المرفوض، الحقائق المقاسة، فريق التنفيذ) | `docs/agent/ZAD_FAMILY_PLAN.md`: قسم «دلوقتي» بس |
| الخطة القديمة (م١…م٩، اتقفلت ٢٧/١١) | `docs/agent/ZAD_OR_PLAN.md` (مرجع) |
| آخر جلسة وفخاخها | آخر قيد في `docs/agent/SESSION_LOG.md` |
| شغل الواجهة | `docs/agent/UI_OVERHAUL_STATUS.md` (حدّثه في نفس الكومِت) |
| Flutter: الاتفاقات والفجوات | `docs/agent/FLUTTER_MIGRATION.md` |
| قناة البنك (ماتشددش الفلترة من غير قياس) | `docs/agent/BANK_NOTIFICATION_CHANNEL.md` |
| توزيع الشغل على عمّال | `.claude/skills/orchestrate-workers/SKILL.md` (المراجعة والدمج) و`.claude/skills/external-workers/SKILL.md` (NVIDIA وGemini وGroq عبر opencode) |
| مواصفات شرايح م٣ الجاهزة للعمّال | `.claude/tasks/<slice>/TASK_WORKER.md` (مش متتبعة في git) |
| الترندز / تيك توك / العروض مابتوصلش | `docs/agent/SEARCH_HEALTH_RUNBOOK.md` |

## آخر الجلسة

علّم مربع الخطة في الكومِت اللي بيقفله، وضيف قيد في `SESSION_LOG.md` (اتعمل إيه، واتقاس إيه، والمالك قال إيه، وفاضل إيه، والفخاخ)، وحدّث الملف ده لو حاجة فيه اتغيرت.
