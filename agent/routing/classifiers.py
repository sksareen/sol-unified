"""
Intent classifiers: rule-based, local LLM, and ensemble.

This module provides multiple classification strategies that can be
combined for improved accuracy.
"""

import re
import json
import asyncio
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Optional, Any
from enum import Enum

from .intents import Intent, IntentCategory, IntentRegistry


class ClassifierType(Enum):
    """Types of classifiers."""
    RULE_BASED = "rule_based"
    LOCAL_LLM = "local_llm"
    ENSEMBLE = "ensemble"


@dataclass
class ClassificationResult:
    """
    Result of intent classification with confidence and metadata.
    """
    intent: Intent
    confidence: float  # 0.0 to 1.0
    classifier_type: ClassifierType

    # Additional metadata
    raw_scores: dict[str, float] = field(default_factory=dict)
    extracted_slots: dict[str, Any] = field(default_factory=dict)
    reasoning: Optional[str] = None
    alternative_intents: list[tuple[Intent, float]] = field(default_factory=list)

    # For ensemble tracking
    contributing_classifiers: list[str] = field(default_factory=list)
    agreement_score: float = 1.0  # How much classifiers agreed

    @property
    def is_confident(self) -> bool:
        """Check if classification confidence is above threshold."""
        return self.confidence >= 0.7

    @property
    def needs_clarification(self) -> bool:
        """Check if we should ask for clarification."""
        return self.confidence < 0.5 or self.intent.category == IntentCategory.AMBIGUOUS

    def to_dict(self) -> dict:
        """Convert to dictionary for serialization."""
        return {
            "intent_name": self.intent.name,
            "intent_category": self.intent.category.name,
            "confidence": self.confidence,
            "classifier_type": self.classifier_type.value,
            "extracted_slots": self.extracted_slots,
            "reasoning": self.reasoning,
            "alternatives": [
                {"name": i.name, "confidence": c}
                for i, c in self.alternative_intents
            ],
        }


class BaseClassifier(ABC):
    """Abstract base class for intent classifiers."""

    def __init__(self, registry: IntentRegistry):
        self.registry = registry

    @abstractmethod
    async def classify(self, text: str, context: Optional[dict] = None) -> ClassificationResult:
        """
        Classify the intent of the given text.

        Args:
            text: User input text
            context: Optional context (conversation history, user profile, etc.)

        Returns:
            ClassificationResult with intent and confidence
        """
        pass

    @abstractmethod
    def get_classifier_type(self) -> ClassifierType:
        """Return the type of this classifier."""
        pass


