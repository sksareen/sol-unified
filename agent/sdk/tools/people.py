"""
People tools for managing contacts in Sol Unified's People CRM.

Provides tools for:
- Looking up existing contacts
- Creating new contacts
- Updating existing contacts
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

CREATE_CONTACT_TOOL = {
    "name": "create_contact",
    "description": "Create a new contact in Sol Unified's People CRM. Use this to add new people you meet or research.",
    "input_schema": {
        "type": "object",
        "properties": {
            "name": {
                "type": "string",
                "description": "The person's full name (required)."
            },
            "one_liner": {
                "type": "string",
                "description": "A short description like 'CEO at Acme Corp' or 'Investor at XYZ Fund'."
            },
            "notes": {
                "type": "string",
                "description": "Notes about the person, how you met, topics discussed, etc."
            },
            "email": {
                "type": "string",
                "description": "The person's email address."
            },
            "phone": {
                "type": "string",
                "description": "The person's phone number."
            },
            "linkedin": {
                "type": "string",
                "description": "The person's LinkedIn profile URL."
            },
            "location": {
                "type": "string",
                "description": "Full location like 'San Francisco, CA, USA'."
            },
            "current_city": {
                "type": "string",
                "description": "Current city of residence."
            },
            "tags": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Tags to categorize the person, e.g. ['investor', 'tech', 'met-at-conference']."
            }
        },
        "required": ["name"]
    }
}

UPDATE_CONTACT_TOOL = {
    "name": "update_contact",
    "description": "Update an existing contact in Sol Unified's People CRM. Only provided fields will be updated.",
    "input_schema": {
        "type": "object",
        "properties": {
            "id": {
                "type": "string",
                "description": "The unique ID of the contact to update (required)."
            },
            "name": {
                "type": "string",
                "description": "Updated name for the person."
            },
            "one_liner": {
                "type": "string",
                "description": "Updated short description."
            },
            "notes": {
                "type": "string",
                "description": "Updated notes about the person."
            },
            "email": {
                "type": "string",
                "description": "Updated email address."
            },
            "phone": {
                "type": "string",
                "description": "Updated phone number."
            },
            "linkedin": {
                "type": "string",
                "description": "Updated LinkedIn profile URL."
            },
            "location": {
                "type": "string",
                "description": "Updated full location."
            },
            "current_city": {
                "type": "string",
                "description": "Updated current city."
            },
            "tags": {
                "type": "array",
                "items": {"type": "string"},
                "description": "Updated tags (replaces existing tags)."
            }
        },
        "required": ["id"]
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


async def create_contact(
    name: str,
    one_liner: str | None = None,
    notes: str | None = None,
    email: str | None = None,
    phone: str | None = None,
    linkedin: str | None = None,
    location: str | None = None,
    current_city: str | None = None,
    tags: list[str] | None = None,
) -> dict[str, Any]:
    """
    Create a new contact in the People CRM.

    Args:
        name: Person's full name (required).
        one_liner: Short description.
        notes: Notes about the person.
        email: Email address.
        phone: Phone number.
        linkedin: LinkedIn profile URL.
        location: Full location.
        current_city: Current city.
        tags: List of tags for categorization.

    Returns:
        Dictionary containing success status and person_id.
    """
    config = get_config()
    base_url = config.api.sol_unified_url

    payload: dict[str, Any] = {"name": name}
    if one_liner:
        payload["one_liner"] = one_liner
    if notes:
        payload["notes"] = notes
    if email:
        payload["email"] = email
    if phone:
        payload["phone"] = phone
    if linkedin:
        payload["linkedin"] = linkedin
    if location:
        payload["location"] = location
    if current_city:
        payload["current_city"] = current_city
    if tags:
        payload["tags"] = tags

    async with httpx.AsyncClient(timeout=config.api.timeout_seconds) as client:
        try:
            response = await client.post(f"{base_url}/people", json=payload)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            return {"error": f"HTTP error: {e.response.status_code}", "success": False}
        except httpx.ConnectError:
            return {"error": "Cannot connect to Sol Unified. Is it running?", "success": False}
        except Exception as e:
            return {"error": str(e), "success": False}


async def update_contact(
    id: str,
    name: str | None = None,
    one_liner: str | None = None,
    notes: str | None = None,
    email: str | None = None,
    phone: str | None = None,
    linkedin: str | None = None,
    location: str | None = None,
    current_city: str | None = None,
    tags: list[str] | None = None,
) -> dict[str, Any]:
    """
    Update an existing contact in the People CRM.

    Args:
        id: Person's unique ID (required).
        name: Updated name.
        one_liner: Updated short description.
        notes: Updated notes.
        email: Updated email address.
        phone: Updated phone number.
        linkedin: Updated LinkedIn profile URL.
        location: Updated full location.
        current_city: Updated current city.
        tags: Updated list of tags (replaces existing).

    Returns:
        Dictionary containing success status.
    """
    config = get_config()
    base_url = config.api.sol_unified_url

    payload: dict[str, Any] = {}
    if name is not None:
        payload["name"] = name
    if one_liner is not None:
        payload["one_liner"] = one_liner
    if notes is not None:
        payload["notes"] = notes
    if email is not None:
        payload["email"] = email
    if phone is not None:
        payload["phone"] = phone
    if linkedin is not None:
        payload["linkedin"] = linkedin
    if location is not None:
        payload["location"] = location
    if current_city is not None:
        payload["current_city"] = current_city
    if tags is not None:
        payload["tags"] = tags

    async with httpx.AsyncClient(timeout=config.api.timeout_seconds) as client:
        try:
            response = await client.put(f"{base_url}/people/{id}", json=payload)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPStatusError as e:
            if e.response.status_code == 404:
                return {"error": f"Contact with ID '{id}' not found", "success": False}
            return {"error": f"HTTP error: {e.response.status_code}", "success": False}
        except httpx.ConnectError:
            return {"error": "Cannot connect to Sol Unified. Is it running?", "success": False}
        except Exception as e:
            return {"error": str(e), "success": False}


def execute(args: dict[str, Any]) -> dict[str, Any]:
    """Synchronous wrapper for lookup_person tool execution."""
    import asyncio
    return asyncio.run(lookup_person(
        name=args["name"],
        fuzzy=args.get("fuzzy", True)
    ))


def execute_create(args: dict[str, Any]) -> dict[str, Any]:
    """Synchronous wrapper for create_contact tool execution."""
    import asyncio
    return asyncio.run(create_contact(
        name=args["name"],
        one_liner=args.get("one_liner"),
        notes=args.get("notes"),
        email=args.get("email"),
        phone=args.get("phone"),
        linkedin=args.get("linkedin"),
        location=args.get("location"),
        current_city=args.get("current_city"),
        tags=args.get("tags"),
    ))


def execute_update(args: dict[str, Any]) -> dict[str, Any]:
    """Synchronous wrapper for update_contact tool execution."""
    import asyncio
    return asyncio.run(update_contact(
        id=args["id"],
        name=args.get("name"),
        one_liner=args.get("one_liner"),
        notes=args.get("notes"),
        email=args.get("email"),
        phone=args.get("phone"),
        linkedin=args.get("linkedin"),
        location=args.get("location"),
        current_city=args.get("current_city"),
        tags=args.get("tags"),
    ))
