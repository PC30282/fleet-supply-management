-- Automatic cleanup for Fleet Supply Management
-- Run this in Supabase SQL Editor.
-- This tracks when requests become Delivered, removes Delivered requests after 30 days,
-- and removes old checklist records after 30 days when a newer checklist exists.

alter table public.requests
  add column if not exists delivered_at timestamptz;

update public.requests
set delivered_at = coalesce(delivered_at, created_at)
where status = 'Delivered'
  and delivered_at is null;

create or replace function public.set_request_delivered_at()
returns trigger
language plpgsql
as $$
begin
  if new.status = 'Delivered' and old.status is distinct from 'Delivered' then
    new.delivered_at = now();
  elsif new.status is distinct from 'Delivered' then
    new.delivered_at = null;
  end if;
  return new;
end;
$$;

drop trigger if exists set_request_delivered_at on public.requests;
create trigger set_request_delivered_at
  before update of status on public.requests
  for each row
  execute function public.set_request_delivered_at();

create or replace function public.cleanup_fleet_supply_records()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.requests
  where status = 'Delivered'
    and coalesce(delivered_at, created_at) < now() - interval '30 days';

  delete from public.fleet_checklists old_check
  where old_check.completed_at < now() - interval '30 days'
    and exists (
      select 1
      from public.fleet_checklists newer_check
      where newer_check.completed_at > old_check.completed_at
        and (
          (old_check.vehicle_id is not null and newer_check.vehicle_id = old_check.vehicle_id)
          or lower(replace(newer_check.vehicle_vrm, ' ', '')) = lower(replace(old_check.vehicle_vrm, ' ', ''))
        )
    );
end;
$$;

-- Run once immediately after setup if you want to clean existing old data now:
-- select public.cleanup_fleet_supply_records();

-- Optional automatic schedule, if pg_cron is enabled in your Supabase project:
-- create extension if not exists pg_cron with schema extensions;
-- select cron.schedule(
--   'fleet-supply-cleanup-daily',
--   '15 3 * * *',
--   'select public.cleanup_fleet_supply_records();'
-- );
