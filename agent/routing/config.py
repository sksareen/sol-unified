"""
Configuration for the routing and classification system.
"""

from dataclasses import dataclass, field
from typing import Optional
from enum import Enum
import os
import json


class LLMBackend(Enum):
    """Supported local LLM backends."""
    OLLAMA = "ollama"
    LLAMA_CPP = "llama_cpp"
    VLLM = "vllm"
    OPENAI_COMPATIBLE = "openai_compatible"


@dataclass
class LocalLLMConfig:
    """Configuration for local LLM classifier."""

    # Backend selection
    backend: LLMBackend = LLMBackend.OLLAMA

    # Model selection - good small models for classification
    # Ollama models:
    #   - llama3.2:3b (fast, good balance)
    #   - llama3.2:1b (faster, less accurate)
    #   - phi3:mini (Microsoft, good for classification)
    #   - mistral:7b (slower but more accurate)
    #   - qwen2.5:3b (good multilingual support)
    model: str = "llama3.2:3b"

    # Connection
    base_url: str = "http://localhost:11434"
    timeout: float = 10.0

    # Generation parameters
    temperature: float = 0.1  # Low for consistent classification
    max_tokens: int = 150

    # Fallback behavior
    fallback_on_error: bool = True
    cache_responses: bool = True
    cache_ttl_seconds: int = 300

    @classmethod
    def from_env(cls) -> "LocalLLMConfig":
        """Create config from environment variables."""
        return cls(
            backend=LLMBackend(os.getenv("LOCAL_LLM_BACKEND", "ollama")),
            model=os.getenv("LOCAL_LLM_MODEL", "llama3.2:3b"),
            base_url=os.getenv("LOCAL_LLM_URL", "http://localhost:11434"),
            timeout=float(os.getenv("LOCAL_LLM_TIMEOUT", "10.0")),
            temperature=float(os.getenv("LOCAL_LLM_TEMPERATURE", "0.1")),
        )


@dataclass
class ClassifierConfig:
    """Configuration for the classification system."""

    # Ensemble strategy
    # - "rule_first": Use rules, fall back to LLM (default, most efficient)
    # - "weighted_vote": Run both and combine votes
    # - "llm_verify": Use rules, LLM verifies uncertain ones
    # - "consensus": Require agreement
    ensemble_strategy: str = "rule_first"

    # Confidence thresholds
    rule_confidence_threshold: float = 0.7  # When to trust rules alone
    classification_threshold: float = 0.5   # Minimum to route
    clarification_threshold: float = 0.3    # Below this, ask for clarification

    # Weights for voting
    rule_weight: float = 0.4
    llm_weight: float = 0.6  # LLM slightly higher for nuanced cases

    # Local LLM config
    local_llm: LocalLLMConfig = field(default_factory=LocalLLMConfig)

    # Feature flags
    enable_local_llm: bool = True
    enable_slot_extraction: bool = True
    enable_context_awareness: bool = True

    # Caching
    enable_classification_cache: bool = True
    cache_size: int = 1000
    cache_ttl_seconds: int = 300


@dataclass
class RouterConfig:
    """Configuration for the router."""

    # Routing behavior
    confidence_threshold: float = 0.5
    clarification_threshold: float = 0.3

    # Retry behavior
    max_retries: int = 2
    retry_delay_ms: int = 100

    # Fallback behavior
    use_fallback_for_unknown: bool = True
    use_fallback_for_low_confidence: bool = True

    # Logging/metrics
    enable_metrics: bool = True
    log_classifications: bool = True


