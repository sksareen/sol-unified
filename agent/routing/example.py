#!/usr/bin/env python3
"""
Example usage of the hybrid routing and intent classification system.

This example demonstrates:
1. Setting up the router with ensemble classification
2. Registering handlers for different intents
3. Using the local LLM as a backstop for better accuracy
4. Handling clarification and fallback cases

Prerequisites:
    pip install httpx

For local LLM support (optional but recommended):
    # Install Ollama: https://ollama.ai
    ollama pull llama3.2:3b
"""

import asyncio
from typing import Any

from intents import IntentRegistry, Intent, IntentCategory
from classifiers import (
    RuleBasedClassifier,
    LocalLLMClassifier,
    EnsembleClassifier,
    ClassificationResult,
)
from router import Router, RoutingDecision, RoutingOutcome
from config import RoutingConfig, LocalLLMConfig, LLMBackend


async def setup_router() -> Router:
    """Set up the router with handlers."""

    # Create registry with default intents
    registry = IntentRegistry()

    # Optionally add custom intents
    registry.register(Intent(
        category=IntentCategory.CODE_WRITE,
        name="api_endpoint",
        description="Create a new API endpoint",
        keywords=["api", "endpoint", "route", "rest"],
        patterns=[r"\b(create|add|make)\b.*\b(api|endpoint|route)\b"],
        examples=[
            "Create an API endpoint for user login",
            "Add a REST endpoint for fetching products",
        ],
        handler_name="handle_api_creation",
        priority=30,
    ))

    # Create classifiers
    rule_classifier = RuleBasedClassifier(registry)

    # Configure local LLM (Ollama with small model)
    llm_config = LocalLLMConfig(
        backend=LLMBackend.OLLAMA,
        model="llama3.2:3b",  # Small, fast model
        base_url="http://localhost:11434",
        timeout=10.0,
        temperature=0.1,
    )

    llm_classifier = LocalLLMClassifier(
        registry,
        backend=llm_config.backend.value,
        model=llm_config.model,
        base_url=llm_config.base_url,
        timeout=llm_config.timeout,
        temperature=llm_config.temperature,
    )

    # Create ensemble classifier
    # Uses rule_first strategy: fast rules for obvious cases, LLM for uncertain ones
    ensemble = EnsembleClassifier(
        registry,
        rule_classifier=rule_classifier,
        llm_classifier=llm_classifier,
        strategy=EnsembleClassifier.Strategy.RULE_FIRST,
        rule_confidence_threshold=0.7,
    )

    # Create router
    router = Router(
        registry=registry,
        classifier=ensemble,
        confidence_threshold=0.5,
        clarification_threshold=0.3,
    )

    # Register handlers
    register_handlers(router)

    return router


