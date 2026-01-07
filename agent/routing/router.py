"""
Intent Router - Routes classified intents to appropriate handlers.

The router takes classification results and:
1. Routes to the appropriate handler based on intent
2. Handles fallbacks and error cases
3. Supports middleware for pre/post processing
4. Manages conversation flow and context
5. Integrates with memory system for persistent context
"""

import asyncio
from dataclasses import dataclass, field
from typing import Optional, Callable, Any, Awaitable, TYPE_CHECKING
from enum import Enum

from .intents import Intent, IntentCategory, IntentRegistry
from .classifiers import (
    ClassificationResult,
    EnsembleClassifier,
    RuleBasedClassifier,
    LocalLLMClassifier,
)

if TYPE_CHECKING:
    from .memory import MemoryManager


class RoutingOutcome(Enum):
    """Possible outcomes of a routing decision."""
    HANDLED = "handled"              # Successfully routed and handled
    CLARIFICATION_NEEDED = "clarification_needed"  # Need user clarification
    FALLBACK = "fallback"            # Routed to fallback handler
    ERROR = "error"                  # Error during routing/handling
    NO_HANDLER = "no_handler"        # No handler registered


@dataclass
class RoutingDecision:
    """
    Result of routing an intent to a handler.
    """
    outcome: RoutingOutcome
    classification: ClassificationResult
    handler_name: Optional[str] = None
    result: Any = None
    error: Optional[str] = None
    clarification_prompt: Optional[str] = None
    suggested_intents: list[Intent] = field(default_factory=list)

    # Timing/metrics
    classification_time_ms: float = 0.0
    handling_time_ms: float = 0.0

    def to_dict(self) -> dict:
        return {
            "outcome": self.outcome.value,
            "intent": self.classification.intent.name,
            "confidence": self.classification.confidence,
            "handler": self.handler_name,
            "error": self.error,
            "clarification_prompt": self.clarification_prompt,
        }


# Type alias for handler functions
HandlerFunc = Callable[
    [str, ClassificationResult, dict],
    Awaitable[Any]
]

# Type alias for middleware functions
MiddlewareFunc = Callable[
    [str, ClassificationResult, dict],
    Awaitable[Optional[ClassificationResult]]
]


@dataclass
class RouteHandler:
    """
    A registered route handler with metadata.
    """
    name: str
    handler: HandlerFunc
    intents: list[str]  # Intent names this handler responds to
    description: str = ""
    requires_slots: list[str] = field(default_factory=list)
    enabled: bool = True


