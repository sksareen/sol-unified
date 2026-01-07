"""
Intent definitions and registry for the classification system.
"""

from dataclasses import dataclass, field
from enum import Enum, auto
from typing import Optional, Callable, Any


class IntentCategory(Enum):
    """High-level intent categories for routing."""

    # System operations
    SYSTEM_COMMAND = auto()      # File ops, process control, etc.
    SYSTEM_QUERY = auto()        # System status, resource info

    # Information retrieval
    SEARCH = auto()              # Web search, knowledge lookup
    QUESTION = auto()            # Factual questions
    EXPLANATION = auto()         # "Explain X", "What is Y"

    # Task execution
    CODE_WRITE = auto()          # Write/generate code
    CODE_DEBUG = auto()          # Debug/fix code
    CODE_REVIEW = auto()         # Review/analyze code
    CODE_REFACTOR = auto()       # Refactor existing code

    # Productivity
    CALENDAR = auto()            # Calendar operations
    REMINDER = auto()            # Reminders and todos
    EMAIL = auto()               # Email operations
    NOTE = auto()                # Note-taking

    # Communication
    GREETING = auto()            # Hello, hi, etc.
    FAREWELL = auto()            # Bye, goodbye, etc.
    GRATITUDE = auto()           # Thanks, thank you
    SMALL_TALK = auto()          # Casual conversation

    # Control
    CANCEL = auto()              # Cancel current operation
    UNDO = auto()                # Undo last action
    REPEAT = auto()              # Repeat last action
    HELP = auto()                # Help/documentation
    SETTINGS = auto()            # Configuration changes

    # Smart home
    HOME_AUTOMATION = auto()     # Lights, thermostat, etc.

    # Ambiguous/Unknown
    AMBIGUOUS = auto()           # Needs clarification
    UNKNOWN = auto()             # Cannot classify

    # Meta
    MULTI_INTENT = auto()        # Multiple intents detected


@dataclass
class Intent:
    """
    Represents a classified intent with associated metadata.
    """
    category: IntentCategory
    name: str
    description: str

    # Classification hints
    keywords: list[str] = field(default_factory=list)
    patterns: list[str] = field(default_factory=list)  # Regex patterns
    examples: list[str] = field(default_factory=list)  # Training examples for LLM
    negative_examples: list[str] = field(default_factory=list)  # Things NOT this intent

    # Routing metadata
    handler_name: Optional[str] = None
    requires_confirmation: bool = False
    requires_auth: bool = False
    priority: int = 0  # Higher = more specific, should match first

    # Slot extraction
    required_slots: list[str] = field(default_factory=list)
    optional_slots: list[str] = field(default_factory=list)

    def __hash__(self):
        return hash((self.category, self.name))


