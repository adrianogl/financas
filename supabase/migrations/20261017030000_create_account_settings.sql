create table public.account_settings (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  enabled_kinds text[] not null default '{fixed,hourly,one_off}'
    check (cardinality(enabled_kinds) > 0 and enabled_kinds <@ array['fixed', 'hourly', 'one_off']),
  non_business_day text not null default 'next' check (non_business_day in ('next', 'previous', 'keep')),
  overdue_morning_enabled boolean not null default true,
  overdue_morning_time time not null default '08:00',
  overdue_evening_enabled boolean not null default true,
  overdue_evening_time time not null default '19:00',
  due_today_enabled boolean not null default true,
  due_today_time time not null default '08:00',
  updated_at timestamptz not null default now()
);

alter table public.account_settings enable row level security;

create policy "account_settings_select_own" on public.account_settings for select to authenticated using ((select auth.uid()) = user_id);
create policy "account_settings_insert_own" on public.account_settings for insert to authenticated with check ((select auth.uid()) = user_id);
create policy "account_settings_update_own" on public.account_settings for update to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