class Router:
    """
    Main routing engine that connects classification to handlers.

    Features:
    - Intent-to-handler mapping
    - Confidence-based fallback
    - Slot validation
    - Middleware support
    - Clarification flow
    - Context management
    """

    def __init__(
        self,
        registry: Optional[IntentRegistry] = None,
        classifier: Optional[EnsembleClassifier] = None,
        confidence_threshold: float = 0.5,
        clarification_threshold: float = 0.3,
        memory_manager: Optional["MemoryManager"] = None,
    ):
        self.registry = registry or IntentRegistry()

        if classifier:
            self.classifier = classifier
        else:
            # Create default ensemble classifier
            rule_classifier = RuleBasedClassifier(self.registry)
            llm_classifier = LocalLLMClassifier(self.registry)
            self.classifier = EnsembleClassifier(
                self.registry,
                rule_classifier=rule_classifier,
                llm_classifier=llm_classifier,
            )

        self.confidence_threshold = confidence_threshold
        self.clarification_threshold = clarification_threshold

        # Memory system
        self.memory = memory_manager

        # Handler registry
        self._handlers: dict[str, RouteHandler] = {}
        self._intent_to_handler: dict[str, str] = {}

        # Middleware stacks
        self._pre_middleware: list[MiddlewareFunc] = []
        self._post_middleware: list[MiddlewareFunc] = []

        # Fallback handlers
        self._fallback_handler: Optional[HandlerFunc] = None
        self._error_handler: Optional[HandlerFunc] = None
        self._clarification_handler: Optional[Callable] = None

        # Context
        self._context: dict = {}

    def register_handler(
        self,
        name: str,
        handler: HandlerFunc,
        intents: list[str],
        description: str = "",
        requires_slots: list[str] = None,
    ) -> None:
        """
        Register a handler for specific intents.

        Args:
            name: Unique handler name
            handler: Async function to handle the intent
            intents: List of intent names this handler responds to
            description: Human-readable description
            requires_slots: Slots that must be extracted before handling
        """
        route_handler = RouteHandler(
            name=name,
            handler=handler,
            intents=intents,
            description=description,
            requires_slots=requires_slots or [],
        )

        self._handlers[name] = route_handler

        for intent_name in intents:
            self._intent_to_handler[intent_name] = name

    def handler(
        self,
        intents: list[str],
        description: str = "",
        requires_slots: list[str] = None,
    ):
        """
        Decorator for registering handlers.

        Usage:
            @router.handler(["greeting", "farewell"])
            async def handle_social(text, classification, context):
                ...
        """
        def decorator(func: HandlerFunc) -> HandlerFunc:
            self.register_handler(
                name=func.__name__,
                handler=func,
                intents=intents,
                description=description,
                requires_slots=requires_slots,
            )
            return func
        return decorator

    def set_fallback_handler(self, handler: HandlerFunc) -> None:
        """Set the fallback handler for unmatched/low-confidence intents."""
        self._fallback_handler = handler

    def set_error_handler(self, handler: HandlerFunc) -> None:
        """Set the error handler for handling failures."""
        self._error_handler = handler

    def set_clarification_handler(
        self,
        handler: Callable[[str, ClassificationResult, list[Intent]], Awaitable[str]]
    ) -> None:
        """Set handler for generating clarification prompts."""
        self._clarification_handler = handler

    def add_pre_middleware(self, middleware: MiddlewareFunc) -> None:
        """Add middleware that runs before classification."""
        self._pre_middleware.append(middleware)

    def add_post_middleware(self, middleware: MiddlewareFunc) -> None:
        """Add middleware that runs after classification."""
        self._post_middleware.append(middleware)

    def update_context(self, updates: dict) -> None:
        """Update the router's context."""
        self._context.update(updates)

    def get_context(self) -> dict:
        """Get current context."""
        return self._context.copy()

    async def route(
        self,
        text: str,
        context: Optional[dict] = None,
        session_id: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> RoutingDecision:
        """
        Route user input to the appropriate handler.

        This is the main entry point for the router.

        Args:
            text: User input text
            context: Optional additional context
            session_id: Session ID for memory persistence
            user_id: User ID for user-specific memory

        Returns:
            RoutingDecision with outcome and result
        """
        import time

        # Merge context
        full_context = {**self._context, **(context or {})}

        # Load memory context if available
        if self.memory and session_id:
            memory_context = await self.memory.build_context(
                session_id=session_id,
                user_id=user_id,
                include_learned=True,
            )
            full_context.update(memory_context)
            full_context["session_id"] = session_id
            full_context["user_id"] = user_id

        # Run pre-middleware
        for middleware in self._pre_middleware:
            try:
                result = await middleware(text, None, full_context)
                if result:
                    # Middleware provided classification, skip classifier
                    return await self._handle_classification(text, result, full_context, 0.0, session_id, user_id)
            except Exception as e:
                pass  # Middleware errors don't stop routing

        # Classify
        start_time = time.time()
        classification = await self.classifier.classify(text, full_context)
        classification_time = (time.time() - start_time) * 1000

        # Run post-middleware
        for middleware in self._post_middleware:
            try:
                result = await middleware(text, classification, full_context)
                if result:
                    classification = result
            except Exception:
                pass

        return await self._handle_classification(
            text, classification, full_context, classification_time, session_id, user_id
        )

    async def _handle_classification(
        self,
        text: str,
        classification: ClassificationResult,
        context: dict,
        classification_time: float,
        session_id: Optional[str] = None,
        user_id: Optional[str] = None,
    ) -> RoutingDecision:
        """Handle a classification result."""
        import time

        # Check if clarification needed
        if classification.needs_clarification or classification.confidence < self.clarification_threshold:
            return await self._handle_clarification(text, classification, context, classification_time)

        # Check confidence threshold
        if classification.confidence < self.confidence_threshold:
            return await self._handle_low_confidence(text, classification, context, classification_time)

        # Find handler
        handler_name = self._intent_to_handler.get(classification.intent.name)

        if not handler_name:
            # Try fallback
            if self._fallback_handler:
                return await self._execute_fallback(text, classification, context, classification_time)

            return RoutingDecision(
                outcome=RoutingOutcome.NO_HANDLER,
                classification=classification,
                classification_time_ms=classification_time,
            )

        # Get handler
        route_handler = self._handlers[handler_name]

        # Check required slots
        missing_slots = self._check_required_slots(classification, route_handler)
        if missing_slots:
            return await self._handle_missing_slots(
                text, classification, context, missing_slots, classification_time
            )

        # Execute handler
        start_time = time.time()
        try:
            result = await route_handler.handler(text, classification, context)
            handling_time = (time.time() - start_time) * 1000

            # Record interaction to memory
            if self.memory and session_id:
                response_text = str(result) if not isinstance(result, str) else result
                await self.memory.record_interaction(
                    session_id=session_id,
                    user_input=text,
                    assistant_response=response_text,
                    user_id=user_id,
                    extract_facts=True,
                )

            return RoutingDecision(
                outcome=RoutingOutcome.HANDLED,
                classification=classification,
                handler_name=handler_name,
                result=result,
                classification_time_ms=classification_time,
                handling_time_ms=handling_time,
            )

        except Exception as e:
            handling_time = (time.time() - start_time) * 1000

            if self._error_handler:
                try:
                    error_result = await self._error_handler(text, classification, context)
                    return RoutingDecision(
                        outcome=RoutingOutcome.ERROR,
                        classification=classification,
                        handler_name=handler_name,
                        result=error_result,
                        error=str(e),
                        classification_time_ms=classification_time,
                        handling_time_ms=handling_time,
                    )
                except Exception:
                    pass

            return RoutingDecision(
                outcome=RoutingOutcome.ERROR,
                classification=classification,
                handler_name=handler_name,
                error=str(e),
                classification_time_ms=classification_time,
                handling_time_ms=handling_time,
            )

    async def _handle_clarification(
        self,
        text: str,
        classification: ClassificationResult,
        context: dict,
        classification_time: float,
    ) -> RoutingDecision:
        """Handle case where clarification is needed."""

        # Get potential intents to suggest
        suggested = []
        if classification.alternative_intents:
            suggested = [intent for intent, _ in classification.alternative_intents[:3]]
        if classification.intent.category != IntentCategory.AMBIGUOUS:
            suggested.insert(0, classification.intent)

        # Generate clarification prompt
        prompt = None
        if self._clarification_handler:
            try:
                prompt = await self._clarification_handler(text, classification, suggested)
            except Exception:
                pass

        if not prompt:
            # Default clarification prompt
            if suggested:
                options = ", ".join(f"'{i.name}'" for i in suggested[:3])
                prompt = f"I'm not sure what you mean. Did you want to: {options}?"
            else:
                prompt = "Could you please clarify what you'd like me to do?"

        return RoutingDecision(
            outcome=RoutingOutcome.CLARIFICATION_NEEDED,
            classification=classification,
            clarification_prompt=prompt,
            suggested_intents=suggested,
            classification_time_ms=classification_time,
        )

    async def _handle_low_confidence(
        self,
        text: str,
        classification: ClassificationResult,
        context: dict,
        classification_time: float,
    ) -> RoutingDecision:
        """Handle low confidence classification."""

        # If we have a fallback, use it
        if self._fallback_handler:
            return await self._execute_fallback(text, classification, context, classification_time)

        # Otherwise, ask for clarification
        return await self._handle_clarification(text, classification, context, classification_time)

    async def _execute_fallback(
        self,
        text: str,
        classification: ClassificationResult,
        context: dict,
        classification_time: float,
    ) -> RoutingDecision:
        """Execute the fallback handler."""
        import time

        start_time = time.time()
        try:
            result = await self._fallback_handler(text, classification, context)
            handling_time = (time.time() - start_time) * 1000

            return RoutingDecision(
                outcome=RoutingOutcome.FALLBACK,
                classification=classification,
                handler_name="fallback",
                result=result,
                classification_time_ms=classification_time,
                handling_time_ms=handling_time,
            )

        except Exception as e:
            return RoutingDecision(
                outcome=RoutingOutcome.ERROR,
                classification=classification,
                error=str(e),
                classification_time_ms=classification_time,
            )

    def _check_required_slots(
        self,
        classification: ClassificationResult,
        handler: RouteHandler,
    ) -> list[str]:
        """Check if required slots are present."""
        missing = []
        for slot in handler.requires_slots:
            if slot not in classification.extracted_slots:
                missing.append(slot)
        return missing

    async def _handle_missing_slots(
        self,
        text: str,
        classification: ClassificationResult,
        context: dict,
        missing_slots: list[str],
        classification_time: float,
    ) -> RoutingDecision:
        """Handle case where required slots are missing."""

        # Generate prompt for missing slots
        slot_prompts = {
            "path": "What file or path should I use?",
            "time": "What time?",
            "date": "What date?",
            "command": "What command should I run?",
            "message": "What message?",
            "temperature": "What temperature?",
            "room": "Which room?",
        }

        prompts = [slot_prompts.get(s, f"Please provide: {s}") for s in missing_slots]
        prompt = " ".join(prompts)

        return RoutingDecision(
            outcome=RoutingOutcome.CLARIFICATION_NEEDED,
            classification=classification,
            clarification_prompt=prompt,
            classification_time_ms=classification_time,
        )

    # Convenience methods for common patterns

    async def route_with_retry(
        self,
        text: str,
        context: Optional[dict] = None,
        max_retries: int = 2,
    ) -> RoutingDecision:
        """
        Route with automatic retry on error.
        """
        last_result = None
        for attempt in range(max_retries + 1):
            result = await self.route(text, context)
            last_result = result

            if result.outcome != RoutingOutcome.ERROR:
                return result

            # Add retry info to context
            context = context or {}
            context["retry_attempt"] = attempt + 1

        return last_result

    def get_registered_handlers(self) -> list[dict]:
        """Get info about all registered handlers."""
        return [
            {
                "name": h.name,
                "intents": h.intents,
                "description": h.description,
                "requires_slots": h.requires_slots,
                "enabled": h.enabled,
            }
            for h in self._handlers.values()
        ]

    def get_coverage_report(self) -> dict:
        """Get a report of intent coverage by handlers."""
        all_intents = self.registry.all_intents()
        covered = set(self._intent_to_handler.keys())
        uncovered = [i.name for i in all_intents if i.name not in covered]

        return {
            "total_intents": len(all_intents),
            "covered_intents": len(covered),
            "uncovered_intents": uncovered,
            "coverage_percentage": len(covered) / len(all_intents) * 100 if all_intents else 0,
        }
