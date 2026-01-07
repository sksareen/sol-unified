"""
Hybrid Intent Classification and Routing System

This module provides a robust intent classification system that combines:
1. Rule-based classification (fast, deterministic)
2. Local LLM classification (contextual, handles edge cases)
3. Ensemble voting for improved accuracy

The system is designed to route user requests to appropriate handlers
while minimizing API calls and maximizing accuracy.
"""

from .intents import Intent, IntentCategory, IntentRegistry
from .classifiers import (
    RuleBasedClassifier,
    LocalLLMClassifier,
    EnsembleClassifier,
    ClassificationResult,
)
from .router import Router, RouteHandler, RoutingDecision
from .config import RoutingConfig

__all__ = [
    "Intent",
    "IntentCategory",
    "IntentRegistry",
    "RuleBasedClassifier",
    "LocalLLMClassifier",
    "EnsembleClassifier",
    "ClassificationResult",
    "Router",
    "RouteHandler",
    "RoutingDecision",
    "RoutingConfig",
]
