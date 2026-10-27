import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import urllib.request
from google import genai
from google.genai import types
from src.config.settings import settings
from src.prompts.extraction import build_extraction_prompt

# Download a valid JPEG sample image from via.placeholder.com or httpbin
url = "https://httpbin.org/image/jpeg"
print(f"Downloading test image from {url}...")
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as response:
    image_bytes = response.read()

print(f"Downloaded {len(image_bytes)} bytes.")

client = genai.Client(api_key=settings.GEMINI_API_KEY)
prompt = build_extraction_prompt()
image_part = types.Part.from_bytes(data=image_bytes, mime_type='image/jpeg')

model_name = "gemini-3.8-flash"
print(f"Testing vision extraction with {model_name}...")

try:
    response = client.models.generate_content(
        model=model_name,
        contents=[image_part, prompt],
        config=types.GenerateContentConfig(
            response_mime_type="application/json",
            temperature=0.2,
        ),
    )
    print("\n--- EXTRACTED JSON ---")
    print(response.text)
except Exception as e:
    print("Extraction failed:", e)
