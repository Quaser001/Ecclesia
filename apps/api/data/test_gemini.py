import os
import sys
from pathlib import Path

# Add src to sys.path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from google import genai
from google.genai import types
from src.config.settings import settings
from src.prompts.extraction import build_extraction_prompt
from src.orchestration.scan_graph import ScanOrchestrator
from src.providers.gemini_provider import GoogleGeminiProvider
from src.providers.local_db_provider import LocalDBProvider, LocalStorageProvider
import asyncio

async def test():
    print("GEMINI_API_KEY:", settings.GEMINI_API_KEY[:10] + "...")
    print("GEMINI_MODEL:", settings.GEMINI_MODEL)

    gemini = GoogleGeminiProvider()
    supabase = LocalDBProvider()
    storage = LocalStorageProvider()

    orchestrator = ScanOrchestrator(
        gemini=gemini,
        supabase=supabase,
        storage=storage,
    )

    # 1x1 valid minimal JPEG
    fake_jpeg = bytes([
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0xFF, 0xC0, 0x00, 0x0B, 0x08, 0x00, 0x01, 0x00, 0x01, 0x01, 0x01,
        0x11, 0x00, 0xFF, 0xC4, 0x00, 0x1F, 0x00, 0x00, 0x01, 0x05, 0x01, 0x01,
        0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0xFF,
        0xDA, 0x00, 0x08, 0x01, 0x01, 0x00, 0x00, 0x3F, 0x00, 0xBF, 0x00, 0xFF, 0xD9
    ])

    print("Running orchestrator test...")
    res = await orchestrator.run(
        user_id="dev-user-001",
        photo_bytes=fake_jpeg,
        mime_type="image/jpeg",
    )

    print("--- SCAN RESPONSE ---")
    print("Product Name:", res.product.product_name)
    print("Insufficient Data:", res.insufficient_data)
    print("Pipeline Message:", res.pipeline_message)
    print("Extraction Notes:", res.product.extraction_notes)
    print("Nutrition:", res.product.nutrition)
    print("Alternatives Count:", len(res.alternatives))
    for alt in res.alternatives:
        print(" Alt:", alt.type, alt.name, alt.reason)

if __name__ == "__main__":
    asyncio.run(test())
