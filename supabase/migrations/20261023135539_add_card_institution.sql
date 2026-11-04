alter table public.card_connections add column institution_name text;
alter table public.card_accounts add column brand_label text;

create or replace function public.card_accounts_only_nickname()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;
  if (new.id, new.user_id, new.connection_id, new.pluggy_account_id, new.name, new.last_digits, new.brand_label)
    is distinct from (old.id, old.user_id, old.connection_id, old.pluggy_account_id, old.name, old.last_digits, old.brand_label) then
    raise exception 'only nickname can be updated';
  end if;
  return new;
end;
$$;
