"""The client's address, from the entries our own proxies added.

Behind Cloud Run the socket peer is Google's front end, the same address for
every phone, so a per-IP cap keyed on it would lock out every new install
after the first few. The front end appends the address it saw to
X-Forwarded-For. Anything to the left of that came from the client and can
be forged, so only the last `trusted_hops` entries count.
"""

from __future__ import annotations

from typing import Any


def client_ip(request: Any, trusted_hops: int) -> str:
    peer = request.client.host if request.client else ""
    if trusted_hops <= 0:
        return peer
    entries = [e.strip() for e in request.headers.get("x-forwarded-for", "").split(",")]
    entries = [e for e in entries if e]
    if len(entries) < trusted_hops:
        return peer  # not behind the proxies we were told about
    return entries[-trusted_hops]
