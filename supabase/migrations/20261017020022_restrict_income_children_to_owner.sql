drop policy "income_amounts_insert_own" on public.income_amounts;
drop policy "income_amounts_update_own" on public.income_amounts;
drop policy "income_receipts_insert_own" on public.income_receipts;
drop policy "income_receipts_update_own" on public.income_receipts;

create policy "income_amounts_insert_own" on public.income_amounts for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.incomes i where i.id = income_id and i.user_id = (select auth.uid()))
  );
create policy "income_amounts_update_own" on public.income_amounts for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.incomes i where i.id = income_id and i.user_id = (select auth.uid()))
  );

create policy "income_receipts_insert_own" on public.income_receipts for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.incomes i where i.id = income_id and i.user_id = (select auth.uid()))
  );
create policy "income_receipts_update_own" on public.income_receipts for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.incomes i where i.id = income_id and i.user_id = (select auth.uid()))
  );
