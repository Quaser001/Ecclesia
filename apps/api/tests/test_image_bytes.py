"""Photo type from the bytes, and no GPS position kept in a JPEG [M, AT]."""

from __future__ import annotations

import struct

import pytest

from src.services.image_bytes import _read_orientation, sniff_image_type, strip_jpeg_location


def _exif(orientation: int, with_gps: bool = True) -> bytes:
    """An APP1 EXIF block with Orientation and a GPS IFD holding a latitude."""
    entries = [struct.pack("<HHIHH", 0x0112, 3, 1, orientation, 0)]
    if with_gps:
        entries.append(struct.pack("<HHII", 0x8825, 4, 1, 26))  # GPS IFD pointer
    ifd0 = struct.pack("<H", len(entries)) + b"".join(entries) + struct.pack("<I", 0)
    gps = struct.pack("<H", 1) + struct.pack("<HHII", 0x0002, 5, 3, 0) + struct.pack("<I", 0)
    tiff = b"II*\x00" + struct.pack("<I", 8) + ifd0 + gps + b"LAT=12.9716N"
    body = b"Exif\x00\x00" + tiff
    return b"\xff\xe1" + struct.pack(">H", len(body) + 2) + body


def _jpeg(*segments: bytes) -> bytes:
    app0 = b"\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00"
    dqt = b"\xff\xdb\x00\x05\x00\x01\x02"
    sos = b"\xff\xda\x00\x04\x00\x00" + b"PIXELS\xff\x00DATA" + b"\xff\xd9"
    return b"\xff\xd8" + app0 + b"".join(segments) + dqt + sos


@pytest.mark.parametrize("data,kind", [
    (b"\xff\xd8\xff\xe0rest", "image/jpeg"),
    (b"\x89PNG\r\n\x1a\nrest", "image/png"),
    (b"RIFF\x00\x00\x00\x00WEBPVP8 ", "image/webp"),
    (b"\x00\x00\x00\x18ftypheic\x00\x00", "image/heic"),
    (b"MZ\x90\x00", None),
    (b"<html>", None),
    (b"", None),
])
def test_sniff(data, kind):
    assert sniff_image_type(data) == kind


def test_gps_is_removed_and_orientation_kept():
    original = _jpeg(_exif(6))
    cleaned = strip_jpeg_location(original)
    assert b"LAT=12.9716N" in original and b"LAT=12.9716N" not in cleaned
    assert b"PIXELS\xff\x00DATA\xff\xd9" in cleaned  # the image itself is untouched
    app1 = cleaned.index(b"\xff\xe1")
    assert _read_orientation(cleaned[app1 + 10:]) == 6
    assert sniff_image_type(cleaned) == "image/jpeg"


def test_upright_photo_keeps_no_exif_at_all():
    cleaned = strip_jpeg_location(_jpeg(_exif(1)))
    assert b"\xff\xe1" not in cleaned.split(b"\xff\xda")[0]


def test_xmp_and_iptc_blocks_are_removed_too():
    def segment(marker, payload):
        return bytes([0xFF, marker]) + struct.pack(">H", len(payload) + 2) + payload
    xmp = segment(0xE1, b"http://ns.adobe.com/xap/1.0/\x00<x:xmpmeta/>")
    iptc = segment(0xED, b"Photoshop 3.0\x00IPTC")
    cleaned = strip_jpeg_location(_jpeg(xmp, iptc))
    assert b"http://ns" not in cleaned and b"IPTC" not in cleaned


@pytest.mark.parametrize("damaged", [b"\xff\xd8\xff\xe0\x00", b"\xff\xd8garbage", b"not a jpeg"])
def test_damaged_files_are_returned_unchanged(damaged):
    assert strip_jpeg_location(damaged) == damaged
