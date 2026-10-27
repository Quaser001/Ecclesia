import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from google import genai
from google.genai import types
from src.config.settings import settings
import urllib.request

url = "https://httpbin.org/image/jpeg"
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
with urllib.request.urlopen(req) as response:
    image_bytes = response.read()

client = genai.Client(api_key=settings.GEMINI_API_KEY)
image_part = types.Part.from_bytes(data=image_bytes, mime_type='image/jpeg')

models_to_test = [
    "gemini-3.1-flash-lite",
    "gemini-2.5-flash-lite",
    "gemini-3-flash-preview",
    "gemini-flash-lite-latest",
]

for m in models_to_test:
    print(f"Testing {m}...")
    try:
        res = client.models.generate_content(
            model=m,
            contents=[image_part, "What is this image?"],
        )
        print(f"✅ SUCCESS with {m}:", res.text[:100])
        break
    except Exception as e:
        print(f"❌ Failed {m}:", e)
