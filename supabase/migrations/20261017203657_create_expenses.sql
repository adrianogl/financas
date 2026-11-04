create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  start_month date not null check (extract(day from start_month) = 1),
  end_month date check (extract(day from end_month) = 1),
  created_at timestamptz not null default now(),
  check (end_month is null or end_month >= start_month)
);

create table public.expense_terms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  expense_id uuid not null references public.expenses(id) on delete cascade,
  valid_from date not null check (extract(day from valid_from) = 1),
  estimated_amount numeric(12,2) not null check (estimated_amount > 0),
  day_of_month smallint not null check (day_of_month between 1 and 31),
  average_from date not null check (extract(day from average_from) = 1),
  unique (expense_id, valid_from)
);

create table public.expense_bills (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  expense_id uuid not null references public.expenses(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  bill_amount numeric(12,2) check (bill_amount >= 0),
  bill_due_date date,
  paid_on date,
  paid_amount numeric(12,2) check (paid_amount >= 0),
  check ((bill_amount is null) = (bill_due_date is null)),
  check ((paid_on is null) = (paid_amount is null)),
  check (bill_amount is not null or paid_amount is not null),
  unique (expense_id, month)
);

create index expenses_user_id_idx on public.expenses (user_id);
create index expense_terms_user_id_idx on public.expense_terms (user_id);
create index expense_bills_user_id_idx on public.expense_bills (user_id);

alter table public.expenses enable row level security;
alter table public.expense_terms enable row level security;
alter table public.expense_bills enable row level security;

create policy "expenses_select_own" on public.expenses for select to authenticated using ((select auth.uid()) = user_id);
create policy "expenses_insert_own" on public.expenses for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "expenses_update_own" on public.expenses for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "expenses_delete_own" on public.expenses for delete to authenticated using ((select auth.uid()) = user_id);

create policy "expense_terms_select_own" on public.expense_terms for select to authenticated using ((select auth.uid()) = user_id);
create policy "expense_terms_insert_own" on public.expense_terms for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "expense_terms_update_own" on public.expense_terms for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "expense_terms_delete_own" on public.expense_terms for delete to authenticated using ((select auth.uid()) = user_id);

create policy "expense_bills_select_own" on public.expense_bills for select to authenticated using ((select auth.uid()) = user_id);
create policy "expense_bills_insert_own" on public.expense_bills for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "expense_bills_update_own" on public.expense_bills for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "expense_bills_delete_own" on public.expense_bills for delete to authenticated using ((select auth.uid()) = user_id);