@dataclass
class RoutingConfig:
    """
    Main configuration container for the entire routing system.
    """
    classifier: ClassifierConfig = field(default_factory=ClassifierConfig)
    router: RouterConfig = field(default_factory=RouterConfig)

    # Custom intents to register
    custom_intents_file: Optional[str] = None

    def save(self, path: str) -> None:
        """Save configuration to JSON file."""
        data = {
            "classifier": {
                "ensemble_strategy": self.classifier.ensemble_strategy,
                "rule_confidence_threshold": self.classifier.rule_confidence_threshold,
                "classification_threshold": self.classifier.classification_threshold,
                "clarification_threshold": self.classifier.clarification_threshold,
                "rule_weight": self.classifier.rule_weight,
                "llm_weight": self.classifier.llm_weight,
                "enable_local_llm": self.classifier.enable_local_llm,
                "enable_slot_extraction": self.classifier.enable_slot_extraction,
                "enable_context_awareness": self.classifier.enable_context_awareness,
                "local_llm": {
                    "backend": self.classifier.local_llm.backend.value,
                    "model": self.classifier.local_llm.model,
                    "base_url": self.classifier.local_llm.base_url,
                    "timeout": self.classifier.local_llm.timeout,
                    "temperature": self.classifier.local_llm.temperature,
                },
            },
            "router": {
                "confidence_threshold": self.router.confidence_threshold,
                "clarification_threshold": self.router.clarification_threshold,
                "max_retries": self.router.max_retries,
                "use_fallback_for_unknown": self.router.use_fallback_for_unknown,
            },
            "custom_intents_file": self.custom_intents_file,
        }

        with open(path, "w") as f:
            json.dump(data, f, indent=2)

    @classmethod
    def load(cls, path: str) -> "RoutingConfig":
        """Load configuration from JSON file."""
        with open(path, "r") as f:
            data = json.load(f)

        llm_data = data.get("classifier", {}).get("local_llm", {})
        local_llm_config = LocalLLMConfig(
            backend=LLMBackend(llm_data.get("backend", "ollama")),
            model=llm_data.get("model", "llama3.2:3b"),
            base_url=llm_data.get("base_url", "http://localhost:11434"),
            timeout=llm_data.get("timeout", 10.0),
            temperature=llm_data.get("temperature", 0.1),
        )

        classifier_data = data.get("classifier", {})
        classifier_config = ClassifierConfig(
            ensemble_strategy=classifier_data.get("ensemble_strategy", "rule_first"),
            rule_confidence_threshold=classifier_data.get("rule_confidence_threshold", 0.7),
            classification_threshold=classifier_data.get("classification_threshold", 0.5),
            clarification_threshold=classifier_data.get("clarification_threshold", 0.3),
            rule_weight=classifier_data.get("rule_weight", 0.4),
            llm_weight=classifier_data.get("llm_weight", 0.6),
            enable_local_llm=classifier_data.get("enable_local_llm", True),
            enable_slot_extraction=classifier_data.get("enable_slot_extraction", True),
            enable_context_awareness=classifier_data.get("enable_context_awareness", True),
            local_llm=local_llm_config,
        )

        router_data = data.get("router", {})
        router_config = RouterConfig(
            confidence_threshold=router_data.get("confidence_threshold", 0.5),
            clarification_threshold=router_data.get("clarification_threshold", 0.3),
            max_retries=router_data.get("max_retries", 2),
            use_fallback_for_unknown=router_data.get("use_fallback_for_unknown", True),
        )

        return cls(
            classifier=classifier_config,
            router=router_config,
            custom_intents_file=data.get("custom_intents_file"),
        )

    @classmethod
    def default(cls) -> "RoutingConfig":
        """Create default configuration."""
        return cls()

    @classmethod
    def for_low_latency(cls) -> "RoutingConfig":
        """
        Configuration optimized for low latency.
        Uses rules only, no LLM.
        """
        return cls(
            classifier=ClassifierConfig(
                ensemble_strategy="rule_first",
                rule_confidence_threshold=0.5,  # Trust rules more
                enable_local_llm=False,
            ),
            router=RouterConfig(
                max_retries=0,
            ),
        )

    @classmethod
    def for_accuracy(cls) -> "RoutingConfig":
        """
        Configuration optimized for accuracy.
        Always uses both classifiers.
        """
        return cls(
            classifier=ClassifierConfig(
                ensemble_strategy="weighted_vote",
                rule_confidence_threshold=0.9,
                enable_local_llm=True,
                local_llm=LocalLLMConfig(
                    model="mistral:7b",  # Larger, more accurate
                    temperature=0.05,
                ),
            ),
        )

    @classmethod
    def for_hybrid(cls) -> "RoutingConfig":
        """
        Balanced configuration using LLM verification.
        Good balance of speed and accuracy.
        """
        return cls(
            classifier=ClassifierConfig(
                ensemble_strategy="llm_verify",
                rule_confidence_threshold=0.85,
                enable_local_llm=True,
            ),
        )


# Recommended small models for local classification
RECOMMENDED_MODELS = {
    "fastest": {
        "name": "llama3.2:1b",
        "description": "Fastest option, good for simple intents",
        "ram_required": "~2GB",
    },
    "balanced": {
        "name": "llama3.2:3b",
        "description": "Good balance of speed and accuracy",
        "ram_required": "~4GB",
    },
    "accurate": {
        "name": "mistral:7b",
        "description": "More accurate, slower",
        "ram_required": "~8GB",
    },
    "multilingual": {
        "name": "qwen2.5:3b",
        "description": "Good for non-English inputs",
        "ram_required": "~4GB",
    },
    "small_accurate": {
        "name": "phi3:mini",
        "description": "Microsoft's efficient model",
        "ram_required": "~3GB",
    },
}
