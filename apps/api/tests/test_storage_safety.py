"""Local image storage must never write outside its uploads directory."""

from __future__ import annotations

import pytest

from src.providers.local_db_provider import LocalStorageProvider


@pytest.fixture
def storage(tmp_path):
    return LocalStorageProvider(base_dir=str(tmp_path / "uploads"))


async def test_normal_upload_lands_inside_base_dir(storage, tmp_path):
    url = await storage.upload_image("bucket", "scans/abc/1.jpg", b"img", "image/jpeg")
    assert url == "/uploads/bucket/scans/abc/1.jpg"
    assert (tmp_path / "uploads" / "bucket" / "scans" / "abc" / "1.jpg").read_bytes() == b"img"


@pytest.mark.parametrize(
    "path",
    [
        "scans/../../escape.jpg",
        "../escape.jpg",
        "scans/../../../escape.jpg",
        "/abs/escape.jpg",
    ],
)
async def test_traversal_paths_are_refused(storage, tmp_path, path):
    with pytest.raises(ValueError):
        await storage.upload_image("bucket", path, b"x", "image/jpeg")
    assert not (tmp_path / "escape.jpg").exists()
    assert not list(tmp_path.glob("**/escape.jpg"))


async def test_traversal_via_bucket_is_refused(storage, tmp_path):
    with pytest.raises(ValueError):
        await storage.upload_image("../outside", "a.jpg", b"x", "image/jpeg")
    assert not (tmp_path / "outside").exists()


async def test_scan_node_survives_hostile_user_id(storage, tmp_path):
    """The graph node swallows storage errors; a hostile id must yield no URL and no file."""
    from src.orchestration.scan_graph import ScanState, node_upload_image

    state = ScanState(user_id="../../../pwn", photo_bytes=b"x", mime_type="image/jpeg")
    out = await node_upload_image(state, storage, "bucket")
    assert out == {"image_url": None}
    assert not list(tmp_path.glob("**/pwn*"))
