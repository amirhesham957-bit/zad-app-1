-- ٨.٥ الخطوة ٢، الجزء ١ (PLAN_8_5_EXTENSIONS.md): تنبيه ضايع أهون من صف ماتسجّلش.
--
-- التلات دوال دول بينادوا net.http_post من غير EXCEPTION. اتنين منهم تريجرز على
-- zad_inventory وzad_insights، فلو pg_net وقع (أو اتشال لحظة نقله لـextensions،
-- أو zad_cron_secret مالقاش السر) الكتابة نفسها بتترجع: كمية المخزن ماتتحدّثش،
-- والتنبيه/السؤال مايتسجّلش. والتالت zad_notify_admin بيتنادى من ١٢ مكان.
--
-- التعريفات هنا = الحي (اتقرت بـpg_get_functiondef ١٣/١١) بالحرف، والفرق الوحيد
-- إن النداء (ومعاه قراية السر) جوه begin … exception when others then raise warning.
-- notify_telegram_on_transaction وzad_push_family_message وzad_family_zone_event
-- محميين أصلاً.

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

    BEGIN
        PERFORM net.http_post(
            url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push',
            headers:=jsonb_build_object('Content-Type', 'application/json', 'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')),
            body:=jsonb_build_object('user_id', NEW.user_id, 'title', push_title, 'body', push_body,
                                     'voice', NEW.kind <> 'question' AND NEW.priority = 'critical',
                                     'moment', 'critical_insight'),
            timeout_milliseconds:=15000
        );
    EXCEPTION WHEN others THEN
        RAISE WARNING 'notify_telegram_on_insight: push skipped (%)', SQLERRM;
    END;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.notify_telegram_on_low_stock()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    is_linked BOOLEAN;
    v_avg_daily_qty NUMERIC;
    v_rate_known BOOLEAN;
    was_needing BOOLEAN;
    now_needing BOOLEAN;
BEGIN
    IF NEW.quantity >= OLD.quantity THEN
        RETURN NEW;
    END IF;

    SELECT EXISTS (
        SELECT 1 FROM telegram_bindings WHERE user_id = NEW.user_id AND bound_at IS NOT NULL
    ) INTO is_linked;
    IF NOT is_linked THEN
        RETURN NEW;
    END IF;

    SELECT avg_daily_qty, rate_known INTO v_avg_daily_qty, v_rate_known
        FROM zad_consumption WHERE user_id = NEW.user_id AND item_name = NEW.item_name;

    was_needing := public._inventory_needs_checkin(OLD.quantity, OLD.low_stock_threshold, v_avg_daily_qty, v_rate_known);
    now_needing := public._inventory_needs_checkin(NEW.quantity, NEW.low_stock_threshold, v_avg_daily_qty, v_rate_known);

    IF was_needing OR NOT now_needing THEN
        RETURN NEW;
    END IF;

    BEGIN
        PERFORM net.http_post(
            url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=live_checkin',
            headers:=jsonb_build_object('Content-Type', 'application/json', 'X-Live-Checkin-Secret', public.zad_cron_secret('zad_live_checkin_secret')),
            body:=jsonb_build_object('user_id', NEW.user_id, 'item_name', NEW.item_name, 'quantity', NEW.quantity),
            timeout_milliseconds:=15000
        );
    EXCEPTION WHEN others THEN
        RAISE WARNING 'notify_telegram_on_low_stock: checkin skipped (%)', SQLERRM;
    END;

    RETURN NEW;
END;
$function$;

CREATE OR REPLACE FUNCTION public.zad_notify_admin(p_title text, p_body text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  begin
    perform net.http_post(
      url := 'https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=admin_alert',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')
      ),
      body := jsonb_build_object('title', p_title, 'body', p_body),
      timeout_milliseconds := 15000
    );
  exception when others then
    raise warning 'zad_notify_admin: alert skipped (%)', sqlerrm;
  end;
end;
$function$;
