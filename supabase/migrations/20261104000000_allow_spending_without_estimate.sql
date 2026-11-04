alter table public.expense_terms drop constraint expense_terms_estimated_amount_check;
alter table public.expense_terms add constraint expense_terms_estimated_amount_check check (estimated_amount >= 0);
