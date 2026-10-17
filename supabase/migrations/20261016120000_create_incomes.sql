create table public.incomes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  kind text not null check (kind in ('fixed', 'hourly', 'one_off')),
  day_of_month smallint check (day_of_month between 1 and 31),
  hours_per_day numeric(5,2) check (hours_per_day > 0),
  start_month date check (extract(day from start_month) = 1),
  end_month date check (extract(day from end_month) = 1),
  one_off_date date,
  one_off_amount numeric(12,2) check (one_off_amount > 0),
  created_at timestamptz not null default now(),
  check (
    (kind = 'fixed' and day_of_month is not null and start_month is not null and hours_per_day is null and one_off_date is null and one_off_amount is null)
    or (kind = 'hourly' and day_of_month is not null and start_month is not null and hours_per_day is not null and one_off_date is null and one_off_amount is null)
    or (kind = 'one_off' and one_off_date is not null and one_off_amount is not null and day_of_month is null and start_month is null and end_month is null and hours_per_day is null)
  ),
  check (end_month is null or end_month >= start_month)
);

create table public.income_amounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  income_id uuid not null references public.incomes(id) on delete cascade,
  amount numeric(12,2) not null check (amount > 0),
  valid_from date not null check (extract(day from valid_from) = 1),
  unique (income_id, valid_from)
);

create table public.income_receipts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  income_id uuid not null references public.incomes(id) on delete cascade,
  month date not null check (extract(day from month) = 1),
  received_on date not null,
  amount numeric(12,2) not null check (amount >= 0),
  worked_days smallint check (worked_days >= 0),
  worked_hours numeric(6,2) check (worked_hours >= 0),
  unique (income_id, month)
);

create index incomes_user_id_idx on public.incomes (user_id);
create index income_amounts_user_id_idx on public.income_amounts (user_id);
create index income_receipts_user_id_idx on public.income_receipts (user_id);

alter table public.incomes enable row level security;
alter table public.income_amounts enable row level security;
alter table public.income_receipts enable row level security;

create policy "incomes_select_own" on public.incomes for select to authenticated using ((select auth.uid()) = user_id);
create policy "incomes_insert_own" on public.incomes for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "incomes_update_own" on public.incomes for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "incomes_delete_own" on public.incomes for delete to authenticated using ((select auth.uid()) = user_id);

create policy "income_amounts_select_own" on public.income_amounts for select to authenticated using ((select auth.uid()) = user_id);
create policy "income_amounts_insert_own" on public.income_amounts for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "income_amounts_update_own" on public.income_amounts for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "income_amounts_delete_own" on public.income_amounts for delete to authenticated using ((select auth.uid()) = user_id);

create policy "income_receipts_select_own" on public.income_receipts for select to authenticated using ((select auth.uid()) = user_id);
create policy "income_receipts_insert_own" on public.income_receipts for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "income_receipts_update_own" on public.income_receipts for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy "income_receipts_delete_own" on public.income_receipts for delete to authenticated using ((select auth.uid()) = user_id);
