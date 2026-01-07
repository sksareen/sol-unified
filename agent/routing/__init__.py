"""
Hybrid Intent Classification and Routing System

This module provides a robust intent classification system that combines:
1. Rule-based classification (fast, deterministic)
2. Local LLM classification (contextual, handles edge cases)
3. Ensemble voting for improved accuracy
4. Memory system (session, user, and learned memory)

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
from .memory import (
    MemoryManager,
    SessionMemory,
    UserMemory,
    LearnedMemory,
    MemoryEntry,
    MemoryType,
    Message,
    MemoryStore,
    SQLiteMemoryStore,
)

__all__ = [
    # Intents
    "Intent",
    "IntentCategory",
    "IntentRegistry",
    # Classifiers
    "RuleBasedClassifier",
    "LocalLLMClassifier",
    "EnsembleClassifier",
    "ClassificationResult",
    # Router
    "Router",
    "RouteHandler",
    "RoutingDecision",
    # Config
    "RoutingConfig",
    # Memory
    "MemoryManager",
    "SessionMemory",
    "UserMemory",
    "LearnedMemory",
    "MemoryEntry",
    "MemoryType",
    "Message",
    "MemoryStore",
    "SQLiteMemoryStore",
]
