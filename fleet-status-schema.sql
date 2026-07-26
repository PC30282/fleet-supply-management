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
  status_reason text not null default '',
  status_reason_updated_at timestamptz,
  created_at timestamptz not null default now()
);

alter table public.fleet_vehicles
  add column if not exists status_reason text not null default '',
  add column if not exists status_reason_updated_at timestamptz;

create table if not exists public.fleet_checklists (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid references public.fleet_vehicles(id) on delete cascade,
  vehicle_vrm text not null,
  completed_at timestamptz not null default now(),
  completed_by text not null,
  notes text
);

create table if not exists public.supervisor_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  collar_number text not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.audit_log (
  id uuid primary key default gen_random_uuid(),
  action text not null,
  entity_type text not null,
  entity_id text,
  vehicle_vrm text,
  item text,
  details text,
  actor text,
  created_at timestamptz not null default now()
);

alter table public.fleet_vehicles enable row level security;
alter table public.fleet_checklists enable row level security;
alter table public.supervisor_profiles enable row level security;
alter table public.audit_log enable row level security;

grant usage on schema public to anon, authenticated;
grant select on public.fleet_vehicles to anon, authenticated;
grant select on public.fleet_checklists to anon, authenticated;
grant insert, update, delete on public.fleet_vehicles to authenticated;
grant insert on public.fleet_checklists to anon, authenticated;
grant delete on public.fleet_checklists to authenticated;
grant select, insert, update on public.supervisor_profiles to authenticated;
grant select on public.audit_log to authenticated;

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

drop policy if exists "Supervisors can delete fleet checklists" on public.fleet_checklists;
create policy "Supervisors can delete fleet checklists"
  on public.fleet_checklists for delete
  to authenticated
  using (true);

drop policy if exists "Users can read their own supervisor profile" on public.supervisor_profiles;
create policy "Users can read their own supervisor profile"
  on public.supervisor_profiles for select
  to authenticated
  using (auth.uid() = user_id);

drop policy if exists "Users can create their own supervisor profile" on public.supervisor_profiles;
create policy "Users can create their own supervisor profile"
  on public.supervisor_profiles for insert
  to authenticated
  with check (auth.uid() = user_id);

drop policy if exists "Users can update their own supervisor profile" on public.supervisor_profiles;
create policy "Users can update their own supervisor profile"
  on public.supervisor_profiles for update
  to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "Supervisors can read audit log" on public.audit_log;
create policy "Supervisors can read audit log"
  on public.audit_log for select
  to authenticated
  using (true);

create index if not exists fleet_vehicles_sort_idx on public.fleet_vehicles(sort_order, vrm);
create index if not exists fleet_checklists_vehicle_idx on public.fleet_checklists(vehicle_id, completed_at desc);
create index if not exists audit_log_created_idx on public.audit_log(created_at desc);
create index if not exists audit_log_vehicle_idx on public.audit_log(vehicle_vrm, created_at desc);

create or replace function public.add_audit_log(
  audit_action text,
  audit_entity_type text,
  audit_entity_id text default null,
  audit_vehicle_vrm text default null,
  audit_item text default null,
  audit_details text default null,
  audit_actor text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.audit_log(action, entity_type, entity_id, vehicle_vrm, item, details, actor)
  values(audit_action, audit_entity_type, audit_entity_id, audit_vehicle_vrm, audit_item, audit_details, audit_actor);
end;
$$;

grant execute on function public.add_audit_log(text, text, text, text, text, text, text) to anon, authenticated;

create or replace function public.update_fleet_vehicle_status(
  vehicle_id uuid,
  new_status text,
  collar_number text,
  status_reason text default ''
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  old_status text;
  vrm_text text;
  clean_reason text;
begin
  if new_status not in ('On-Road', 'Reported', 'Off-Road') then
    raise exception 'Invalid vehicle status';
  end if;

  if nullif(trim(collar_number), '') is null then
    raise exception 'Collar number is required';
  end if;

  clean_reason := coalesce(trim(status_reason), '');

  select status, vrm into old_status, vrm_text
  from public.fleet_vehicles
  where id = vehicle_id;

  if not found then
    raise exception 'Vehicle not found';
  end if;

  update public.fleet_vehicles
  set status = new_status,
      status_updated_at = now(),
      status_updated_by = 'Collar ' || trim(collar_number),
      status_reason = case when new_status = 'On-Road' then '' else clean_reason end,
      status_reason_updated_at = case when new_status = 'On-Road' then null else now() end
  where id = vehicle_id;

  perform public.add_audit_log(
    'Vehicle status changed',
    'fleet_vehicle',
    vehicle_id::text,
    vrm_text,
    null,
    old_status || ' > ' || new_status || case when clean_reason <> '' then ': ' || clean_reason else '' end,
    'Collar ' || trim(collar_number)
  );
end;
$$;

grant execute on function public.update_fleet_vehicle_status(uuid, text, text, text) to anon, authenticated;
