-- RAIZ | Estrutura do banco Supabase
-- Projeto: Raiz Agricultura
-- Este arquivo documenta a estrutura aplicada no projeto. Em um projeto novo,
-- execute pelo SQL Editor. Todas as tabelas públicas usam RLS.

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.farms (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  municipality text,
  state text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  category text,
  unit text not null default 'kg',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id)
);

create table if not exists public.production (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  farm_id uuid not null,
  product_id uuid not null,
  quantity numeric(12,3) not null check (quantity > 0),
  unit text not null default 'kg',
  produced_on date not null default current_date,
  notes text,
  created_at timestamptz not null default now(),
  foreign key (farm_id, owner_id) references public.farms(id, owner_id) on delete cascade,
  foreign key (product_id, owner_id) references public.products(id, owner_id) on delete cascade
);

create table if not exists public.movements (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  farm_id uuid not null,
  product_id uuid not null,
  movement_type text not null check (movement_type in ('producao','venda','doacao','consumo')),
  quantity numeric(12,3) not null check (quantity > 0),
  unit text not null default 'kg',
  unit_price numeric(12,2) check (unit_price is null or unit_price >= 0),
  occurred_on date not null default current_date,
  destination text,
  notes text,
  created_at timestamptz not null default now(),
  foreign key (farm_id, owner_id) references public.farms(id, owner_id) on delete cascade,
  foreign key (product_id, owner_id) references public.products(id, owner_id) on delete cascade,
  constraint sale_requires_price check (movement_type <> 'venda' or unit_price is not null)
);

create table if not exists public.market_prices (
  id uuid primary key default gen_random_uuid(),
  product_name text not null,
  normalized_name text not null,
  municipality text,
  region text,
  market_name text,
  average_price numeric(12,2) not null check (average_price >= 0),
  unit text not null default 'kg',
  source_name text not null,
  source_url text,
  quote_date date not null,
  created_at timestamptz not null default now()
);

create index if not exists farms_owner_id_idx on public.farms(owner_id);
create index if not exists products_owner_id_idx on public.products(owner_id);
create index if not exists production_owner_date_idx on public.production(owner_id, produced_on desc);
create index if not exists movements_owner_date_idx on public.movements(owner_id, occurred_on desc);
create index if not exists movements_product_idx on public.movements(product_id);
create index if not exists market_prices_lookup_idx on public.market_prices(normalized_name, quote_date desc);

create or replace function public.set_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, full_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', ''))
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.handle_new_user() from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.farms enable row level security;
alter table public.products enable row level security;
alter table public.production enable row level security;
alter table public.movements enable row level security;
alter table public.market_prices enable row level security;

-- Políticas de propriedade: cada conta só acessa suas próprias linhas.
drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own on public.profiles for select to authenticated using ((select auth.uid()) = id);
drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own on public.profiles for insert to authenticated with check ((select auth.uid()) = id);
drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

drop policy if exists farms_select_own on public.farms;
create policy farms_select_own on public.farms for select to authenticated using ((select auth.uid()) = owner_id);
drop policy if exists farms_insert_own on public.farms;
create policy farms_insert_own on public.farms for insert to authenticated with check ((select auth.uid()) = owner_id);
drop policy if exists farms_update_own on public.farms;
create policy farms_update_own on public.farms for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
drop policy if exists farms_delete_own on public.farms;
create policy farms_delete_own on public.farms for delete to authenticated using ((select auth.uid()) = owner_id);

drop policy if exists products_select_own on public.products;
create policy products_select_own on public.products for select to authenticated using ((select auth.uid()) = owner_id);
drop policy if exists products_insert_own on public.products;
create policy products_insert_own on public.products for insert to authenticated with check ((select auth.uid()) = owner_id);
drop policy if exists products_update_own on public.products;
create policy products_update_own on public.products for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
drop policy if exists products_delete_own on public.products;
create policy products_delete_own on public.products for delete to authenticated using ((select auth.uid()) = owner_id);

drop policy if exists production_select_own on public.production;
create policy production_select_own on public.production for select to authenticated using ((select auth.uid()) = owner_id);
drop policy if exists production_insert_own on public.production;
create policy production_insert_own on public.production for insert to authenticated with check ((select auth.uid()) = owner_id);
drop policy if exists production_update_own on public.production;
create policy production_update_own on public.production for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
drop policy if exists production_delete_own on public.production;
create policy production_delete_own on public.production for delete to authenticated using ((select auth.uid()) = owner_id);

drop policy if exists movements_select_own on public.movements;
create policy movements_select_own on public.movements for select to authenticated using ((select auth.uid()) = owner_id);
drop policy if exists movements_insert_own on public.movements;
create policy movements_insert_own on public.movements for insert to authenticated with check ((select auth.uid()) = owner_id);
drop policy if exists movements_update_own on public.movements;
create policy movements_update_own on public.movements for update to authenticated using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
drop policy if exists movements_delete_own on public.movements;
create policy movements_delete_own on public.movements for delete to authenticated using ((select auth.uid()) = owner_id);

drop policy if exists market_prices_read_authenticated on public.market_prices;
create policy market_prices_read_authenticated on public.market_prices for select to authenticated using (true);

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles, public.farms, public.products, public.production, public.movements to authenticated;
grant select on public.market_prices to authenticated;
