"""
Sol Unified AI Agent Module

This module contains the AI agent components for the Sol application,
including intent classification, routing, and task execution.
"""

# Lazy import routing to avoid breaking the sdk submodule
# if routing has syntax errors
try:
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
except (ImportError, SyntaxError) as e:
    # Routing module has issues, but sdk can still work
    __all__ = []
