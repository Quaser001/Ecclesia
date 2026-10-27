import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from google import genai
from src.config.settings import settings

client = genai.Client(api_key=settings.GEMINI_API_KEY)

try:
    models = list(client.models.list())
    print(f"Found {len(models)} models:")
    for m in models:
        print(" -", m.name, getattr(m, 'display_name', ''))
except Exception as e:
    print("Error listing models:", e)
