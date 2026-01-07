# Hybrid Intent Classification and Routing System

A robust intent classification system that combines rule-based classification with local LLM support for improved accuracy.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      User Input                              │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Ensemble Classifier                        │
│  ┌─────────────────────┐   ┌─────────────────────────────┐  │
│  │  Rule-Based         │   │  Local LLM                  │  │
│  │  Classifier         │   │  Classifier                 │  │
│  │  • Keywords         │   │  • Ollama/llama.cpp         │  │
│  │  • Regex patterns   │   │  • Contextual understanding │  │
│  │  • Fast & cheap     │   │  • Edge case handling       │  │
│  └──────────┬──────────┘   └──────────────┬──────────────┘  │
│             │                              │                 │
│             └──────────┬───────────────────┘                 │
│                        ▼                                     │
│              Ensemble Strategy                               │
│    (rule_first | weighted_vote | llm_verify | consensus)    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                        Router                                │
│  • Intent → Handler mapping                                  │
│  • Confidence-based routing                                  │
│  • Slot validation                                           │
│  • Fallback handling                                         │
│  • Clarification flow                                        │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Intent Handlers                           │
└─────────────────────────────────────────────────────────────┘
```

## Why Hybrid Classification?

| Approach | Pros | Cons |
|----------|------|------|
| **Rules Only** | Fast, deterministic, no dependencies | Brittle, misses edge cases |
| **LLM Only** | Handles nuance, contextual | Slower, costs compute |
| **Hybrid** | Best of both worlds | Slightly more complex |

The hybrid approach:
- Uses fast rules for obvious cases (>90% of requests)
- Falls back to local LLM for uncertain cases
- Can verify rule classifications with LLM for extra confidence
- Works even if LLM is unavailable

## Quick Start

```python
import asyncio
from routing import Router, IntentRegistry, EnsembleClassifier

async def main():
    # Create router with default settings
    registry = IntentRegistry()
    router = Router(registry=registry)

    # Register a handler
    @router.handler(intents=["greeting"])
    async def handle_greeting(text, classification, context):
        return "Hello! How can I help?"

    # Route user input
    result = await router.route("Hi there!")
    print(result.result)  # "Hello! How can I help?"

asyncio.run(main())
```

## Configuration

### Ensemble Strategies

```python
from routing import EnsembleClassifier, RoutingConfig

# Rule-first (default): Fast, uses LLM only when uncertain
config = RoutingConfig.default()

# Weighted vote: Always uses both, combines results
config = RoutingConfig.for_accuracy()

# LLM verify: Rules first, LLM verifies uncertain ones
config = RoutingConfig.for_hybrid()

# Low latency: Rules only, no LLM
config = RoutingConfig.for_low_latency()
```

### Local LLM Setup

The system supports multiple backends:

**Ollama (recommended):**
```bash
# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Pull a small, fast model
ollama pull llama3.2:3b

# Or even smaller for faster classification
ollama pull llama3.2:1b
```

**Recommended models:**
| Model | Size | Use Case |
|-------|------|----------|
| `llama3.2:1b` | ~1GB | Fastest, simple intents |
| `llama3.2:3b` | ~3GB | Balanced (default) |
| `phi3:mini` | ~2GB | Efficient, good accuracy |
| `mistral:7b` | ~7GB | Most accurate, slower |

## API Reference

### IntentRegistry

```python
registry = IntentRegistry()

# Register custom intent
registry.register(Intent(
    category=IntentCategory.CODE_WRITE,
    name="database_query",
    description="Write database queries",
    keywords=["sql", "query", "database", "select"],
    patterns=[r"\b(sql|query|select)\b.*\b(from|database)\b"],
    examples=["Write a SQL query to get all users"],
))
```

### Router

```python
router = Router(registry, classifier, confidence_threshold=0.5)

# Register handler via decorator
@router.handler(intents=["greeting", "farewell"])
async def handle_social(text, classification, context):
    ...

# Or manually
router.register_handler(
    name="social_handler",
    handler=handle_social,
    intents=["greeting", "farewell"],
)

# Set fallback for unknown intents
router.set_fallback_handler(my_fallback)

# Route input
result = await router.route("Hello!")
```

### ClassificationResult

```python
result = await classifier.classify("Turn on the lights")

result.intent           # Intent object
result.confidence       # 0.0 - 1.0
result.extracted_slots  # {"room": "living room"}
result.reasoning        # LLM explanation (if used)
result.is_confident     # confidence >= 0.7
result.needs_clarification  # confidence < 0.5
```

## Built-in Intents

The system comes with common intents pre-configured:

- **Social**: greeting, farewell, gratitude, small_talk
- **Code**: code_generate, code_debug, code_review, code_refactor
- **Files**: file_create, file_read, file_delete
- **Questions**: factual_question, explanation_request
- **Productivity**: create_reminder, calendar_query
- **Home**: lights_control, thermostat_control
- **Control**: cancel_action, undo_action, help_request

## Running the Example

```bash
# Install dependencies
pip install httpx

# Run classification demo
python example.py

# Interactive mode
python example.py interactive

# Check if local LLM is available
python example.py check
```

## Testing

```bash
pip install pytest pytest-asyncio
pytest tests/
```
