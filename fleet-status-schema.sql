-- Fleet Status tables for the Tamworth Vehicle Supplies app
-- Run this in Supabase SQL Editor.

create table if not exists public.fleet_vehicles (
  id uuid primary key default gen_random_uuid(),
  vrm text not null unique,
  make text not null default '',
  model text not null default '',
  vehicle_type text not null default 'Marked' check (vehicle_type in ('Marked', 'Unmarked')),
  status text not null default 'On-Road' check (status in ('On-Road', 'Reported', 'Off-Road')),
  sort_order integer not null default 0,
  status_updated_at timestamptz,
  status_updated_by text,
  created_at timestamptz not null default now()
);

create table if not exists public.fleet_checklists (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid references public.fleet_vehicles(id) on delete cascade,
  vehicle_vrm text not null,
  completed_at timestamptz not null default now(),
  completed_by text not null,
  notes text
);

alter table public.fleet_vehicles enable row level security;
alter table public.fleet_checklists enable row level security;

grant usage on schema public to anon, authenticated;
grant select on public.fleet_vehicles to anon, authenticated;
grant select on public.fleet_checklists to anon, authenticated;
grant insert, update, delete on public.fleet_vehicles to authenticated;
grant insert on public.fleet_checklists to anon, authenticated;

drop policy if exists "Fleet vehicles are readable" on public.fleet_vehicles;
create policy "Fleet vehicles are readable"
  on public.fleet_vehicles for select
  to anon, authenticated
  using (true);

drop policy if exists "Supervisors can manage fleet vehicles" on public.fleet_vehicles;
create policy "Supervisors can manage fleet vehicles"
  on public.fleet_vehicles for all
  to authenticated
  using (true)
  with check (true);

drop policy if exists "Fleet checklists are readable" on public.fleet_checklists;
create policy "Fleet checklists are readable"
  on public.fleet_checklists for select
  to anon, authenticated
  using (true);

drop policy if exists "Supervisors can record fleet checklists" on public.fleet_checklists;
drop policy if exists "Public users can record fleet checklists" on public.fleet_checklists;
create policy "Public users can record fleet checklists"
  on public.fleet_checklists for insert
  to anon, authenticated
  with check (true);

create index if not exists fleet_vehicles_sort_idx on public.fleet_vehicles(sort_order, vrm);
create index if not exists fleet_checklists_vehicle_idx on public.fleet_checklists(vehicle_id, completed_at desc);
