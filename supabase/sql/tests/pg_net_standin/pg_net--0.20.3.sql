create schema if not exists net;
create unlogged table net.http_request_queue(
  id bigserial, method text not null, url text not null, headers jsonb not null,
  body bytea, timeout_milliseconds int not null);
create unlogged table net._http_response(id bigint, status_code int, created timestamptz not null default now());
create function net.http_post(url text, body jsonb default '{}'::jsonb, params jsonb default '{}'::jsonb,
  headers jsonb default '{"Content-Type": "application/json"}'::jsonb, timeout_milliseconds int default 5000)
returns bigint language plpgsql volatile as $$
declare rid bigint;
begin
  insert into net.http_request_queue(method, url, headers, body, timeout_milliseconds)
  values ('POST', url, headers, convert_to(body::text, 'UTF8'), timeout_milliseconds) returning id into rid;
  return rid;
end $$;
grant usage on schema net to PUBLIC;
grant all on all sequences in schema net to PUBLIC;
grant all on all tables in schema net to PUBLIC;
