create table public.spending_suggestions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  merchant text not null check (length(trim(merchant)) > 0),
  merchant_key text not null check (length(merchant_key) > 0),
  card text not null default '',
  amount numeric(12,2) not null check (amount > 0),
  occurred_at timestamptz not null,
  reporter_devices uuid[] not null check (cardinality(reporter_devices) > 0),
  first_device_name text not null,
  status text not null default 'pending' check (status in ('pending', 'confirmed', 'dismissed')),
  expense_id uuid references public.expenses(id) on delete set null,
  entry_id uuid references public.expense_entries(id) on delete set null,
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  check ((status = 'pending') = (resolved_at is null))
);

create table public.merchant_spending_rules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  merchant_key text not null check (length(merchant_key) > 0),
  expense_id uuid not null references public.expenses(id) on delete cascade,
  auto_launch boolean not null default false,
  unique (user_id, merchant_key)
);

create index spending_suggestions_dedup_idx on public.spending_suggestions (user_id, merchant_key, card, amount, occurred_at);
create index spending_suggestions_status_idx on public.spending_suggestions (user_id, status);
create index spending_suggestions_expense_id_idx on public.spending_suggestions (expense_id);
create index spending_suggestions_entry_id_idx on public.spending_suggestions (entry_id);
create index merchant_spending_rules_expense_id_idx on public.merchant_spending_rules (expense_id);

alter table public.spending_suggestions enable row level security;
alter table public.merchant_spending_rules enable row level security;

create policy "spending_suggestions_select_own" on public.spending_suggestions for select to authenticated using ((select auth.uid()) = user_id);
create policy "spending_suggestions_insert_own" on public.spending_suggestions for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "spending_suggestions_update_own" on public.spending_suggestions for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and (expense_id is null or exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid())))
  );
create policy "spending_suggestions_delete_own" on public.spending_suggestions for delete to authenticated using ((select auth.uid()) = user_id);

create policy "merchant_spending_rules_select_own" on public.merchant_spending_rules for select to authenticated using ((select auth.uid()) = user_id);
create policy "merchant_spending_rules_insert_own" on public.merchant_spending_rules for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "merchant_spending_rules_update_own" on public.merchant_spending_rules for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "merchant_spending_rules_delete_own" on public.merchant_spending_rules for delete to authenticated using ((select auth.uid()) = user_id);

create function public.report_spending_suggestion(
  p_device uuid,
  p_device_name text,
  p_merchant text,
  p_merchant_key text,
  p_card text,
  p_amount numeric,
  p_occurred_at timestamptz
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_card text := coalesce(trim(p_card), '');
  v_amount numeric(12,2) := round(p_amount, 2);
  v_row public.spending_suggestions;
begin
  if v_user is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  perform pg_advisory_xact_lock(hashtextextended(v_user::text || '|' || p_merchant_key || '|' || v_card || '|' || v_amount::text, 0));

  select * into v_row
  from public.spending_suggestions s
  where s.user_id = v_user
    and s.merchant_key = p_merchant_key
    and s.card = v_card
    and s.amount = v_amount
    and s.occurred_at between p_occurred_at - interval '10 minutes' and p_occurred_at + interval '10 minutes'
    and not (p_device = any (s.reporter_devices))
  order by s.occurred_at
  limit 1
  for update;

  if found then
    update public.spending_suggestions
    set reporter_devices = array_append(reporter_devices, p_device)
    where id = v_row.id
    returning * into v_row;
    return jsonb_build_object('suggestion', to_jsonb(v_row), 'created', false);
  end if;

  insert into public.spending_suggestions (merchant, merchant_key, card, amount, occurred_at, reporter_devices, first_device_name)
  values (trim(p_merchant), p_merchant_key, v_card, v_amount, p_occurred_at, array[p_device], p_device_name)
  returning * into v_row;
  return jsonb_build_object('suggestion', to_jsonb(v_row), 'created', true);
end;
$$;

create function public.confirm_spending_suggestion(
  p_id uuid,
  p_expense_id uuid,
  p_spent_on date,
  p_auto_launch boolean default null
)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_row public.spending_suggestions;
  v_entry uuid;
begin
  select * into v_row from public.spending_suggestions where id = p_id for update;
  if not found then
    raise exception 'suggestion not found' using errcode = 'P0002';
  end if;

  if v_row.status = 'confirmed' then
    return jsonb_build_object('suggestion', to_jsonb(v_row), 'already', true);
  end if;

  if not exists (select 1 from public.expenses e where e.id = p_expense_id and e.kind = 'spending') then
    raise exception 'expense is not a monthly spending' using errcode = '22023';
  end if;

  insert into public.expense_entries (expense_id, spent_on, amount)
  values (p_expense_id, p_spent_on, v_row.amount)
  returning id into v_entry;

  update public.spending_suggestions
  set status = 'confirmed', expense_id = p_expense_id, entry_id = v_entry, resolved_at = now()
  where id = p_id
  returning * into v_row;

  insert into public.merchant_spending_rules as r (merchant_key, expense_id, auto_launch)
  values (v_row.merchant_key, p_expense_id, coalesce(p_auto_launch, false))
  on conflict (user_id, merchant_key) do update
  set expense_id = excluded.expense_id, auto_launch = coalesce(p_auto_launch, r.auto_launch);

  return jsonb_build_object('suggestion', to_jsonb(v_row), 'already', false);
end;
$$;

create function public.reopen_spending_suggestion(p_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_row public.spending_suggestions;
begin
  select * into v_row from public.spending_suggestions where id = p_id for update;
  if not found then
    raise exception 'suggestion not found' using errcode = 'P0002';
  end if;

  if v_row.status = 'pending' then
    return to_jsonb(v_row);
  end if;

  if v_row.entry_id is not null then
    delete from public.expense_entries where id = v_row.entry_id;
  end if;

  update public.spending_suggestions
  set status = 'pending', expense_id = null, entry_id = null, resolved_at = null
  where id = p_id
  returning * into v_row;
  return to_jsonb(v_row);
end;
$$;

create function public.move_spending_suggestion(p_id uuid, p_expense_id uuid)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_row public.spending_suggestions;
begin
  select * into v_row from public.spending_suggestions where id = p_id for update;
  if not found or v_row.status <> 'confirmed' or v_row.entry_id is null then
    raise exception 'suggestion is not launched' using errcode = 'P0002';
  end if;

  if not exists (select 1 from public.expenses e where e.id = p_expense_id and e.kind = 'spending') then
    raise exception 'expense is not a monthly spending' using errcode = '22023';
  end if;

  update public.expense_entries set expense_id = p_expense_id where id = v_row.entry_id;

  update public.spending_suggestions set expense_id = p_expense_id where id = p_id returning * into v_row;

  update public.merchant_spending_rules set expense_id = p_expense_id where merchant_key = v_row.merchant_key;

  return to_jsonb(v_row);
end;
$$;

revoke execute on function public.report_spending_suggestion(uuid, text, text, text, text, numeric, timestamptz) from public, anon;
revoke execute on function public.confirm_spending_suggestion(uuid, uuid, date, boolean) from public, anon;
revoke execute on function public.reopen_spending_suggestion(uuid) from public, anon;
revoke execute on function public.move_spending_suggestion(uuid, uuid) from public, anon;
grant execute on function public.report_spending_suggestion(uuid, text, text, text, text, numeric, timestamptz) to authenticated;
grant execute on function public.confirm_spending_suggestion(uuid, uuid, date, boolean) to authenticated;
grant execute on function public.reopen_spending_suggestion(uuid) to authenticated;
grant execute on function public.move_spending_suggestion(uuid, uuid) to authenticated;
