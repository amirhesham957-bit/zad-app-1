-- What zad_ai_budget_check (20261025193500) needs on top of brain_cost: the alerts table and a stub admin notifier.
create table public.zad_brain_health_alerts (alert_date date not null, total_runs int not null default 0, bad_runs int not null default 0,
  bad_pct int not null default 0, top_error text, created_at timestamptz not null default now(), kind text not null default 'failure_rate',
  primary key (alert_date, kind));
create table public.notified (title text, body text);
create function public.zad_notify_admin(p_title text, p_body text) returns void language sql as $$ insert into public.notified values (p_title, p_body) $$;
