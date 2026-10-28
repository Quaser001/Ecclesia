# Architect: scan-pipeline

Confirmed by the founder on 2026-10-28. `apps/api/src/orchestration/scan_graph.py`.

- Every node is wrapped by `observability.timed` and records stage timings in the scan trace.
- The conditional entry point (`route_entry`) lets `run_with_product` skip photo reading.
- Only scans with a real result are saved. Insufficient or pending scans (retake/confirm/choose) are not saved, and their photos are never uploaded.
- **Known weakness:** the model fallback chain lists models that may be retired or missing in a given region. A failure just moves to the next model, but costs latency.
