// قاعدة Postgres حقيقية جوه الاختبار (PGlite = Postgres 16 مبني WASM) لمراحل الماسح الاستباقي
// (agent_proactive_scan). مراحل الماسح SQL بالكامل، فاختبار بيقرا نص الميجريشن بـregex ماكانش
// بيثبت سلوكها — هنا الميجريشن نفسها بتتنفذ والماسح بيتنادى والصفوف اللي كتبها بتتقرا.
//
// الجداول هنا فيها الأعمدة اللي المراحل بتلمسها بس، بنفس أنواعها وقيودها على الحي (مقيسة من
// information_schema 2026-10-11). الماسح نفسه و zad_market_timezone بيتحمّلوا من ملفات
// الميجريشن، والمراحل التانية stubs فاضية — كل اختبار بيحمّل الميجريشن اللي بيختبرها فوق ده.
import { PGlite } from "npm:@electric-sql/pglite@0.2.17";

export type Db = PGlite;

/** نص ميجريشن من supabase/migrations. */
export function migration(file: string): Promise<string> {
  return Deno.readTextFile(new URL(`../../migrations/${file}`, import.meta.url));
}

/** `create or replace function public.<name>(` لحد قفلة الـ$tag$; بتاعتها. */
export function functionBlock(sql: string, name: string): string {
  const start = sql.indexOf(`create or replace function public.${name}(`);
  if (start < 0) throw new Error(`${name} not found`);
  const tag = /\bas\s+(\$[a-z_]*\$)/i.exec(sql.slice(start));
  if (!tag) throw new Error(`${name}: no dollar-quoted body`);
  const open = start + tag.index + tag[0].length;
  const close = sql.indexOf(`${tag[1]};`, open);
  if (close < 0) throw new Error(`${name}: body never closes`);
  return sql.slice(start, close + tag[1].length + 1);
}

/** المراحل اللي الماسح بيناديها قبل ما أي شريحة جديدة تتضاف (20260930130000). */
const EXISTING_STAGES = [
  "spending_ahead", "bill_reminder", "warranty_reminder", "listener_gap_alert", "spend_forecast",
  "habit_budget", "predicted_shortage", "home_weekly_digest", "med_followup",
];

const BASE = `
  create role anon; create role authenticated; create role service_role;
  create schema auth;
  create table auth.users (id uuid primary key);

  create table public.zad_users (
    id uuid primary key default gen_random_uuid(),
    country text, currency text,
    monthly_limit numeric, limit_confirmed_at timestamptz,
    sleep_bed time, sleep_wake time
  );

  create table public.zad_transactions (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null,
    amount double precision not null,
    title text not null,
    category text,
    is_expense boolean default true,
    created_at timestamptz default now(),
    txn_kind text not null default 'expense',
    merchant_name text,
    currency text
  );

  create table public.zad_insights (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    kind text not null check (kind in ('insight','question','alert')),
    surface text not null check (surface in ('home_card','bell','voice')),
    priority text not null default 'normal' check (priority in ('normal','critical')),
    title text not null,
    body text not null,
    dedupe_key text not null,
    status text not null default 'pending' check (status in ('pending','seen','acted','dismissed')),
    action_type text,
    about_item text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    dismiss_reason text check (dismiss_reason in ('not_relevant','wrong_data','timing')),
    expires_at timestamptz
  );
  create unique index idx_zad_insights_user_dedupe on public.zad_insights(user_id, dedupe_key);

  create table public.zad_pharmacy_items (user_id uuid, is_recurring boolean);
  create table public.zad_brain_health_alerts (
    alert_date date, kind text, total_runs int, bad_runs int, bad_pct numeric, top_error text,
    primary key (alert_date, kind)
  );

  create function public.agent_brain_cost_guard() returns int language sql as $$ select 0 $$;
  create function public._agent_proactive_suppressed(uuid, text) returns boolean language sql as $$ select false $$;
  create function public.zad_notify_admin(text, text) returns void language sql as $$ select $$;
  ${EXISTING_STAGES.map((s) => `create function public._agent_${s}_for_user(uuid) returns void language sql as $$ select $$;`).join("\n")}
`;

/** قاعدة فيها الجداول والماسح كما هو قبل الشرايح (stage list آخرها predicted_shortage). */
export async function scanDb(scanFrom = "20260930130000_predicted_shortage.sql"): Promise<Db> {
  const db = new PGlite();
  await db.exec(BASE);
  await db.exec(functionBlock(await migration("20261001170000_unknown_country_cairo_time.sql"), "zad_market_timezone"));
  await db.exec(functionBlock(await migration(scanFrom), "agent_proactive_scan"));
  return db;
}

/** حساب حقيقي (في auth.users و zad_users). */
export async function addUser(
  db: Db,
  u: { country?: string; currency?: string } = {},
): Promise<string> {
  const id = crypto.randomUUID();
  await db.query("insert into auth.users (id) values ($1)", [id]);
  await db.query("insert into public.zad_users (id, country, currency) values ($1, $2, $3)", [
    id, u.country ?? "EG", u.currency ?? "EGP",
  ]);
  return id;
}

/** ينادي الماسح كله ويرجّع ملخصه. */
export async function runScan(db: Db): Promise<{ scanned: number; failed: number; errors: unknown[] }> {
  const r = await db.query<{ s: { scanned: number; failed: number; errors: unknown[] } }>(
    "select public.agent_proactive_scan() as s",
  );
  return r.rows[0].s;
}