class RuleBasedClassifier(BaseClassifier):
    """
    Fast rule-based classifier using keywords and regex patterns.

    This classifier is deterministic and fast, making it ideal for
    common/obvious intents. It uses:
    - Keyword matching with scoring
    - Regex pattern matching
    - Negative pattern filtering
    """

    def __init__(self, registry: IntentRegistry):
        super().__init__(registry)
        self._compile_patterns()

    def _compile_patterns(self) -> None:
        """Pre-compile regex patterns for all intents."""
        self._compiled_patterns: dict[str, list[re.Pattern]] = {}

        for intent in self.registry.all_intents():
            self._compiled_patterns[intent.name] = [
                re.compile(p, re.IGNORECASE)
                for p in intent.patterns
            ]

    def get_classifier_type(self) -> ClassifierType:
        return ClassifierType.RULE_BASED

    async def classify(self, text: str, context: Optional[dict] = None) -> ClassificationResult:
        """
        Classify using rules, keywords, and patterns.
        """
        text_lower = text.lower().strip()
        scores: dict[str, float] = {}

        for intent in self.registry.all_intents():
            score = self._score_intent(text_lower, text, intent)
            if score > 0:
                scores[intent.name] = score

        if not scores:
            unknown = self.registry.get("unknown")
            return ClassificationResult(
                intent=unknown,
                confidence=0.0,
                classifier_type=self.get_classifier_type(),
                raw_scores={},
            )

        # Get top intent
        sorted_scores = sorted(scores.items(), key=lambda x: x[1], reverse=True)
        top_name, top_score = sorted_scores[0]
        top_intent = self.registry.get(top_name)

        # Calculate confidence (normalize and apply priority boost)
        max_possible = 100.0  # Rough max score
        confidence = min(top_score / max_possible, 1.0)

        # Boost confidence if there's a clear winner
        if len(sorted_scores) > 1:
            second_score = sorted_scores[1][1]
            if top_score > second_score * 2:
                confidence = min(confidence * 1.2, 1.0)

        # Get alternatives
        alternatives = [
            (self.registry.get(name), score / max_possible)
            for name, score in sorted_scores[1:4]
        ]

        # Extract slots if possible
        slots = self._extract_slots(text, top_intent)

        return ClassificationResult(
            intent=top_intent,
            confidence=confidence,
            classifier_type=self.get_classifier_type(),
            raw_scores=scores,
            extracted_slots=slots,
            alternative_intents=alternatives,
        )

    def _score_intent(self, text_lower: str, text_original: str, intent: Intent) -> float:
        """
        Score how well text matches an intent.

        Scoring:
        - Keyword match: 10 points each
        - Pattern match: 25 points each
        - Priority bonus: intent.priority points
        """
        score = 0.0

        # Keyword matching
        for keyword in intent.keywords:
            if keyword.lower() in text_lower:
                score += 10.0
                # Bonus for keyword at start
                if text_lower.startswith(keyword.lower()):
                    score += 5.0

        # Pattern matching
        patterns = self._compiled_patterns.get(intent.name, [])
        for pattern in patterns:
            if pattern.search(text_original):
                score += 25.0
                break  # Only count pattern once

        # Priority bonus
        if score > 0:
            score += intent.priority

        return score

    def _extract_slots(self, text: str, intent: Intent) -> dict[str, Any]:
        """Extract slot values from text based on intent requirements."""
        slots = {}

        # Basic slot extraction patterns
        slot_patterns = {
            "path": r'["\']?([\/\w\.\-\_]+\.\w+)["\']?|["\']?([\/\w\.\-\_]+\/)["\']?',
            "time": r'\b(\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\b|\b(at\s+\d{1,2}(?::\d{2})?)\b',
            "date": r'\b(today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
            "temperature": r'\b(\d{1,3})\s*(?:degrees?|°)?\b',
            "room": r'\b(living\s*room|bedroom|kitchen|bathroom|office|garage)\b',
        }

        all_slots = intent.required_slots + intent.optional_slots
        for slot in all_slots:
            if slot in slot_patterns:
                match = re.search(slot_patterns[slot], text, re.IGNORECASE)
                if match:
                    # Get first non-None group
                    value = next((g for g in match.groups() if g), None)
                    if value:
                        slots[slot] = value.strip()

        return slots


