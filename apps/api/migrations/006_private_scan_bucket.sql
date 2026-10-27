-- Migration 006 — private storage bucket for scan photos
-- Applied to the live project as migration `006_private_scan_bucket`.

-- No storage.objects policies are added, so only the backend's service_role
-- key can read or write; anon and authenticated clients get nothing. Limits
-- mirror the API's own checks (MAX_SCAN_UPLOAD_BYTES and the accepted types).
--
-- Note: SupabaseStorageProvider stores get_public_url() in scans.image_url.
-- For a private bucket that link does not open. The app does not display it
-- today; serve signed URLs before showing scan photos anywhere.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'calfit-scans',
  'calfit-scans',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif']
)
on conflict (id) do nothing;
