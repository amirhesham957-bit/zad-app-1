-- ZAD_PLAN 8.3: «بلّغ عن الرد» — the customer reports one of Zad's chat replies.
--
-- Google Play's AI-generated content policy asks every app that generates content to let its users report
-- offensive output from inside the app. The flag under a reply sends its id, its text as the customer saw it,
-- and one of four reasons. One report per reply per customer; reporting again changes the reason.
--
-- Written only through zad_report_reply (auth.uid(), never a user id from the client). Customers read nothing
-- here; the owner reviews it with the service role.

create table if not exists public.zad_reply_reports (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  message_id text not null,
  reply_text text not null,
  reason text not null check (reason in ('offensive', 'wrong', 'harmful', 'other')),
  reported_at timestamptz not null default now(),
  unique (user_id, message_id)
);
create index if not exists zad_reply_reports_at on public.zad_reply_reports (reported_at);

alter table public.zad_reply_reports enable row level security;
revoke all on table public.zad_reply_reports from anon, authenticated;

create or replace function public.zad_report_reply(p_message_id text, p_reply_text text, p_reason text)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_user uuid := auth.uid();
  v_id text := left(btrim(coalesce(p_message_id, '')), 200);
  v_text text := left(btrim(coalesce(p_reply_text, '')), 4000);
begin
  if v_user is null then
    return jsonb_build_object('ok', false, 'reason', 'signed_out');
  end if;
  if v_id = '' or v_text = '' or p_reason is null or p_reason not in ('offensive', 'wrong', 'harmful', 'other') then
    return jsonb_build_object('ok', false, 'reason', 'invalid');
  end if;
  -- A runaway client cannot fill the table: 50 reports a day is far past any honest use.
  if (select count(*) from public.zad_reply_reports r
       where r.user_id = v_user and r.reported_at > now() - interval '1 day') >= 50 then
    return jsonb_build_object('ok', false, 'reason', 'too_many');
  end if;

  insert into public.zad_reply_reports (user_id, message_id, reply_text, reason)
  values (v_user, v_id, v_text, p_reason)
  on conflict (user_id, message_id) do update
    set reason = excluded.reason, reported_at = now();

  return jsonb_build_object('ok', true);
end;
$function$;

revoke all on function public.zad_report_reply(text, text, text) from public, anon;
grant execute on function public.zad_report_reply(text, text, text) to authenticated;
