"""What an uploaded photo really is, and removing where it was taken.

The declared Content-Type is whatever the client says. The first bytes are
what the file is: anything that isn't a JPEG, PNG, WebP or HEIC is refused
before it reaches Gemini or the bucket.

Phone cameras write the GPS position into a JPEG's EXIF block, and the app's
resize keeps it. The privacy policy says we don't collect precise location, so
the EXIF block is replaced by one holding only the orientation (without it a
portrait photo would show sideways). No image library needed: the JPEG is
copied segment by segment and the pixels are never decoded.
"""

from __future__ import annotations

import struct

_HEIF_BRANDS = {b"heic", b"heix", b"hevc", b"hevx", b"heim", b"heis", b"mif1", b"msf1"}


def sniff_image_type(data: bytes) -> str | None:
    """The MIME type from the file's own signature, or None if it isn't one we accept."""
    if data[:3] == b"\xff\xd8\xff":
        return "image/jpeg"
    if data[:8] == b"\x89PNG\r\n\x1a\n":
        return "image/png"
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    if data[4:8] == b"ftyp" and data[8:12] in _HEIF_BRANDS:
        return "image/heic"
    return None


_APP1 = 0xE1  # EXIF (GPS, camera, time) and XMP
_APP13 = 0xED  # Photoshop / IPTC (can hold a location too)
_SOS = 0xDA  # start of scan: compressed pixels follow until the end
_STANDALONE = {0x01, *range(0xD0, 0xD8)}  # markers without a length field
_ORIENTATION_TAG = 0x0112


def strip_jpeg_location(data: bytes) -> bytes:
    """The JPEG without its EXIF/XMP/IPTC blocks, keeping only the orientation.

    Anything that doesn't parse as a JPEG is returned unchanged; the caller has
    already checked the signature, and a damaged file is Gemini's to reject.
    """
    if data[:2] != b"\xff\xd8":
        return data
    out = [data[:2]]
    orientation: int | None = None
    i = 2
    while i + 4 <= len(data):
        if data[i] != 0xFF:
            return data  # not where a marker should be: leave the file alone
        marker = data[i + 1]
        if marker == 0xFF:  # fill byte
            i += 1
            continue
        if marker in _STANDALONE:
            out.append(data[i:i + 2])
            i += 2
            continue
        (length,) = struct.unpack(">H", data[i + 2:i + 4])
        end = i + 2 + length
        if length < 2 or end > len(data):
            return data
        segment = data[i:end]
        if marker == _APP1 and segment[4:10] == b"Exif\x00\x00":
            orientation = orientation or _read_orientation(segment[10:])
        elif marker not in (_APP1, _APP13):
            out.append(segment)
        if marker == _SOS:
            out.append(data[end:])
            break
        i = end
    else:
        return data  # never reached the pixels: not a JPEG we understand
    if orientation and orientation != 1:
        out.insert(1, _orientation_only_exif(orientation))
    return b"".join(out)


def _read_orientation(tiff: bytes) -> int | None:
    """The Orientation value from IFD0 of an EXIF TIFF block, if present."""
    if tiff[:2] == b"II":
        endian = "<"
    elif tiff[:2] == b"MM":
        endian = ">"
    else:
        return None
    try:
        (ifd,) = struct.unpack(endian + "I", tiff[4:8])
        (count,) = struct.unpack(endian + "H", tiff[ifd:ifd + 2])
        for n in range(count):
            entry = tiff[ifd + 2 + 12 * n: ifd + 14 + 12 * n]
            tag, kind = struct.unpack(endian + "HH", entry[:4])
            if tag == _ORIENTATION_TAG and kind == 3:  # SHORT
                (value,) = struct.unpack(endian + "H", entry[8:10])
                return value if 1 <= value <= 8 else None
    except struct.error:
        return None
    return None


def _orientation_only_exif(orientation: int) -> bytes:
    """An APP1 EXIF segment holding the orientation and nothing else."""
    tiff = (b"II*\x00" + struct.pack("<I", 8)  # little-endian, IFD0 at offset 8
            + struct.pack("<H", 1)  # one entry
            + struct.pack("<HHIHH", _ORIENTATION_TAG, 3, 1, orientation, 0)
            + struct.pack("<I", 0))  # no next IFD
    body = b"Exif\x00\x00" + tiff
    return b"\xff\xe1" + struct.pack(">H", len(body) + 2) + body
