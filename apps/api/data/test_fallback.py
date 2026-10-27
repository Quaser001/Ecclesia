import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import urllib.request
from google import genai
from google.genai import types
from src.config.settings import settings
from src.prompts.extraction import build_extraction_prompt

# Download a valid JPEG sample image
url = "https://httpbin.org/image/jpeg"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as response:
    image_bytes = response.read()

client = genai.Client(api_key=settings.GEMINI_API_KEY)
prompt = build_extraction_prompt()
image_part = types.Part.from_bytes(data=image_bytes, mime_type='image/jpeg')

fallback_models = [
    "gemini-flash-latest",
    "gemini-pro-latest",
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-3-flash-preview",
]

for model_name in fallback_models:
    print(f"\nTrying model: {model_name}...")
    try:
        response = client.models.generate_content(
            model=model_name,
            contents=[image_part, prompt],
            config=types.GenerateContentConfig(
                response_mime_type="application/json",
                temperature=0.2,
            ),
        )
        print(f"🎉 SUCCESS WITH MODEL: {model_name}!")
        print("Response snippet:", (response.text or "")[:200])
        break
    except Exception as e:
        print(f"❌ Failed with {model_name}: {e}")
