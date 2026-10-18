alter table public.expenses
  add column kind text not null default 'bill' check (kind in ('bill', 'spending'));

alter table public.expense_bills
  add column bill_parts jsonb,
  add column paid_parts jsonb;

create table public.expense_parts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  expense_id uuid not null references public.expenses(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  position smallint not null,
  unique (expense_id, name)
);

create table public.expense_part_terms (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  part_id uuid not null references public.expense_parts(id) on delete cascade,
  valid_from date not null check (extract(day from valid_from) = 1),
  amount numeric(12,2) not null check (amount > 0),
  is_fixed boolean not null,
  average_from date not null check (extract(day from average_from) = 1),
  is_active boolean not null,
  unique (part_id, valid_from)
);

create table public.expense_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  expense_id uuid not null references public.expenses(id) on delete cascade,
  spent_on date not null,
  amount numeric(12,2) not null check (amount > 0)
);

create index expense_parts_user_id_idx on public.expense_parts (user_id);
create index expense_part_terms_user_id_idx on public.expense_part_terms (user_id);
create index expense_entries_user_id_idx on public.expense_entries (user_id);

alter table public.expense_parts enable row level security;
alter table public.expense_part_terms enable row level security;
alter table public.expense_entries enable row level security;

create policy "expense_parts_select_own" on public.expense_parts for select to authenticated using ((select auth.uid()) = user_id);
create policy "expense_parts_insert_own" on public.expense_parts for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "expense_parts_update_own" on public.expense_parts for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "expense_parts_delete_own" on public.expense_parts for delete to authenticated using ((select auth.uid()) = user_id);

create policy "expense_part_terms_select_own" on public.expense_part_terms for select to authenticated using ((select auth.uid()) = user_id);
create policy "expense_part_terms_insert_own" on public.expense_part_terms for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expense_parts p where p.id = part_id and p.user_id = (select auth.uid()))
  );
create policy "expense_part_terms_update_own" on public.expense_part_terms for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expense_parts p where p.id = part_id and p.user_id = (select auth.uid()))
  );
create policy "expense_part_terms_delete_own" on public.expense_part_terms for delete to authenticated using ((select auth.uid()) = user_id);

create policy "expense_entries_select_own" on public.expense_entries for select to authenticated using ((select auth.uid()) = user_id);
create policy "expense_entries_insert_own" on public.expense_entries for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "expense_entries_update_own" on public.expense_entries for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.expenses e where e.id = expense_id and e.user_id = (select auth.uid()))
  );
create policy "expense_entries_delete_own" on public.expense_entries for delete to authenticated using ((select auth.uid()) = user_id);
