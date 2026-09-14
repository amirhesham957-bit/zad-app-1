-- تنبيهات مالية حرجة على تليجرام بتوصل بفويس بصوت زاد مع النص (٢٠٢٦-٠٩-١٤).
--
-- realtime_push في zad-telegram-bot بقى بيقبل `voice: true`: النص بيتبعت زي ما هو على طول،
-- وبعده فويس نوت (Gemini TTS بصوت Aoede = سارة، نفس صوت قراءة الإشعارات والمكالمة).
-- اللي بيبعت هو اللي بيقرر إن التنبيه حرج — البوت مابيخمّنش من النص.
--
-- هنا الاتنين اللي بيتبعتوا من تريجرات:
-- - notify_telegram_on_transaction: عتبة ٩٠٪ و١٠٠٪ من الميزانية بس. ٧٥٪ تنبيه مبكر مش
--   حرج، والمعاملات العادية أكيد لأ — فويس على كل مصروف = ضوضاء العميل هيكتمها.
-- - notify_telegram_on_insight: priority = 'critical' بس (مش أسئلة زاد).
--
-- المبادرتين الحرجتين من zad-brain (listener_gap_alert، spending_ahead) بتبعت voice من
-- الكود (shared.ts: VOICE_ALERT_KINDS). تنبيهات الأدمن (صحة العقل/الماسح) من غير فويس.
--
-- التعريفين منقولين **بالحرف** من pg_get_functiondef على الإنتاج نفس اليوم؛ الفرق الوحيد
-- حقل 'voice' في jsonb_build_object. التكرار (مرة كل عتبة/شهر) زي ما هو، فمفيش سقف جديد.

CREATE OR REPLACE FUNCTION public.notify_telegram_on_transaction()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    is_linked BOOLEAN;
    v_limit DOUBLE PRECISION;
    current_month TEXT;
    month_spent DOUBLE PRECISION;
    spent_pct INT;
    threshold_to_fire INT;
    push_title TEXT;
    push_body TEXT;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM telegram_bindings WHERE user_id = NEW.user_id AND bound_at IS NOT NULL
    ) INTO is_linked;
    IF NOT is_linked THEN
        RETURN NEW;
    END IF;

    IF NEW.amount != 0 THEN
        push_title := 'زاد | معاملة جديدة';
        push_body := (CASE WHEN NEW.is_expense THEN 'مصروف: ' ELSE 'دخل: ' END)
            || NEW.title || ' — ' || NEW.amount::TEXT;
        PERFORM net.http_post(
            url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push',
            headers:=jsonb_build_object('Content-Type', 'application/json', 'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')),
            body:=jsonb_build_object('user_id', NEW.user_id, 'title', push_title, 'body', push_body),
            timeout_milliseconds:=15000
        );
    END IF;

    -- Fix 1: txn_kind='expense', not is_expense — a transfer/ATM withdrawal is not spend.
    IF NEW.txn_kind <> 'expense' THEN
        RETURN NEW;
    END IF;

    -- Fix 2: only reason on a confirmed limit — same invariant as every Kotlin reader.
    SELECT monthly_limit INTO v_limit
    FROM zad_users
    WHERE id = NEW.user_id AND limit_confirmed_at IS NOT NULL;
    IF v_limit IS NULL OR v_limit <= 0 THEN
        RETURN NEW;
    END IF;

    current_month := to_char(NEW.created_at, 'YYYY-MM');

    SELECT COALESCE(SUM(amount), 0) INTO month_spent
    FROM zad_transactions
    WHERE user_id = NEW.user_id
      AND txn_kind = 'expense'
      AND to_char(created_at, 'YYYY-MM') = current_month;

    spent_pct := (month_spent::NUMERIC / v_limit * 100)::INT;

    threshold_to_fire := NULL;
    IF spent_pct >= 100 AND NOT EXISTS (
        SELECT 1 FROM sent_telegram_budget_alerts WHERE user_id = NEW.user_id AND threshold = 100 AND month = current_month
    ) THEN
        threshold_to_fire := 100;
    ELSIF spent_pct >= 90 AND NOT EXISTS (
        SELECT 1 FROM sent_telegram_budget_alerts WHERE user_id = NEW.user_id AND threshold = 90 AND month = current_month
    ) THEN
        threshold_to_fire := 90;
    ELSIF spent_pct >= 75 AND NOT EXISTS (
        SELECT 1 FROM sent_telegram_budget_alerts WHERE user_id = NEW.user_id AND threshold = 75 AND month = current_month
    ) THEN
        threshold_to_fire := 75;
    END IF;

    IF threshold_to_fire IS NOT NULL THEN
        INSERT INTO sent_telegram_budget_alerts (user_id, threshold, month)
            VALUES (NEW.user_id, threshold_to_fire, current_month)
            ON CONFLICT (user_id, threshold, month) DO NOTHING;

        push_title := CASE threshold_to_fire
            WHEN 100 THEN '⛔ وصلت لحد ميزانيتك'
            WHEN 90 THEN '⚠️ ميزانيتك قاربت النفاد'
            WHEN 75 THEN '💡 استخدمت 75% من ميزانيتك'
        END;
        push_body := 'مصروف الشهر: ' || month_spent::TEXT || ' من ' || v_limit::TEXT || ' (' || spent_pct::TEXT || '%)';

        PERFORM net.http_post(
            url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push',
            headers:=jsonb_build_object('Content-Type', 'application/json', 'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')),
            body:=jsonb_build_object('user_id', NEW.user_id, 'title', push_title, 'body', push_body,
                                     'voice', threshold_to_fire >= 90),
            timeout_milliseconds:=15000
        );
    END IF;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.notify_telegram_on_insight()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    is_linked BOOLEAN;
    push_title TEXT;
    push_body TEXT;
BEGIN
    IF NEW.status != 'pending' OR NOT (NEW.kind = 'question' OR NEW.priority = 'critical') THEN
        RETURN NEW;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM telegram_bindings WHERE user_id = NEW.user_id AND bound_at IS NOT NULL
    ) INTO is_linked;
    IF NOT is_linked THEN
        RETURN NEW;
    END IF;

    push_title := CASE WHEN NEW.kind = 'question' THEN '❓ سؤال من زاد' ELSE '🔔 تنبيه من زاد' END;
    push_body := NEW.title || E'\n' || NEW.body
        || CASE WHEN NEW.kind = 'question' THEN E'\n\nرد هنا بإجابتك.' ELSE '' END;

    PERFORM net.http_post(
        url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push',
        headers:=jsonb_build_object('Content-Type', 'application/json', 'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')),
        body:=jsonb_build_object('user_id', NEW.user_id, 'title', push_title, 'body', push_body,
                                 'voice', NEW.kind <> 'question' AND NEW.priority = 'critical'),
        timeout_milliseconds:=15000
    );

    RETURN NEW;
END;
$function$;
