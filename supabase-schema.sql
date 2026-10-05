
-- LaoBirds multi-user database foundation
-- Run this in Supabase SQL Editor.
-- No API keys or secrets are included in this file.

create extension if not exists pgcrypto;

-- =========================================================
-- PROFILES
-- One row per authenticated LaoBirds user.
-- =========================================================

create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text,
    country text,
    province text,
    bio text,
    avatar_path text,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Users can read their own profile.
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (id = auth.uid());

-- Users can create their own profile.
create policy "profiles_insert_own"
on public.profiles
for insert
to authenticated
with check (id = auth.uid());

-- Users can update their own profile.
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (id = auth.uid())
with check (id = auth.uid());


-- =========================================================
-- LOCATIONS
-- Reusable birding / survey locations.
-- =========================================================

create table if not exists public.locations (
    id uuid primary key default gen_random_uuid(),
    created_by uuid not null references auth.users(id) on delete cascade,
    name text not null,
    country text,
    province text,
    district text,
    latitude double precision,
    longitude double precision,
    accuracy_m double precision,
    notes text,
    created_at timestamptz not null default now()
);

create index if not exists locations_created_by_idx
on public.locations(created_by);

create index if not exists locations_lat_lon_idx
on public.locations(latitude, longitude);

alter table public.locations enable row level security;

create policy "locations_select_own"
on public.locations
for select
to authenticated
using (created_by = auth.uid());

create policy "locations_insert_own"
on public.locations
for insert
to authenticated
with check (created_by = auth.uid());

create policy "locations_update_own"
on public.locations
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

create policy "locations_delete_own"
on public.locations
for delete
to authenticated
using (created_by = auth.uid());


-- =========================================================
-- CHECKLISTS
-- One row = one complete field visit / birding checklist.
-- =========================================================

create table if not exists public.checklists (
    id uuid primary key default gen_random_uuid(),
    created_by uuid not null references auth.users(id) on delete cascade,
    location_id uuid references public.locations(id) on delete set null,

    location_name text not null,

    country text,
    province text,
    district text,

    latitude double precision,
    longitude double precision,
    accuracy_m double precision,

    observation_date date not null,
    start_time time,
    end_time time,

    survey_type text not null default 'opportunistic'
        check (survey_type in ('traveling', 'stationary', 'opportunistic')),

    complete boolean not null default false,

    visibility text not null default 'public'
        check (visibility in ('public', 'private')),

    notes text,

    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists checklists_created_by_idx
on public.checklists(created_by);

create index if not exists checklists_date_idx
on public.checklists(observation_date);

create index if not exists checklists_location_idx
on public.checklists(location_id);

alter table public.checklists enable row level security;

-- Owner can always read own checklist.
create policy "checklists_select_own"
on public.checklists
for select
to authenticated
using (
    created_by = auth.uid()
    or visibility = 'public'
);

create policy "checklists_insert_own"
on public.checklists
for insert
to authenticated
with check (created_by = auth.uid());

create policy "checklists_update_own"
on public.checklists
for update
to authenticated
using (created_by = auth.uid())
with check (created_by = auth.uid());

create policy "checklists_delete_own"
on public.checklists
for delete
to authenticated
using (created_by = auth.uid());


-- =========================================================
-- CHECKLIST OBSERVATIONS
-- One row = one bird species recorded inside one checklist.
--
-- species_id must match the ID used by LaoBirds data.js.
-- Example: 001, LB-001, etc.
-- =========================================================

create table if not exists public.checklist_observations (
    id uuid primary key default gen_random_uuid(),
    checklist_id uuid not null references public.checklists(id) on delete cascade,

    species_id text not null,

    count integer not null default 1
        check (count >= 1),

    notes text,

    created_at timestamptz not null default now()
);

create index if not exists checklist_observations_checklist_idx
on public.checklist_observations(checklist_id);

create index if not exists checklist_observations_species_idx
on public.checklist_observations(species_id);

alter table public.checklist_observations enable row level security;

-- A user can read observations if they own the checklist
-- or the checklist is public.
create policy "checklist_observations_select"
on public.checklist_observations
for select
to authenticated
using (
    exists (
        select 1
        from public.checklists c
        where c.id = checklist_id
        and (
            c.created_by = auth.uid()
            or c.visibility = 'public'
        )
    )
);

create policy "checklist_observations_insert"
on public.checklist_observations
for insert
to authenticated
with check (
    exists (
        select 1
        from public.checklists c
        where c.id = checklist_id
        and c.created_by = auth.uid()
    )
);

create policy "checklist_observations_update"
on public.checklist_observations
for update
to authenticated
using (
    exists (
        select 1
        from public.checklists c
        where c.id = checklist_id
        and c.created_by = auth.uid()
    )
)
with check (
    exists (
        select 1
        from public.checklists c
        where c.id = checklist_id
        and c.created_by = auth.uid()
    )
);

create policy "checklist_observations_delete"
on public.checklist_observations
for delete
to authenticated
using (
    exists (
        select 1
        from public.checklists c
        where c.id = checklist_id
        and c.created_by = auth.uid()
    )
);


-- =========================================================
-- PHOTOS
-- Metadata for photos uploaded to Supabase Storage.
-- The actual image file will live in Storage.
-- =========================================================

create table if not exists public.photos (
    id uuid primary key default gen_random_uuid(),

    uploaded_by uuid not null references auth.users(id) on delete cascade,

    checklist_id uuid references public.checklists(id) on delete cascade,

    checklist_observation_id uuid
        references public.checklist_observations(id)
        on delete cascade,

    storage_path text not null,

    caption text,

    created_at timestamptz not null default now()
);

create index if not exists photos_uploaded_by_idx
on public.photos(uploaded_by);

create index if not exists photos_checklist_idx
on public.photos(checklist_id);

create index if not exists photos_observation_idx
on public.photos(checklist_observation_id);

alter table public.photos enable row level security;

create policy "photos_select"
on public.photos
for select
to authenticated
using (
    uploaded_by = auth.uid()
    or exists (
        select 1
        from public.checklists c
        where c.id = checklist_id
        and c.visibility = 'public'
    )
);

create policy "photos_insert_own"
on public.photos
for insert
to authenticated
with check (uploaded_by = auth.uid());

create policy "photos_update_own"
on public.photos
for update
to authenticated
using (uploaded_by = auth.uid())
with check (uploaded_by = auth.uid());

create policy "photos_delete_own"
on public.photos
for delete
to authenticated
using (uploaded_by = auth.uid());


-- =========================================================
-- AUTO-CREATE PROFILE WHEN A USER REGISTERS
-- =========================================================

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
    insert into public.profiles (id, display_name)
    values (
        new.id,
        coalesce(
            new.raw_user_meta_data ->> 'display_name',
            split_part(new.email, '@', 1)
        )
    );

    return new;
end;
$$;

drop trigger if exists on_auth_user_created
on auth.users;

create trigger on_auth_user_created
after insert on auth.users
for each row
execute procedure public.handle_new_user();


-- =========================================================
-- UPDATED_AT HELPER
-- =========================================================

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_updated_at
on public.profiles;

create trigger profiles_updated_at
before update on public.profiles
for each row
execute procedure public.set_updated_at();

drop trigger if exists checklists_updated_at
on public.checklists;

create trigger checklists_updated_at
before update on public.checklists
for each row
execute procedure public.set_updated_at();
