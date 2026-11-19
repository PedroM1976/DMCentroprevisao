-- SEM AUTENTICAÇÃO: palavra-passe do HTML é apenas uma barreira visual.
-- Permite leitura e gravação públicas pela API. Executar também se já instalou
-- a versão anterior: preserva os movimentos existentes.
begin;
create table if not exists public.dm_finance_state (
 id integer primary key check (id=1), version integer not null default 0,
 movements jsonb not null default '[]'::jsonb check(jsonb_typeof(movements)='array'),
 updated_at timestamptz not null default now(), updated_by uuid references auth.users(id)
);
insert into public.dm_finance_state(id) values(1) on conflict do nothing;
alter table public.dm_finance_state enable row level security;
revoke all on public.dm_finance_state from anon,authenticated;
grant select on public.dm_finance_state to anon,authenticated;
drop policy if exists dm_finance_read on public.dm_finance_state;
create policy dm_finance_read on public.dm_finance_state for select to anon,authenticated using(id=1);
create or replace function public.dm_finance_save(expected_version integer,new_movements jsonb)
returns integer language plpgsql security definer set search_path='' as $$
declare next_version integer;
begin
 if new_movements is null or jsonb_typeof(new_movements)<>'array' then raise exception 'DM_INVALID_DATA'; end if;
 if jsonb_array_length(new_movements)>50000 or octet_length(new_movements::text)>20000000 then raise exception 'DM_DATA_TOO_LARGE'; end if;
 update public.dm_finance_state set movements=new_movements,version=version+1,updated_at=now(),updated_by=null where id=1 and version=expected_version returning version into next_version;
 if not found then raise exception 'DM_CONFLICT'; end if;
 return next_version;
end $$;
revoke all on function public.dm_finance_save(integer,jsonb) from public,anon,authenticated;
grant execute on function public.dm_finance_save(integer,jsonb) to anon,authenticated;
commit;
