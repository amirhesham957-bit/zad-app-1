-- What 20261114230000_pantry_calibration.sql calls beyond the pantry scaffolds: the admin message, caught here.
create table public.admin_messages (title text, body text);
create function public.zad_notify_admin(p_title text, p_body text) returns void language sql as $$
  insert into public.admin_messages values (p_title, p_body) $$;