class LocalLLMClassifier(BaseClassifier):
    """
    Classifier using a local LLM (Ollama, llama.cpp, etc.)

    This classifier uses a small local model for more nuanced
    classification, especially for:
    - Edge cases that don't match rules well
    - Context-dependent classification
    - Ambiguous inputs needing reasoning

    Supported backends:
    - Ollama (recommended for ease of use)
    - llama.cpp server
    - vLLM
    - Any OpenAI-compatible API
    """

    def __init__(
        self,
        registry: IntentRegistry,
        backend: str = "ollama",
        model: str = "llama3.2:3b",  # Small, fast model
        base_url: str = "http://localhost:11434",
        timeout: float = 10.0,
        temperature: float = 0.1,  # Low temp for consistent classification
    ):
        super().__init__(registry)
        self.backend = backend
        self.model = model
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.temperature = temperature
        self._available: Optional[bool] = None

    def get_classifier_type(self) -> ClassifierType:
        return ClassifierType.LOCAL_LLM

    async def is_available(self) -> bool:
        """Check if the local LLM backend is available."""
        if self._available is not None:
            return self._available

        try:
            import httpx
            async with httpx.AsyncClient(timeout=2.0) as client:
                if self.backend == "ollama":
                    resp = await client.get(f"{self.base_url}/api/tags")
                    self._available = resp.status_code == 200
                else:
                    # OpenAI-compatible endpoint
                    resp = await client.get(f"{self.base_url}/v1/models")
                    self._available = resp.status_code == 200
        except Exception:
            self._available = False

        return self._available

    async def classify(self, text: str, context: Optional[dict] = None) -> ClassificationResult:
        """
        Classify using local LLM.
        """
        if not await self.is_available():
            # Return low-confidence unknown if LLM unavailable
            return ClassificationResult(
                intent=self.registry.get("unknown"),
                confidence=0.0,
                classifier_type=self.get_classifier_type(),
                reasoning="Local LLM not available",
            )

        try:
            prompt = self._build_classification_prompt(text, context)
            response = await self._query_llm(prompt)
            return self._parse_llm_response(response, text)
        except Exception as e:
            return ClassificationResult(
                intent=self.registry.get("unknown"),
                confidence=0.0,
                classifier_type=self.get_classifier_type(),
                reasoning=f"LLM error: {str(e)}",
            )

    def _build_classification_prompt(self, text: str, context: Optional[dict]) -> str:
        """Build the classification prompt for the LLM."""

        # Build intent list with examples
        intent_descriptions = []
        for intent in self.registry.all_intents():
            if intent.category in (IntentCategory.UNKNOWN, IntentCategory.AMBIGUOUS):
                continue

            examples_str = ""
            if intent.examples:
                examples_str = f" Examples: {', '.join(intent.examples[:2])}"

            intent_descriptions.append(
                f"- {intent.name}: {intent.description}.{examples_str}"
            )

        intents_list = "\n".join(intent_descriptions)

        context_str = ""
        if context:
            if "conversation_history" in context:
                recent = context["conversation_history"][-3:]
                context_str = f"\nRecent conversation:\n" + "\n".join(
                    f"- {msg}" for msg in recent
                )

        prompt = f"""You are an intent classifier. Classify the user's intent into exactly one of these categories:

{intents_list}

If none fit well, use "unknown".
If the intent is unclear and could be multiple things, use "ambiguous".
{context_str}
User input: "{text}"

Respond with ONLY a JSON object in this exact format:
{{"intent": "intent_name", "confidence": 0.0-1.0, "reasoning": "brief explanation", "slots": {{}}}}

JSON response:"""

        return prompt

    async def _query_llm(self, prompt: str) -> str:
        """Query the local LLM backend."""
        import httpx

        async with httpx.AsyncClient(timeout=self.timeout) as client:
            if self.backend == "ollama":
                resp = await client.post(
                    f"{self.base_url}/api/generate",
                    json={
                        "model": self.model,
                        "prompt": prompt,
                        "stream": False,
                        "options": {
                            "temperature": self.temperature,
                            "num_predict": 150,
                        }
                    }
                )
                data = resp.json()
                return data.get("response", "")
            else:
                # OpenAI-compatible endpoint
                resp = await client.post(
                    f"{self.base_url}/v1/completions",
                    json={
                        "model": self.model,
                        "prompt": prompt,
                        "max_tokens": 150,
                        "temperature": self.temperature,
                    }
                )
                data = resp.json()
                return data["choices"][0]["text"]

    def _parse_llm_response(self, response: str, original_text: str) -> ClassificationResult:
        """Parse the LLM's JSON response."""
        try:
            # Try to extract JSON from response
            response = response.strip()

            # Handle common LLM response quirks
            if response.startswith("```"):
                response = response.split("```")[1]
                if response.startswith("json"):
                    response = response[4:]

            # Find JSON object
            start = response.find("{")
            end = response.rfind("}") + 1
            if start >= 0 and end > start:
                json_str = response[start:end]
                data = json.loads(json_str)
            else:
                raise ValueError("No JSON found in response")

            intent_name = data.get("intent", "unknown")
            intent = self.registry.get(intent_name) or self.registry.get("unknown")

            confidence = float(data.get("confidence", 0.5))
            confidence = max(0.0, min(1.0, confidence))

            return ClassificationResult(
                intent=intent,
                confidence=confidence,
                classifier_type=self.get_classifier_type(),
                extracted_slots=data.get("slots", {}),
                reasoning=data.get("reasoning"),
            )

        except (json.JSONDecodeError, ValueError, KeyError) as e:
            # Fallback: try to extract intent name from response
            response_lower = response.lower()
            for intent in self.registry.all_intents():
                if intent.name in response_lower:
                    return ClassificationResult(
                        intent=intent,
                        confidence=0.4,  # Lower confidence for fallback parsing
                        classifier_type=self.get_classifier_type(),
                        reasoning=f"Parsed from non-JSON response: {response[:100]}",
                    )

            return ClassificationResult(
                intent=self.registry.get("unknown"),
                confidence=0.0,
                classifier_type=self.get_classifier_type(),
                reasoning=f"Failed to parse LLM response: {str(e)}",
            )


