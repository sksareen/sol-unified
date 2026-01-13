"""
People tool for looking up contacts in Sol Unified's People CRM.
"""

from typing import Any
import httpx

from ..config import get_config


PEOPLE_TOOL = {
    "name": "lookup_person",
    "description": "Look up a person in Sol Unified's People CRM by name. Returns their information, organization, notes, and relationship context. Use this before researching someone externally.",
    "input_schema": {
        "type": "object",
        "properties": {
            "name": {
                "type": "string",
                "description": "The person's name to look up."
            },
            "fuzzy": {
                "type": "boolean",
                "description": "Allow fuzzy/partial matching on name. Default true.",
                "default": True
            }
        },
        "required": ["name"]
    }
}


async def lookup_person(name: str, fuzzy: bool = True) -> dict[str, Any]:
    """
    Look up a person in the People CRM.

    Args:
        name: Person's name to search for.
        fuzzy: Allow fuzzy matching.

    Returns:
        Dictionary containing person details or empty results.
    """
    config = get_config()
    base_url = config.api.sol_unified_url

    params = {"q": name}
    if fuzzy:
        params["fuzzy"] = "true"

    async with httpx.AsyncClient(timeout=config.api.timeout_seconds) as client:
        try:
            response = await client.get(f"{base_url}/people/search", params=params)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return {"found": False, "people": [], "message": f"No person found matching '{name}'"}
            return {"error": f"HTTP error: {e.response.status_code}", "people": []}
        except httpx.ConnectError:
            return {"error": "Cannot connect to Sol Unified. Is it running?", "people": []}
        except Exception as e:
            return {"error": str(e), "people": []}


def execute(args: dict[str, Any]) -> dict[str, Any]:
    """Synchronous wrapper for tool execution."""
    import asyncio
    return asyncio.run(lookup_person(
        name=args["name"],
        fuzzy=args.get("fuzzy", True)
    ))
