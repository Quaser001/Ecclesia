"""SupabaseStorageProvider must return a real URL string, not an un-awaited coroutine.

supabase-py's async client makes get_public_url a coroutine. Returning it
without `await` handed a coroutine object to the scan pipeline as image_url.
"""

from __future__ import annotations

from types import SimpleNamespace

from src.providers.supabase_provider import SupabaseStorageProvider


class _Bucket:
    def __init__(self):
        self.uploaded = None

    async def upload(self, path, file, file_options):
        self.uploaded = (path, file, file_options)

    async def get_public_url(self, path):
        return f"https://example.supabase.co/storage/v1/object/public/b/{path}"


async def test_upload_image_returns_a_string_url():
    bucket = _Bucket()
    provider = SupabaseStorageProvider(url="https://example.supabase.co", key="k")
    provider._client = SimpleNamespace(storage=SimpleNamespace(from_=lambda name: bucket))

    url = await provider.upload_image("b", "scans/u/1.jpg", b"img", "image/jpeg")

    assert isinstance(url, str)
    assert url.endswith("scans/u/1.jpg")
    assert bucket.uploaded[0] == "scans/u/1.jpg"
