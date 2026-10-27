import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from src.providers.local_db_provider import LocalDBProvider
import asyncio

async def check():
    db = LocalDBProvider()
    profile = await db.get_profile("dev-user-001")
    print("--- PROFILE FOR dev-user-001 IN SQLITE ---")
    if profile:
        print("User ID:", profile.user_id)
        print("Name:", profile.name)
        print("Health Conditions:", [c.value for c in profile.health_conditions])
        print("Allergies:", profile.allergies)
        print("Dietary Preferences:", [d.value for d in profile.dietary_preferences])
        print("Health Goals:", [g.value for g in profile.health_goals])
    else:
        print("No profile found for dev-user-001!")

if __name__ == "__main__":
    asyncio.run(check())
