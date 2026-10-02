-- Field workspace v1
-- Run in Supabase SQL editor after enabling email/password auth.

create extension if not exists pgcrypto;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  trade text not null default 'Instalações',
  phone text,
  created_at timestamptz not null default now()
);

create table if not exists public.clients (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  phone text,
  email text,
  address text,
  notes text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  title text not null,
  location text not null default '',
  kind text not null default 'Novo',
  status text not null default 'Rascunho',
  scheduled_at timestamptz,
  duration_minutes integer not null default 60 check (duration_minutes > 0),
  notes text not null default '',
  is_new boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.materials (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid references public.jobs(id) on delete cascade,
  name text not null,
  quantity numeric not null default 1,
  unit text not null default 'un.',
  ready boolean not null default false,
  notes text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  client_id uuid references public.clients(id) on delete set null,
  job_id uuid references public.jobs(id) on delete set null,
  title text not null,
  status text not null default 'Rascunho',
  subtotal numeric(12,2) not null default 0,
  tax numeric(12,2) not null default 0,
  total numeric(12,2) not null default 0,
  valid_until date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- One professional can connect one or more WhatsApp Business Accounts.
-- Credentials live in the non-exposed private schema; Flutter only sees the
-- connection metadata below.
create table if not exists public.whatsapp_connections (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  waba_id text not null,
  phone_number_id text not null,
  display_phone text,
  status text not null default 'connected',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(owner_id, phone_number_id)
);

create table if not exists private.whatsapp_credentials (
  connection_id uuid primary key references public.whatsapp_connections(id) on delete cascade,
  access_token_ciphertext text not null,
  updated_at timestamptz not null default now()
);

revoke all on table private.whatsapp_credentials from public, anon, authenticated;
grant usage on schema private to service_role;
grant all on table private.whatsapp_credentials to service_role;

-- AI orchestration. The Mac mini/Hermes worker consumes queued jobs and writes
-- results back; the Flutter app never talks directly to Hermes.
create table if not exists public.agent_jobs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('assistant_request', 'daily_plan', 'draft_message', 'draft_quote')),
  status text not null default 'queued' check (status in ('queued', 'running', 'succeeded', 'failed', 'cancelled')),
  input jsonb not null default '{}'::jsonb,
  result jsonb,
  error text,
  locked_by text,
  locked_at timestamptz,
  attempts integer not null default 0,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  finished_at timestamptz
);

