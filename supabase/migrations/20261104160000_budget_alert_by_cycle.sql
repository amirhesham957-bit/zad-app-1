-- تنبيه الميزانية في تليجرام بيمشي على دورة المرتب، وكل مصروف بيقول إحنا فين، وبعد ١٠٠٪ مابيسكتش (المالك ٤/١١).
--
-- المالك: «لما الفلوس تخلص من الكرت ونعدّي حد المصروف التطبيق بيبطّل يراقب… المفروض يقول للعميل إحنا صرفنا
-- زيادة وعدّينا المصروف ويبتدي يتعلم ويتنبأ ويدي نصايح». اللي كان بيحصل (notify_telegram_on_transaction):
-- • الحسبة بالشهر الميلادي (to_char 'YYYY-MM') مش بالدورة — بيت دورته من ٢٥ كان بيتقاس غلط.
-- • ٧٥ و٩٠ و١٠٠ مرة واحدة لكل شهر، وبعد الـ١٠٠ كل مصروف جديد بيتبعت «مصروف: … — مبلغ» من غير ولا كلمة
--   إن الميزانية اتعدّت، فبيبان إن زاد بطّل يراقب.
-- دلوقتي: الأرقام من zad_budget_state (السلطة الواحدة للميزانية، 20260809120000)، وكل مصروف بياخد سطر
-- «فاضل X من Y — N يوم» أو «⛔ عدّينا الميزانية بـ X»، والعتبات بتتسجل على بداية الدورة. عبور الـ١٠٠ بيقول
-- نصيحة واحدة من الأرقام نفسها (من غير موديل): الأيام الباقية والمطلوب يتوقف عليه.

create or replace function public.notify_telegram_on_transaction()
 returns trigger
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
    is_linked boolean;
    v_state jsonb;
    v_limit numeric;
    v_spent numeric;
    v_remaining numeric;
    v_days int;
    v_cycle text;
    v_currency text;
    spent_pct int;
    threshold_to_fire int;
    push_title text;
    push_body text;
    budget_line text := null;
begin
    select exists (
        select 1 from telegram_bindings where user_id = new.user_id and bound_at is not null
    ) into is_linked;
    if not is_linked then
        return new;
    end if;

    -- الميزانية بتاعة الدورة دي، بس لمصروف وعلى حد اتأكد (نفس شرط كل قارئ تاني). أي غلطة هنا ماتوقفش
    -- رسالة المعاملة نفسها.
    if new.txn_kind = 'expense' then
        begin
            v_state := public.zad_budget_state(new.user_id);
        exception when others then
            v_state := null;
        end;
        if v_state is not null and coalesce((v_state ->> 'limit_confirmed')::boolean, false) then
            v_limit := nullif((v_state ->> 'monthly_limit')::numeric, 0);
            v_spent := coalesce((v_state ->> 'spent')::numeric, 0);
            v_remaining := coalesce((v_state ->> 'remaining')::numeric, v_limit - v_spent);
            v_days := coalesce((v_state ->> 'days_left')::int, 0);
            v_cycle := coalesce(v_state ->> 'cycle_start', to_char(new.created_at, 'YYYY-MM'));
            v_currency := coalesce(v_state ->> 'currency', '');
        end if;
        if v_limit is not null and v_limit > 0 then
            budget_line := case
                when v_remaining < 0 then '⛔ عدّينا الميزانية بـ ' || round(-v_remaining)::text || ' ' || v_currency
                    || ' — فاضل ' || v_days::text || ' يوم في الدورة'
                else 'فاضل ' || round(v_remaining)::text || ' من ' || round(v_limit)::text || ' ' || v_currency
                    || ' — ' || v_days::text || ' يوم'
            end;
        end if;
    end if;

    if new.amount != 0 then
        push_title := 'زاد | معاملة جديدة';
        push_body := (case when new.txn_kind = 'transfer' and new.transfer_to = 'cash' then 'سحب كاش (مش مصروف — اللي هتصرفه منه هو اللي بيتحسب): ' when new.txn_kind = 'transfer' then 'تحويل: ' when new.txn_kind = 'income' then 'دخل: ' else 'مصروف: ' end)
            || new.title || ' — ' || new.amount::text
            || coalesce(E'\n' || budget_line, '');
        perform net.http_post(
            url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push',
            headers:=jsonb_build_object('Content-Type', 'application/json', 'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')),
            body:=jsonb_build_object('user_id', new.user_id, 'title', push_title, 'body', push_body),
            timeout_milliseconds:=15000
        );
    end if;

    if new.txn_kind <> 'expense' or v_limit is null or v_limit <= 0 then
        return new;
    end if;

    spent_pct := (v_spent / v_limit * 100)::int;

    -- العتبة مرة لكل دورة (month = بداية الدورة).
    threshold_to_fire := null;
    if spent_pct >= 100 and not exists (
        select 1 from sent_telegram_budget_alerts where user_id = new.user_id and threshold = 100 and month = v_cycle
    ) then
        threshold_to_fire := 100;
    elsif spent_pct >= 90 and not exists (
        select 1 from sent_telegram_budget_alerts where user_id = new.user_id and threshold = 90 and month = v_cycle
    ) then
        threshold_to_fire := 90;
    elsif spent_pct >= 75 and not exists (
        select 1 from sent_telegram_budget_alerts where user_id = new.user_id and threshold = 75 and month = v_cycle
    ) then
        threshold_to_fire := 75;
    end if;

    if threshold_to_fire is not null then
        insert into sent_telegram_budget_alerts (user_id, threshold, month)
            values (new.user_id, threshold_to_fire, v_cycle)
            on conflict (user_id, threshold, month) do nothing;

        push_title := case threshold_to_fire
            when 100 then '⛔ صرفنا أكتر من الميزانية'
            when 90 then '⚠️ ميزانيتك قاربت تخلص'
            when 75 then '💡 استخدمت 75% من ميزانيتك'
        end;
        push_body := 'مصروف الدورة: ' || round(v_spent)::text || ' من ' || round(v_limit)::text || ' ' || v_currency
            || ' (' || spent_pct::text || '%)، وفاضل ' || v_days::text || ' يوم.'
            || case
                when threshold_to_fire = 100 then
                    E'\nمن هنا للمرتب خلّي الصرف على الضروري بس (أكل، دوا، مواصلات)، وأنا هقولك مع كل مصروف إحنا فين. لو عايز نعيد توزيع الأيام الباقية قولّي «اعمللي خطة لحد المرتب».'
                when threshold_to_fire = 90 and v_days > 0 then
                    E'\nالباقي ' || round(greatest(v_remaining, 0))::text || ' — يعني حوالي ' || round(greatest(v_remaining, 0) / v_days)::text || ' في اليوم لحد آخر الدورة.'
                else ''
            end;

        perform net.http_post(
            url:='https://auuftqncrjsnyylolhbu.supabase.co/functions/v1/zad-telegram-bot?job=realtime_push',
            headers:=jsonb_build_object('Content-Type', 'application/json', 'X-Realtime-Push-Secret', public.zad_cron_secret('zad_realtime_push_secret')),
            body:=jsonb_build_object('user_id', new.user_id, 'title', push_title, 'body', push_body,
                                     'voice', threshold_to_fire >= 90,
                                     'moment', case when threshold_to_fire >= 100 then 'budget_100' else 'budget_90' end),
            timeout_milliseconds:=15000
        );
    end if;

    return new;
end;
$function$;
