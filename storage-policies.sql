-- LaoBirds photo storage policies
-- First create a PRIVATE bucket named: bird-photos
-- Recommended bucket limit for this first version: 6 MB per file, images only.

-- Upload only into a top-level folder named with the authenticated user's id.
create policy "laobirds_bird_photos_insert_own"
on storage.objects
for insert
to authenticated
with check (
    bucket_id = 'bird-photos'
    and (storage.foldername(name))[1] = (select auth.uid()::text)
);

-- Read only the user's own stored photos for now.
create policy "laobirds_bird_photos_select_own"
on storage.objects
for select
to authenticated
using (
    bucket_id = 'bird-photos'
    and owner_id = (select auth.uid()::text)
);

-- Allow the owner to delete their own photos.
create policy "laobirds_bird_photos_delete_own"
on storage.objects
for delete
to authenticated
using (
    bucket_id = 'bird-photos'
    and owner_id = (select auth.uid()::text)
);

-- Allow the owner to update their own photos when needed later.
create policy "laobirds_bird_photos_update_own"
on storage.objects
for update
to authenticated
using (
    bucket_id = 'bird-photos'
    and owner_id = (select auth.uid()::text)
)
with check (
    bucket_id = 'bird-photos'
    and owner_id = (select auth.uid()::text)
);