create table if not exists public.agent_runs (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  job_id uuid references public.agent_jobs(id) on delete set null,
  runtime text not null default 'api',
  model text,
  status text not null default 'started',
  input_tokens integer not null default 0,
  output_tokens integer not null default 0,
  tool_calls integer not null default 0,
  latency_ms integer,
  created_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists public.agent_actions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  run_id uuid references public.agent_runs(id) on delete cascade,
  action_type text not null,
  payload jsonb not null default '{}'::jsonb,
  status text not null default 'proposed' check (status in ('proposed', 'approved', 'executed', 'rejected')),
  approved_at timestamptz,
  executed_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists public.agent_memories (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  kind text not null default 'preference',
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  confidence numeric(4,3) not null default 0.5 check (confidence >= 0 and confidence <= 1),
  source text not null default 'user',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.usage_events (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  event_type text not null,
  provider text,
  model text,
  units numeric,
  cost_usd numeric(12,6),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

-- Atomically claim one job. The worker uses the service role from the Mac mini;
-- the function prevents two workers from processing the same row.
create or replace function public.claim_next_agent_job(worker_name text)
returns setof public.agent_jobs
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  update public.agent_jobs as job
  set status = 'running',
      locked_by = worker_name,
      locked_at = now(),
      started_at = coalesce(started_at, now()),
      attempts = attempts + 1
  where job.id = (
    select candidate.id
    from public.agent_jobs as candidate
    where candidate.status = 'queued'
       or (candidate.status = 'running' and candidate.locked_at < now() - interval '10 minutes')
    order by candidate.created_at asc
    for update skip locked
    limit 1
  )
  returning job.*;
end;
$$;

revoke all on function public.claim_next_agent_job(text) from public, anon, authenticated;
grant execute on function public.claim_next_agent_job(text) to service_role;

create index if not exists agent_jobs_queue_idx on public.agent_jobs(status, created_at);
create index if not exists agent_jobs_owner_idx on public.agent_jobs(owner_id, created_at desc);
create index if not exists agent_runs_owner_idx on public.agent_runs(owner_id, created_at desc);
create index if not exists agent_memories_owner_idx on public.agent_memories(owner_id, updated_at desc);

create index if not exists jobs_owner_scheduled_idx on public.jobs(owner_id, scheduled_at);
create index if not exists clients_owner_name_idx on public.clients(owner_id, name);
create index if not exists materials_owner_ready_idx on public.materials(owner_id, ready);

alter table public.profiles enable row level security;
alter table public.clients enable row level security;
alter table public.jobs enable row level security;
alter table public.materials enable row level security;
alter table public.quotes enable row level security;
alter table public.whatsapp_connections enable row level security;
alter table public.agent_jobs enable row level security;
alter table public.agent_runs enable row level security;
alter table public.agent_actions enable row level security;
alter table public.agent_memories enable row level security;
alter table public.usage_events enable row level security;
alter table private.whatsapp_credentials enable row level security;

create policy "profile owner" on public.profiles for all to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()));
create policy "clients owner" on public.clients for all to authenticated
using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "jobs owner" on public.jobs for all to authenticated
using (owner_id = (select auth.uid())) with check (
  owner_id = (select auth.uid())
  and (client_id is null or exists (
    select 1 from public.clients as linked_client
    where linked_client.id = jobs.client_id
      and linked_client.owner_id = (select auth.uid())
  ))
);
create policy "materials owner" on public.materials for all to authenticated
using (owner_id = (select auth.uid())) with check (
  owner_id = (select auth.uid())
  and (job_id is null or exists (
    select 1 from public.jobs as linked_job
    where linked_job.id = materials.job_id
      and linked_job.owner_id = (select auth.uid())
  ))
);
create policy "quotes owner" on public.quotes for all to authenticated
using (owner_id = (select auth.uid())) with check (
  owner_id = (select auth.uid())
  and (client_id is null or exists (
    select 1 from public.clients as linked_client
    where linked_client.id = quotes.client_id
      and linked_client.owner_id = (select auth.uid())
  ))
  and (job_id is null or exists (
    select 1 from public.jobs as linked_job
    where linked_job.id = quotes.job_id
      and linked_job.owner_id = (select auth.uid())
  ))
);
create policy "whatsapp owner" on public.whatsapp_connections for all to authenticated
using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "agent jobs read" on public.agent_jobs for select to authenticated
using (owner_id = (select auth.uid()));
create policy "agent jobs enqueue" on public.agent_jobs for insert to authenticated
with check (owner_id = (select auth.uid()) and status = 'queued');
create policy "agent jobs cancel" on public.agent_jobs for update to authenticated
using (owner_id = (select auth.uid()) and status = 'queued')
with check (owner_id = (select auth.uid()) and status = 'cancelled');
create policy "agent runs owner" on public.agent_runs for select to authenticated
using (owner_id = (select auth.uid()));
create policy "agent actions owner" on public.agent_actions for select to authenticated
using (owner_id = (select auth.uid()));
create policy "agent memories owner" on public.agent_memories for all to authenticated
using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "usage owner" on public.usage_events for select to authenticated
using (owner_id = (select auth.uid()));

revoke all on all tables in schema public from anon;
grant select, insert, update, delete on public.profiles, public.clients, public.jobs,
  public.materials, public.quotes, public.whatsapp_connections, public.agent_memories
  to authenticated;
grant select, insert, update on public.agent_jobs to authenticated;
grant select on public.agent_runs, public.agent_actions, public.usage_events to authenticated;