def register_handlers(router: Router) -> None:
    """Register all intent handlers."""

    # Greeting handler
    @router.handler(intents=["greeting"], description="Handle greetings")
    async def handle_greeting(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> str:
        return "Hello! How can I help you today?"

    # Farewell handler
    @router.handler(intents=["farewell"], description="Handle goodbyes")
    async def handle_farewell(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> str:
        return "Goodbye! Have a great day!"

    # Code generation handler
    @router.handler(
        intents=["code_generate", "api_endpoint"],
        description="Generate code"
    )
    async def handle_code_generate(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> dict:
        return {
            "action": "generate_code",
            "intent": classification.intent.name,
            "confidence": classification.confidence,
            "slots": classification.extracted_slots,
            "message": f"I'll help you generate code. Detected intent: {classification.intent.name}",
        }

    # Code debug handler
    @router.handler(intents=["code_debug"], description="Debug code")
    async def handle_code_debug(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> dict:
        return {
            "action": "debug_code",
            "message": "Let me help you debug that issue.",
            "reasoning": classification.reasoning,
        }

    # File operations handler
    @router.handler(
        intents=["file_create", "file_read", "file_delete"],
        description="Handle file operations",
        requires_slots=["path"],
    )
    async def handle_file_ops(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> dict:
        path = classification.extracted_slots.get("path", "unknown")
        return {
            "action": classification.intent.name,
            "path": path,
            "message": f"Performing {classification.intent.name} on {path}",
        }

    # Search handler
    @router.handler(intents=["web_search"], description="Handle search queries")
    async def handle_search(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> dict:
        return {
            "action": "search",
            "query": text,
            "message": f"Searching for: {text}",
        }

    # Explanation handler
    @router.handler(
        intents=["explanation_request", "factual_question"],
        description="Handle questions and explanations"
    )
    async def handle_explanation(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> dict:
        return {
            "action": "explain",
            "question": text,
            "message": "Let me explain that for you...",
        }

    # Help handler
    @router.handler(intents=["help_request"], description="Handle help requests")
    async def handle_help(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> str:
        return """Available commands:
- Ask questions or request explanations
- Generate or debug code
- File operations (create, read, delete)
- Web search
- Set reminders
- Calendar queries
- And more!"""

    # Home automation
    @router.handler(
        intents=["lights_control", "thermostat_control"],
        description="Handle home automation"
    )
    async def handle_home(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> dict:
        return {
            "action": "home_automation",
            "device": classification.intent.name.replace("_control", ""),
            "slots": classification.extracted_slots,
        }

    # Fallback handler for unknown intents
    async def fallback_handler(
        text: str,
        classification: ClassificationResult,
        context: dict,
    ) -> dict:
        return {
            "action": "fallback",
            "message": f"I'm not sure how to handle that. Classification: {classification.intent.name} ({classification.confidence:.2f})",
            "suggestion": "Could you rephrase or be more specific?",
        }

    router.set_fallback_handler(fallback_handler)


async def demo_classification():
    """Demonstrate the classification system."""
    print("=" * 60)
    print("Hybrid Intent Classification Demo")
    print("=" * 60)

    router = await setup_router()

    # Test inputs
    test_inputs = [
        # Clear intents (rules should handle)
        "Hello!",
        "Goodbye, see you later",
        "Thanks for your help",

        # Code intents
        "Write a function to validate email addresses",
        "Debug this authentication error in my code",
        "Create an API endpoint for user registration",

        # File operations
        "Create a new file called config.yaml",
        "Show me the contents of package.json",

        # Questions
        "What is a closure in JavaScript?",
        "Explain how async/await works",

        # Ambiguous (LLM should help)
        "Can you help me with that thing we discussed?",
        "Do the thing",
        "Make it better",

        # Home automation
        "Turn on the living room lights",
        "Set the temperature to 72 degrees",

        # Edge cases
        "I need to fix the login but also add a new feature",
    ]

    print("\n")

    for text in test_inputs:
        print(f"Input: \"{text}\"")
        print("-" * 40)

        result = await router.route(text)

        print(f"  Intent: {result.classification.intent.name}")
        print(f"  Category: {result.classification.intent.category.name}")
        print(f"  Confidence: {result.classification.confidence:.2f}")
        print(f"  Classifier: {', '.join(result.classification.contributing_classifiers) or result.classification.classifier_type.value}")
        print(f"  Outcome: {result.outcome.value}")

        if result.classification.extracted_slots:
            print(f"  Slots: {result.classification.extracted_slots}")

        if result.classification.reasoning:
            print(f"  Reasoning: {result.classification.reasoning}")

        if result.outcome == RoutingOutcome.HANDLED:
            print(f"  Handler: {result.handler_name}")
            print(f"  Result: {result.result}")
        elif result.outcome == RoutingOutcome.CLARIFICATION_NEEDED:
            print(f"  Clarification: {result.clarification_prompt}")

        print(f"  Time: {result.classification_time_ms:.1f}ms classification, {result.handling_time_ms:.1f}ms handling")
        print("\n")


async def demo_interactive():
    """Interactive demo."""
    print("=" * 60)
    print("Interactive Intent Classification")
    print("=" * 60)
    print("Type your messages (Ctrl+C to exit)\n")

    router = await setup_router()

    while True:
        try:
            text = input("You: ").strip()
            if not text:
                continue

            result = await router.route(text)

            print(f"\n[{result.classification.intent.name}] (confidence: {result.classification.confidence:.2f})")

            if result.outcome == RoutingOutcome.HANDLED:
                if isinstance(result.result, str):
                    print(f"Assistant: {result.result}")
                else:
                    print(f"Response: {result.result}")
            elif result.outcome == RoutingOutcome.CLARIFICATION_NEEDED:
                print(f"Assistant: {result.clarification_prompt}")
            elif result.outcome == RoutingOutcome.FALLBACK:
                print(f"Assistant: {result.result.get('message', 'Unknown')}")
            else:
                print(f"Outcome: {result.outcome.value}")

            print()

        except KeyboardInterrupt:
            print("\n\nGoodbye!")
            break
        except Exception as e:
            print(f"Error: {e}\n")


async def demo_llm_check():
    """Check if local LLM is available."""
    print("=" * 60)
    print("Local LLM Availability Check")
    print("=" * 60)

    registry = IntentRegistry()
    llm = LocalLLMClassifier(registry)

    available = await llm.is_available()

    if available:
        print("Local LLM is available!")
        print(f"  Backend: {llm.backend}")
        print(f"  Model: {llm.model}")
        print(f"  URL: {llm.base_url}")

        # Test classification
        result = await llm.classify("Hello, how are you?")
        print(f"\nTest classification:")
        print(f"  Intent: {result.intent.name}")
        print(f"  Confidence: {result.confidence:.2f}")
        print(f"  Reasoning: {result.reasoning}")
    else:
        print("Local LLM is NOT available.")
        print("\nTo enable local LLM support:")
        print("  1. Install Ollama: https://ollama.ai")
        print("  2. Pull a model: ollama pull llama3.2:3b")
        print("  3. Start Ollama: ollama serve")
        print("\nThe system will still work using rule-based classification only.")


async def main():
    """Main entry point."""
    import sys

    if len(sys.argv) > 1:
        mode = sys.argv[1]
        if mode == "interactive":
            await demo_interactive()
        elif mode == "check":
            await demo_llm_check()
        else:
            print(f"Unknown mode: {mode}")
            print("Usage: python example.py [interactive|check]")
    else:
        await demo_classification()


if __name__ == "__main__":
    asyncio.run(main())