class EnsembleClassifier(BaseClassifier):
    """
    Ensemble classifier combining multiple classification strategies.

    This classifier uses both rule-based and LLM classification,
    combining them using configurable strategies:

    - weighted_vote: Weight each classifier's vote by confidence
    - rule_first: Use rules, fall back to LLM if uncertain
    - llm_verify: Use rules, use LLM to verify low-confidence results
    - consensus: Require agreement between classifiers

    The ensemble approach helps because:
    - Rules catch obvious cases quickly and cheaply
    - LLM handles nuanced/edge cases
    - Combined, they're more accurate than either alone
    """

    class Strategy(Enum):
        WEIGHTED_VOTE = "weighted_vote"
        RULE_FIRST = "rule_first"
        LLM_VERIFY = "llm_verify"
        CONSENSUS = "consensus"

    def __init__(
        self,
        registry: IntentRegistry,
        rule_classifier: Optional[RuleBasedClassifier] = None,
        llm_classifier: Optional[LocalLLMClassifier] = None,
        strategy: Strategy = Strategy.RULE_FIRST,
        rule_confidence_threshold: float = 0.7,
        llm_weight: float = 0.6,  # LLM gets slightly more weight when voting
        rule_weight: float = 0.4,
    ):
        super().__init__(registry)

        self.rule_classifier = rule_classifier or RuleBasedClassifier(registry)
        self.llm_classifier = llm_classifier or LocalLLMClassifier(registry)

        self.strategy = strategy
        self.rule_confidence_threshold = rule_confidence_threshold
        self.llm_weight = llm_weight
        self.rule_weight = rule_weight

    def get_classifier_type(self) -> ClassifierType:
        return ClassifierType.ENSEMBLE

    async def classify(self, text: str, context: Optional[dict] = None) -> ClassificationResult:
        """
        Classify using ensemble strategy.
        """
        if self.strategy == self.Strategy.WEIGHTED_VOTE:
            return await self._weighted_vote(text, context)
        elif self.strategy == self.Strategy.RULE_FIRST:
            return await self._rule_first(text, context)
        elif self.strategy == self.Strategy.LLM_VERIFY:
            return await self._llm_verify(text, context)
        elif self.strategy == self.Strategy.CONSENSUS:
            return await self._consensus(text, context)
        else:
            return await self._rule_first(text, context)

    async def _rule_first(self, text: str, context: Optional[dict]) -> ClassificationResult:
        """
        Use rule-based first, fall back to LLM if uncertain.

        This is the default and most efficient strategy:
        - Fast for obvious cases
        - Only uses LLM when needed
        """
        rule_result = await self.rule_classifier.classify(text, context)

        # If rules are confident, use them
        if rule_result.confidence >= self.rule_confidence_threshold:
            result = ClassificationResult(
                intent=rule_result.intent,
                confidence=rule_result.confidence,
                classifier_type=ClassifierType.ENSEMBLE,
                raw_scores=rule_result.raw_scores,
                extracted_slots=rule_result.extracted_slots,
                contributing_classifiers=["rule_based"],
                agreement_score=1.0,
            )
            return result

        # Otherwise, consult LLM
        llm_result = await self.llm_classifier.classify(text, context)

        # If LLM also has low confidence, return the better of the two
        if llm_result.confidence < 0.3:
            better = rule_result if rule_result.confidence >= llm_result.confidence else llm_result
            return ClassificationResult(
                intent=better.intent,
                confidence=better.confidence,
                classifier_type=ClassifierType.ENSEMBLE,
                extracted_slots=better.extracted_slots,
                reasoning=llm_result.reasoning,
                contributing_classifiers=["rule_based", "local_llm"],
                agreement_score=1.0 if rule_result.intent == llm_result.intent else 0.5,
            )

        # Combine insights
        slots = {**rule_result.extracted_slots, **llm_result.extracted_slots}

        return ClassificationResult(
            intent=llm_result.intent,
            confidence=llm_result.confidence,
            classifier_type=ClassifierType.ENSEMBLE,
            extracted_slots=slots,
            reasoning=llm_result.reasoning,
            contributing_classifiers=["rule_based", "local_llm"],
            agreement_score=1.0 if rule_result.intent == llm_result.intent else 0.5,
            alternative_intents=[(rule_result.intent, rule_result.confidence)]
                if rule_result.intent != llm_result.intent else [],
        )

    async def _weighted_vote(self, text: str, context: Optional[dict]) -> ClassificationResult:
        """
        Run both classifiers and combine with weighted voting.
        """
        # Run both in parallel
        rule_result, llm_result = await asyncio.gather(
            self.rule_classifier.classify(text, context),
            self.llm_classifier.classify(text, context),
        )

        # Collect votes
        votes: dict[str, float] = {}

        # Rule vote
        rule_vote = rule_result.confidence * self.rule_weight
        votes[rule_result.intent.name] = votes.get(rule_result.intent.name, 0) + rule_vote

        # LLM vote (if available)
        if llm_result.confidence > 0:
            llm_vote = llm_result.confidence * self.llm_weight
            votes[llm_result.intent.name] = votes.get(llm_result.intent.name, 0) + llm_vote

        # Find winner
        sorted_votes = sorted(votes.items(), key=lambda x: x[1], reverse=True)
        winner_name, winner_score = sorted_votes[0]
        winner_intent = self.registry.get(winner_name)

        # Calculate agreement
        agreement = 1.0 if rule_result.intent == llm_result.intent else 0.0

        # Combined confidence
        combined_confidence = winner_score / (self.rule_weight + self.llm_weight)

        # Merge slots
        slots = {**rule_result.extracted_slots, **llm_result.extracted_slots}

        return ClassificationResult(
            intent=winner_intent,
            confidence=combined_confidence,
            classifier_type=ClassifierType.ENSEMBLE,
            raw_scores=votes,
            extracted_slots=slots,
            reasoning=llm_result.reasoning,
            contributing_classifiers=["rule_based", "local_llm"],
            agreement_score=agreement,
            alternative_intents=[(self.registry.get(n), s) for n, s in sorted_votes[1:3]],
        )

    async def _llm_verify(self, text: str, context: Optional[dict]) -> ClassificationResult:
        """
        Use rules, but have LLM verify uncertain classifications.

        Good for reducing LLM calls while catching rule errors.
        """
        rule_result = await self.rule_classifier.classify(text, context)

        # High confidence - trust rules
        if rule_result.confidence >= 0.85:
            return ClassificationResult(
                intent=rule_result.intent,
                confidence=rule_result.confidence,
                classifier_type=ClassifierType.ENSEMBLE,
                raw_scores=rule_result.raw_scores,
                extracted_slots=rule_result.extracted_slots,
                contributing_classifiers=["rule_based"],
                agreement_score=1.0,
            )

        # Low confidence - get LLM opinion
        llm_result = await self.llm_classifier.classify(text, context)

        # If they agree, boost confidence
        if rule_result.intent == llm_result.intent:
            combined_confidence = min(
                (rule_result.confidence + llm_result.confidence) / 1.5,
                1.0
            )
            return ClassificationResult(
                intent=rule_result.intent,
                confidence=combined_confidence,
                classifier_type=ClassifierType.ENSEMBLE,
                extracted_slots={**rule_result.extracted_slots, **llm_result.extracted_slots},
                reasoning=f"Verified by LLM: {llm_result.reasoning}",
                contributing_classifiers=["rule_based", "local_llm"],
                agreement_score=1.0,
            )

        # Disagreement - trust LLM if confident
        if llm_result.confidence > rule_result.confidence:
            return ClassificationResult(
                intent=llm_result.intent,
                confidence=llm_result.confidence * 0.9,  # Slight penalty for disagreement
                classifier_type=ClassifierType.ENSEMBLE,
                extracted_slots=llm_result.extracted_slots,
                reasoning=f"LLM override: {llm_result.reasoning}",
                contributing_classifiers=["rule_based", "local_llm"],
                agreement_score=0.0,
                alternative_intents=[(rule_result.intent, rule_result.confidence)],
            )

        # Trust rules if more confident
        return ClassificationResult(
            intent=rule_result.intent,
            confidence=rule_result.confidence * 0.9,
            classifier_type=ClassifierType.ENSEMBLE,
            extracted_slots=rule_result.extracted_slots,
            reasoning=f"Rules preferred (LLM suggested: {llm_result.intent.name})",
            contributing_classifiers=["rule_based", "local_llm"],
            agreement_score=0.0,
            alternative_intents=[(llm_result.intent, llm_result.confidence)],
        )

    async def _consensus(self, text: str, context: Optional[dict]) -> ClassificationResult:
        """
        Require consensus between classifiers.

        If classifiers disagree, mark as ambiguous.
        """
        rule_result, llm_result = await asyncio.gather(
            self.rule_classifier.classify(text, context),
            self.llm_classifier.classify(text, context),
        )

        # Check for consensus
        if rule_result.intent == llm_result.intent:
            # Full agreement - high confidence
            combined_confidence = (rule_result.confidence + llm_result.confidence) / 2
            return ClassificationResult(
                intent=rule_result.intent,
                confidence=combined_confidence,
                classifier_type=ClassifierType.ENSEMBLE,
                extracted_slots={**rule_result.extracted_slots, **llm_result.extracted_slots},
                reasoning=f"Consensus: {llm_result.reasoning}",
                contributing_classifiers=["rule_based", "local_llm"],
                agreement_score=1.0,
            )

        # No consensus - mark as ambiguous if both are uncertain
        if rule_result.confidence < 0.6 and llm_result.confidence < 0.6:
            return ClassificationResult(
                intent=self.registry.get("ambiguous"),
                confidence=0.3,
                classifier_type=ClassifierType.ENSEMBLE,
                reasoning=f"No consensus: rules say {rule_result.intent.name}, LLM says {llm_result.intent.name}",
                contributing_classifiers=["rule_based", "local_llm"],
                agreement_score=0.0,
                alternative_intents=[
                    (rule_result.intent, rule_result.confidence),
                    (llm_result.intent, llm_result.confidence),
                ],
            )

        # One is confident - use that one but note disagreement
        confident = rule_result if rule_result.confidence > llm_result.confidence else llm_result
        other = llm_result if confident == rule_result else rule_result

        return ClassificationResult(
            intent=confident.intent,
            confidence=confident.confidence * 0.8,  # Reduce for lack of consensus
            classifier_type=ClassifierType.ENSEMBLE,
            extracted_slots=confident.extracted_slots,
            reasoning=f"No consensus (other classifier suggested: {other.intent.name})",
            contributing_classifiers=["rule_based", "local_llm"],
            agreement_score=0.0,
            alternative_intents=[(other.intent, other.confidence)],
        )
