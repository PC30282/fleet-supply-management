-- Notification setup for Fleet Supply Management
-- Run this in Supabase SQL Editor.
-- This stores the supervisor notification settings used by the website.
-- Immediate emails are sent by the notify-request Edge Function.
-- Daily, weekly and monthly digest rows are stored in notification_queue for a future scheduled sender.

create table if not exists public.app_settings (
  key text primary key,
  value text not null default '',
  updated_at timestamptz not null default now()
);

create table if not exists public.notification_queue (
  id uuid primary key default gen_random_uuid(),
  frequency text not null default 'daily' check (frequency in ('daily', 'weekly', 'monthly')),
  email text,
  recipient_email text,
  request_id uuid,
  request_data jsonb,
  section text,
  item text,
  vehicle text,
  quantity integer,
  requester text,
  notes text,
  created_at timestamptz not null default now(),
  sent_at timestamptz
);

alter table public.app_settings enable row level security;
alter table public.notification_queue enable row level security;

grant usage on schema public to anon, authenticated;
grant select on public.app_settings to anon, authenticated;
grant insert, update on public.app_settings to authenticated;
grant insert on public.notification_queue to anon, authenticated;
grant select, update, delete on public.notification_queue to authenticated;

drop policy if exists "App settings are readable" on public.app_settings;
create policy "App settings are readable"
  on public.app_settings for select
  to anon, authenticated
  using (true);

drop policy if exists "Supervisors can create app settings" on public.app_settings;
create policy "Supervisors can create app settings"
  on public.app_settings for insert
  to authenticated
  with check (true);

drop policy if exists "Supervisors can update app settings" on public.app_settings;
create policy "Supervisors can update app settings"
  on public.app_settings for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "Notifications can be queued" on public.notification_queue;
create policy "Notifications can be queued"
  on public.notification_queue for insert
  to anon, authenticated
  with check (true);

drop policy if exists "Supervisors can read notification queue" on public.notification_queue;
create policy "Supervisors can read notification queue"
  on public.notification_queue for select
  to authenticated
  using (true);

drop policy if exists "Supervisors can update notification queue" on public.notification_queue;
create policy "Supervisors can update notification queue"
  on public.notification_queue for update
  to authenticated
  using (true)
  with check (true);

insert into public.app_settings(key, value)
values
  ('notification_frequency', 'disabled'),
  ('notification_email', '')
on conflict (key) do nothing;

create index if not exists notification_queue_unsent_idx
  on public.notification_queue(frequency, created_at)
  where sent_at is null;
