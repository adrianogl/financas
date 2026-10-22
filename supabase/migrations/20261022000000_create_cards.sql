create table public.card_connections (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  item_id text not null unique,
  status text not null default 'active' check (status in ('active', 'needs_reconnect', 'error')),
  last_synced_at timestamptz,
  last_error text,
  created_at timestamptz not null default now()
);

create table public.card_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  connection_id uuid not null references public.card_connections(id) on delete cascade,
  pluggy_account_id text not null unique,
  name text not null,
  last_digits text not null,
  nickname text not null check (length(trim(nickname)) > 0)
);

create table public.card_transactions (
  id text primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  card_account_id uuid not null references public.card_accounts(id) on delete cascade,
  date date not null,
  description text not null,
  amount numeric(12,2) not null check (amount >= 0),
  type text not null check (type in ('DEBIT', 'CREDIT')),
  is_pending boolean not null,
  installment_number smallint,
  total_installments smallint,
  purchase_date date
);

create table public.card_recurrences (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  card_account_id uuid not null references public.card_accounts(id) on delete cascade,
  merchant_key text not null,
  status text not null check (status in ('confirmed', 'dismissed', 'ended')),
  ended_on date,
  check ((status = 'ended') = (ended_on is not null)),
  unique (card_account_id, merchant_key)
);

create index card_connections_user_id_idx on public.card_connections (user_id);
create index card_accounts_user_id_idx on public.card_accounts (user_id);
create index card_transactions_user_id_idx on public.card_transactions (user_id);
create index card_transactions_account_date_idx on public.card_transactions (card_account_id, date);
create index card_recurrences_user_id_idx on public.card_recurrences (user_id);

alter table public.card_connections enable row level security;
alter table public.card_accounts enable row level security;
alter table public.card_transactions enable row level security;
alter table public.card_recurrences enable row level security;

create policy "card_connections_select_own" on public.card_connections for select to authenticated using ((select auth.uid()) = user_id);
create policy "card_accounts_select_own" on public.card_accounts for select to authenticated using ((select auth.uid()) = user_id);
create policy "card_transactions_select_own" on public.card_transactions for select to authenticated using ((select auth.uid()) = user_id);
create policy "card_recurrences_select_own" on public.card_recurrences for select to authenticated using ((select auth.uid()) = user_id);

create policy "card_accounts_update_own" on public.card_accounts for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "card_recurrences_insert_own" on public.card_recurrences for insert to authenticated
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.card_accounts a where a.id = card_account_id and a.user_id = (select auth.uid()))
  );
create policy "card_recurrences_update_own" on public.card_recurrences for update to authenticated
  using ((select auth.uid()) = user_id)
  with check (
    (select auth.uid()) = user_id
    and exists (select 1 from public.card_accounts a where a.id = card_account_id and a.user_id = (select auth.uid()))
  );

create function public.card_accounts_only_nickname()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;
  if (new.id, new.user_id, new.connection_id, new.pluggy_account_id, new.name, new.last_digits)
    is distinct from (old.id, old.user_id, old.connection_id, old.pluggy_account_id, old.name, old.last_digits) then
    raise exception 'only nickname can be updated';
  end if;
  return new;
end;
$$;

create trigger card_accounts_only_nickname
before update on public.card_accounts
for each row execute function public.card_accounts_only_nickname();