class IntentRegistry:
    """
    Registry of all known intents with lookup capabilities.
    """

    def __init__(self):
        self._intents: dict[str, Intent] = {}
        self._by_category: dict[IntentCategory, list[Intent]] = {}
        self._register_default_intents()

    def register(self, intent: Intent) -> None:
        """Register a new intent."""
        self._intents[intent.name] = intent
        if intent.category not in self._by_category:
            self._by_category[intent.category] = []
        self._by_category[intent.category].append(intent)

    def get(self, name: str) -> Optional[Intent]:
        """Get intent by name."""
        return self._intents.get(name)

    def get_by_category(self, category: IntentCategory) -> list[Intent]:
        """Get all intents in a category."""
        return self._by_category.get(category, [])

    def all_intents(self) -> list[Intent]:
        """Get all registered intents."""
        return list(self._intents.values())

    def _register_default_intents(self) -> None:
        """Register built-in default intents."""

        # Greetings
        self.register(Intent(
            category=IntentCategory.GREETING,
            name="greeting",
            description="User greeting or starting conversation",
            keywords=["hello", "hi", "hey", "good morning", "good afternoon", "good evening", "howdy", "greetings"],
            patterns=[r"^(hey|hi|hello|howdy|greetings)\b", r"^good\s+(morning|afternoon|evening|day)"],
            examples=[
                "Hello!",
                "Hi there",
                "Hey, how are you?",
                "Good morning!",
            ],
            handler_name="handle_greeting",
            priority=10,
        ))

        self.register(Intent(
            category=IntentCategory.FAREWELL,
            name="farewell",
            description="User ending conversation",
            keywords=["bye", "goodbye", "see you", "later", "goodnight", "cya"],
            patterns=[r"\b(bye|goodbye|see\s+you|later|goodnight|cya)\b"],
            examples=[
                "Bye!",
                "Goodbye",
                "See you later",
                "I'm heading out",
            ],
            handler_name="handle_farewell",
            priority=10,
        ))

        self.register(Intent(
            category=IntentCategory.GRATITUDE,
            name="gratitude",
            description="User expressing thanks",
            keywords=["thanks", "thank you", "appreciate", "grateful"],
            patterns=[r"\b(thanks|thank\s+you|thx|appreciate|grateful)\b"],
            examples=[
                "Thanks!",
                "Thank you so much",
                "I appreciate it",
            ],
            handler_name="handle_gratitude",
            priority=10,
        ))

        # System commands
        self.register(Intent(
            category=IntentCategory.SYSTEM_COMMAND,
            name="file_create",
            description="Create a new file or directory",
            keywords=["create", "make", "new", "file", "folder", "directory", "touch", "mkdir"],
            patterns=[r"\b(create|make|new)\b.*\b(file|folder|directory)\b", r"\b(touch|mkdir)\b"],
            examples=[
                "Create a new file called test.py",
                "Make a folder for the project",
                "Create directory src/components",
            ],
            handler_name="handle_file_create",
            required_slots=["path"],
            priority=20,
        ))

        self.register(Intent(
            category=IntentCategory.SYSTEM_COMMAND,
            name="file_read",
            description="Read or view file contents",
            keywords=["read", "show", "view", "cat", "display", "open", "contents"],
            patterns=[r"\b(read|show|view|cat|display|open)\b.*\b(file|contents)\b", r"what('s| is) in"],
            examples=[
                "Show me the contents of config.yaml",
                "Read the README file",
                "What's in package.json?",
            ],
            handler_name="handle_file_read",
            required_slots=["path"],
            priority=20,
        ))

        self.register(Intent(
            category=IntentCategory.SYSTEM_COMMAND,
            name="file_delete",
            description="Delete files or directories",
            keywords=["delete", "remove", "rm", "unlink", "trash"],
            patterns=[r"\b(delete|remove|rm)\b.*\b(file|folder|directory)?\b"],
            examples=[
                "Delete the old log files",
                "Remove the temp directory",
                "rm -rf node_modules",
            ],
            handler_name="handle_file_delete",
            required_slots=["path"],
            requires_confirmation=True,
            priority=20,
        ))

        self.register(Intent(
            category=IntentCategory.SYSTEM_COMMAND,
            name="run_command",
            description="Execute a shell command",
            keywords=["run", "execute", "exec", "shell", "terminal", "command"],
            patterns=[r"\b(run|execute|exec)\b", r"^(npm|yarn|pip|python|node|git|docker)\b"],
            examples=[
                "Run the tests",
                "Execute npm install",
                "Run git status",
            ],
            handler_name="handle_run_command",
            required_slots=["command"],
            priority=15,
        ))

        # Code intents
        self.register(Intent(
            category=IntentCategory.CODE_WRITE,
            name="code_generate",
            description="Generate or write new code",
            keywords=["write", "create", "generate", "implement", "code", "function", "class", "component"],
            patterns=[
                r"\b(write|create|generate|implement|build|make)\b.*\b(function|class|component|module|api|endpoint)\b",
                r"\b(add|create)\b.*\b(feature|functionality)\b",
            ],
            examples=[
                "Write a function to validate emails",
                "Create a React component for the header",
                "Implement a binary search algorithm",
                "Generate an API endpoint for user registration",
            ],
            negative_examples=[
                "Review this code",
                "Debug the login function",
            ],
            handler_name="handle_code_generate",
            priority=25,
        ))

        self.register(Intent(
            category=IntentCategory.CODE_DEBUG,
            name="code_debug",
            description="Debug or fix code issues",
            keywords=["debug", "fix", "error", "bug", "issue", "broken", "not working", "fails"],
            patterns=[
                r"\b(debug|fix|solve|resolve)\b.*\b(error|bug|issue|problem)\b",
                r"\b(not working|broken|fails|failing|crashed)\b",
                r"why (is|does|isn't|doesn't)",
            ],
            examples=[
                "Debug the authentication error",
                "Fix this TypeError",
                "Why is this function returning null?",
                "The login isn't working",
            ],
            handler_name="handle_code_debug",
            priority=25,
        ))

        self.register(Intent(
            category=IntentCategory.CODE_REVIEW,
            name="code_review",
            description="Review or analyze code",
            keywords=["review", "analyze", "check", "look at", "evaluate", "assess"],
            patterns=[
                r"\b(review|analyze|check|evaluate|assess)\b.*\b(code|function|class|file)\b",
                r"what do you think (of|about)",
            ],
            examples=[
                "Review this pull request",
                "Analyze the performance of this function",
                "Check my code for issues",
                "What do you think of this implementation?",
            ],
            handler_name="handle_code_review",
            priority=25,
        ))

        self.register(Intent(
            category=IntentCategory.CODE_REFACTOR,
            name="code_refactor",
            description="Refactor or improve existing code",
            keywords=["refactor", "improve", "clean up", "optimize", "restructure", "simplify"],
            patterns=[
                r"\b(refactor|improve|clean\s*up|optimize|restructure|simplify)\b",
                r"make (it|this|the code) (better|cleaner|more efficient)",
            ],
            examples=[
                "Refactor this function to be more readable",
                "Clean up this component",
                "Optimize the database queries",
                "Make this code more efficient",
            ],
            handler_name="handle_code_refactor",
            priority=25,
        ))

        # Questions and explanations
        self.register(Intent(
            category=IntentCategory.QUESTION,
            name="factual_question",
            description="Ask a factual question",
            keywords=["what", "who", "when", "where", "how many", "how much"],
            patterns=[
                r"^(what|who|when|where|which)\b.*\?$",
                r"^how (many|much)\b",
            ],
            examples=[
                "What is the capital of France?",
                "Who wrote this library?",
                "When was Python created?",
            ],
            handler_name="handle_question",
            priority=10,
        ))

        self.register(Intent(
            category=IntentCategory.EXPLANATION,
            name="explanation_request",
            description="Request an explanation",
            keywords=["explain", "what is", "what are", "how does", "why does", "tell me about"],
            patterns=[
                r"^(explain|describe)\b",
                r"^what (is|are)\b",
                r"^how does\b",
                r"^why (does|is|do|are)\b",
                r"^tell me (about|more)\b",
            ],
            examples=[
                "Explain how async/await works",
                "What is a closure?",
                "How does garbage collection work?",
                "Tell me about microservices",
            ],
            handler_name="handle_explanation",
            priority=15,
        ))

        # Search
        self.register(Intent(
            category=IntentCategory.SEARCH,
            name="web_search",
            description="Search the web for information",
            keywords=["search", "find", "look up", "google", "research"],
            patterns=[
                r"\b(search|find|look\s*up|google|research)\b.*\b(for|about|on)\b",
                r"^(search|find)\b",
            ],
            examples=[
                "Search for the latest Python release",
                "Find information about React hooks",
                "Look up the Express.js documentation",
            ],
            handler_name="handle_search",
            priority=15,
        ))

        # Productivity
        self.register(Intent(
            category=IntentCategory.REMINDER,
            name="create_reminder",
            description="Create a reminder",
            keywords=["remind", "reminder", "don't forget", "remember"],
            patterns=[
                r"\bremind\s+(me|us)\b",
                r"\bset\s+a?\s*reminder\b",
                r"\bdon't\s+(let\s+me\s+)?forget\b",
            ],
            examples=[
                "Remind me to call John at 3pm",
                "Set a reminder for the meeting tomorrow",
                "Don't let me forget to submit the report",
            ],
            handler_name="handle_create_reminder",
            optional_slots=["time", "date", "message"],
            priority=20,
        ))

        self.register(Intent(
            category=IntentCategory.CALENDAR,
            name="calendar_query",
            description="Query calendar events",
            keywords=["calendar", "schedule", "meeting", "appointment", "event", "busy"],
            patterns=[
                r"\b(what's|what is)\s+(on\s+)?(my\s+)?(calendar|schedule)\b",
                r"\b(am\s+i|are\s+we)\s+(free|busy|available)\b",
                r"\b(any|what)\s+(meetings|appointments|events)\b",
            ],
            examples=[
                "What's on my calendar today?",
                "Am I free at 2pm?",
                "What meetings do I have tomorrow?",
            ],
            handler_name="handle_calendar_query",
            optional_slots=["date", "time_range"],
            priority=20,
        ))

        # Help and settings
        self.register(Intent(
            category=IntentCategory.HELP,
            name="help_request",
            description="Request help or documentation",
            keywords=["help", "how to", "how do i", "tutorial", "guide", "documentation"],
            patterns=[
                r"^help\b",
                r"\bhow (do|can|should) i\b",
                r"\b(show|give)\s+me\s+(the\s+)?(help|docs|documentation)\b",
            ],
            examples=[
                "Help",
                "How do I use this feature?",
                "Show me the documentation",
            ],
            handler_name="handle_help",
            priority=10,
        ))

        self.register(Intent(
            category=IntentCategory.SETTINGS,
            name="settings_change",
            description="Change settings or preferences",
            keywords=["settings", "configure", "config", "preference", "change", "set", "enable", "disable"],
            patterns=[
                r"\b(change|update|set|modify)\s+(the\s+)?(settings?|config|preferences?)\b",
                r"\b(enable|disable|turn\s+(on|off))\b",
            ],
            examples=[
                "Change the theme to dark mode",
                "Enable voice commands",
                "Update my notification preferences",
            ],
            handler_name="handle_settings",
            priority=15,
        ))

        # Control
        self.register(Intent(
            category=IntentCategory.CANCEL,
            name="cancel_action",
            description="Cancel current action",
            keywords=["cancel", "stop", "abort", "nevermind", "never mind", "forget it"],
            patterns=[
                r"^(cancel|stop|abort|nevermind|never\s*mind|forget\s*it)\b",
            ],
            examples=[
                "Cancel",
                "Stop that",
                "Nevermind",
                "Abort the operation",
            ],
            handler_name="handle_cancel",
            priority=30,  # High priority to catch early
        ))

        self.register(Intent(
            category=IntentCategory.UNDO,
            name="undo_action",
            description="Undo last action",
            keywords=["undo", "revert", "rollback", "go back"],
            patterns=[
                r"^undo\b",
                r"\b(revert|rollback)\s+(the\s+)?(last|previous)\b",
            ],
            examples=[
                "Undo",
                "Revert the last change",
                "Go back",
            ],
            handler_name="handle_undo",
            priority=30,
        ))

        # Home automation
        self.register(Intent(
            category=IntentCategory.HOME_AUTOMATION,
            name="lights_control",
            description="Control lights",
            keywords=["lights", "light", "lamp", "brightness", "dim"],
            patterns=[
                r"\b(turn|switch)\s+(on|off)\s+(the\s+)?lights?\b",
                r"\b(dim|brighten)\s+(the\s+)?lights?\b",
                r"\blights?\s+(on|off)\b",
            ],
            examples=[
                "Turn on the lights",
                "Dim the living room lights",
                "Lights off",
            ],
            handler_name="handle_lights",
            optional_slots=["room", "brightness"],
            priority=20,
        ))

        self.register(Intent(
            category=IntentCategory.HOME_AUTOMATION,
            name="thermostat_control",
            description="Control thermostat/temperature",
            keywords=["temperature", "thermostat", "heat", "cool", "ac", "degrees"],
            patterns=[
                r"\bset\s+(the\s+)?temperature\s+to\b",
                r"\b(turn|switch)\s+(on|off|up|down)\s+(the\s+)?(heat|ac|air\s*conditioning)\b",
                r"\bmake\s+it\s+(warmer|cooler|hotter|colder)\b",
            ],
            examples=[
                "Set the temperature to 72",
                "Turn up the heat",
                "Make it cooler in here",
            ],
            handler_name="handle_thermostat",
            optional_slots=["temperature", "mode"],
            priority=20,
        ))

        # Unknown/Ambiguous
        self.register(Intent(
            category=IntentCategory.UNKNOWN,
            name="unknown",
            description="Unknown or unclassifiable intent",
            keywords=[],
            patterns=[],
            examples=[],
            handler_name="handle_unknown",
            priority=0,
        ))

        self.register(Intent(
            category=IntentCategory.AMBIGUOUS,
            name="ambiguous",
            description="Ambiguous intent requiring clarification",
            keywords=[],
            patterns=[],
            examples=[],
            handler_name="handle_ambiguous",
            priority=0,
        ))
