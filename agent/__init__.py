"""
Sol Unified AI Agent Module

This module contains the AI agent components for the Sol application,
including intent classification, routing, and task execution.
"""

from .routing import (
    Intent,
    IntentCategory,
    IntentRegistry,
    RuleBasedClassifier,
    LocalLLMClassifier,
    EnsembleClassifier,
    ClassificationResult,
    Router,
    RouteHandler,
    RoutingDecision,
    RoutingConfig,
)

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
