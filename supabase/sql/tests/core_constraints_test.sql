-- ZAD_OR_PLAN م٢.٣. بعد core_constraints_scaffold.sql و20261122200000_core_constraints.sql.

\set ON_ERROR_STOP on

-- القيد بيرفض الغلط. (raise exception لو اتقبل، ومش هيتمسك لأن سلفها مش check_violation.)
do $$
begin
  begin
    insert into public.zad_inventory (item_name, quantity) values ('neg-count', -1);
    raise exception 'negative quantity was accepted';
  exception when check_violation then null;
  end;

  begin
    update public.zad_inventory set quantity = -0.001 where item_name = 'legacy-rice';
    raise exception 'quantity update to negative was accepted';
  exception when check_violation then null;
  end;

  begin
    insert into public.zad_transactions (amount, title) values (-1, 'neg-amount');
    raise exception 'negative amount was accepted';
  exception when check_violation then null;
  end;

  begin
    insert into public.zad_transactions (amount, title) values (10000000.01, 'too-big');
    raise exception 'amount above the cap was accepted';
  exception when check_violation then null;
  end;

  begin
    insert into public.zad_transactions (amount, title) values ('NaN'::float8, 'nan');
    raise exception 'NaN amount was accepted';
  exception when check_violation then null;
  end;
end $$;

-- القيد بيقبل الصح، والحدود نفسها داخلة.
insert into public.zad_inventory (item_name, quantity) values
  ('zero-count', 0), ('half-kilo', 0.5), ('no-count', null);
insert into public.zad_transactions (amount, title) values
  (0, 'free'), (250.75, 'normal'), (10000000, 'at-cap');

-- NOT VALID: الصفوف القديمة المخالفة لسه موجودة، والمايجريشن ماوقعش عليها.
do $$
begin
  assert (select count(*) from public.zad_inventory where item_name = 'legacy-broken-count') = 1,
    'legacy negative quantity row was touched';
  assert (select count(*) from public.zad_transactions where title = 'legacy-negative') = 1,
    'legacy negative amount row was touched';
  assert (select count(*) from public.zad_inventory) = 5, 'inventory row count';
  assert (select count(*) from public.zad_transactions) = 5, 'transaction row count';
end $$;

select 'core_constraints_test ok';
