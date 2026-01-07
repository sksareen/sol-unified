"""
Memory system for the AI agent.

Three types of memory:
1. Session Memory - Conversation context within a single session
2. User Memory - Facts about the user that persist across sessions
3. Learned Memory - Generalizable insights that improve over time

Based on patterns from Ashpreet Bedi's agent memory architecture.
"""

import json
import sqlite3
import hashlib
import asyncio
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional, Any, Callable, Awaitable
from enum import Enum
from pathlib import Path


class MemoryType(Enum):
    """Types of memory."""
    SESSION = "session"
    USER = "user"
    LEARNED = "learned"


@dataclass
class MemoryEntry:
    """A single memory entry."""
    id: str
    memory_type: MemoryType
    content: str
    metadata: dict = field(default_factory=dict)
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    confidence: float = 1.0
    approved: bool = True  # For learned memory, requires approval

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "type": self.memory_type.value,
            "content": self.content,
            "metadata": self.metadata,
            "created_at": self.created_at.isoformat(),
            "session_id": self.session_id,
            "user_id": self.user_id,
            "confidence": self.confidence,
            "approved": self.approved,
        }


@dataclass
class Message:
    """A conversation message."""
    role: str  # "user", "assistant", "system"
    content: str
    timestamp: datetime = field(default_factory=datetime.now)
    metadata: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "role": self.role,
            "content": self.content,
            "timestamp": self.timestamp.isoformat(),
            "metadata": self.metadata,
        }


class MemoryStore(ABC):
    """Abstract base class for memory storage backends."""

    @abstractmethod
    async def save(self, entry: MemoryEntry) -> None:
        """Save a memory entry."""
        pass

    @abstractmethod
    async def get(self, id: str) -> Optional[MemoryEntry]:
        """Get a memory entry by ID."""
        pass

    @abstractmethod
    async def search(
        self,
        query: str,
        memory_type: Optional[MemoryType] = None,
        user_id: Optional[str] = None,
        session_id: Optional[str] = None,
        limit: int = 10,
    ) -> list[MemoryEntry]:
        """Search memory entries."""
        pass

    @abstractmethod
    async def delete(self, id: str) -> bool:
        """Delete a memory entry."""
        pass

    @abstractmethod
    async def list_by_session(self, session_id: str, limit: int = 100) -> list[MemoryEntry]:
        """List entries for a session."""
        pass

    @abstractmethod
    async def list_by_user(self, user_id: str, limit: int = 100) -> list[MemoryEntry]:
        """List entries for a user."""
        pass


class SQLiteMemoryStore(MemoryStore):
    """SQLite-based memory storage."""

    def __init__(self, db_path: str = "memory.db"):
        self.db_path = db_path
        self._init_db()

    def _init_db(self) -> None:
        """Initialize the database schema."""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        # Memory entries table
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS memory_entries (
                id TEXT PRIMARY KEY,
                memory_type TEXT NOT NULL,
                content TEXT NOT NULL,
                metadata TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                session_id TEXT,
                user_id TEXT,
                confidence REAL DEFAULT 1.0,
                approved INTEGER DEFAULT 1
            )
        """)

        # Messages table for session history
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS messages (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                metadata TEXT
            )
        """)

        # Indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_memory_type ON memory_entries(memory_type)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_session_id ON memory_entries(session_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_user_id ON memory_entries(user_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_messages_session ON messages(session_id)")

        conn.commit()
        conn.close()

    def _get_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    async def save(self, entry: MemoryEntry) -> None:
        conn = self._get_conn()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT OR REPLACE INTO memory_entries
            (id, memory_type, content, metadata, created_at, updated_at, session_id, user_id, confidence, approved)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            entry.id,
            entry.memory_type.value,
            entry.content,
            json.dumps(entry.metadata),
            entry.created_at.isoformat(),
            entry.updated_at.isoformat(),
            entry.session_id,
            entry.user_id,
            entry.confidence,
            1 if entry.approved else 0,
        ))

        conn.commit()
        conn.close()

    async def get(self, id: str) -> Optional[MemoryEntry]:
        conn = self._get_conn()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM memory_entries WHERE id = ?", (id,))
        row = cursor.fetchone()
        conn.close()

        if row:
            return self._row_to_entry(row)
        return None

    async def search(
        self,
        query: str,
        memory_type: Optional[MemoryType] = None,
        user_id: Optional[str] = None,
        session_id: Optional[str] = None,
        limit: int = 10,
    ) -> list[MemoryEntry]:
        conn = self._get_conn()
        cursor = conn.cursor()

        # Basic text search (for production, use FTS5 or vector DB)
        sql = "SELECT * FROM memory_entries WHERE content LIKE ?"
        params = [f"%{query}%"]

        if memory_type:
            sql += " AND memory_type = ?"
            params.append(memory_type.value)

        if user_id:
            sql += " AND user_id = ?"
            params.append(user_id)

        if session_id:
            sql += " AND session_id = ?"
            params.append(session_id)

        sql += " AND approved = 1 ORDER BY updated_at DESC LIMIT ?"
        params.append(limit)

        cursor.execute(sql, params)
        rows = cursor.fetchall()
        conn.close()

        return [self._row_to_entry(row) for row in rows]

    async def delete(self, id: str) -> bool:
        conn = self._get_conn()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM memory_entries WHERE id = ?", (id,))
        deleted = cursor.rowcount > 0
        conn.commit()
        conn.close()
        return deleted

    async def list_by_session(self, session_id: str, limit: int = 100) -> list[MemoryEntry]:
        conn = self._get_conn()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM memory_entries WHERE session_id = ? ORDER BY created_at DESC LIMIT ?",
            (session_id, limit)
        )
        rows = cursor.fetchall()
        conn.close()
        return [self._row_to_entry(row) for row in rows]

    async def list_by_user(self, user_id: str, limit: int = 100) -> list[MemoryEntry]:
        conn = self._get_conn()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM memory_entries WHERE user_id = ? AND approved = 1 ORDER BY updated_at DESC LIMIT ?",
            (user_id, limit)
        )
        rows = cursor.fetchall()
        conn.close()
        return [self._row_to_entry(row) for row in rows]

    def _row_to_entry(self, row: sqlite3.Row) -> MemoryEntry:
        return MemoryEntry(
            id=row["id"],
            memory_type=MemoryType(row["memory_type"]),
            content=row["content"],
            metadata=json.loads(row["metadata"]) if row["metadata"] else {},
            created_at=datetime.fromisoformat(row["created_at"]),
            updated_at=datetime.fromisoformat(row["updated_at"]),
            session_id=row["session_id"],
            user_id=row["user_id"],
            confidence=row["confidence"],
            approved=bool(row["approved"]),
        )

    # Message-specific methods
    async def save_message(self, session_id: str, message: Message) -> None:
        conn = self._get_conn()
        cursor = conn.cursor()
        cursor.execute("""
            INSERT INTO messages (session_id, role, content, timestamp, metadata)
            VALUES (?, ?, ?, ?, ?)
        """, (
            session_id,
            message.role,
            message.content,
            message.timestamp.isoformat(),
            json.dumps(message.metadata),
        ))
        conn.commit()
        conn.close()

    async def get_messages(self, session_id: str, limit: int = 50) -> list[Message]:
        conn = self._get_conn()
        cursor = conn.cursor()
        cursor.execute(
            "SELECT * FROM messages WHERE session_id = ? ORDER BY timestamp ASC LIMIT ?",
            (session_id, limit)
        )
        rows = cursor.fetchall()
        conn.close()

        return [
            Message(
                role=row["role"],
                content=row["content"],
                timestamp=datetime.fromisoformat(row["timestamp"]),
                metadata=json.loads(row["metadata"]) if row["metadata"] else {},
            )
            for row in rows
        ]


class SessionMemory:
    """
    Session memory - preserves conversation context within a single session.

    Stores messages and retrieves them before every response.
    """

    def __init__(self, store: MemoryStore, session_id: str):
        self.store = store
        self.session_id = session_id
        self._messages: list[Message] = []
        self._loaded = False

    async def load(self) -> None:
        """Load session history from store."""
        if isinstance(self.store, SQLiteMemoryStore):
            self._messages = await self.store.get_messages(self.session_id)
        self._loaded = True

    async def add_message(self, role: str, content: str, metadata: dict = None) -> None:
        """Add a message to the session."""
        message = Message(
            role=role,
            content=content,
            metadata=metadata or {},
        )
        self._messages.append(message)

        if isinstance(self.store, SQLiteMemoryStore):
            await self.store.save_message(self.session_id, message)

    async def get_history(self, limit: int = 50) -> list[Message]:
        """Get conversation history."""
        if not self._loaded:
            await self.load()
        return self._messages[-limit:]

    async def get_context_string(self, limit: int = 10) -> str:
        """Get history as a formatted string for LLM context."""
        messages = await self.get_history(limit)
        return "\n".join(
            f"{m.role}: {m.content}"
            for m in messages
        )

    def clear(self) -> None:
        """Clear in-memory messages (doesn't delete from store)."""
        self._messages = []
        self._loaded = False


class UserMemory:
    """
    User memory - facts about the user that persist across sessions.

    Stores preferences, goals, constraints, and other user-specific info.
    """

    def __init__(self, store: MemoryStore, user_id: str):
        self.store = store
        self.user_id = user_id

    async def remember(
        self,
        fact: str,
        category: str = "general",
        confidence: float = 1.0,
        metadata: dict = None,
    ) -> MemoryEntry:
        """Remember a fact about the user."""
        entry = MemoryEntry(
            id=self._generate_id(fact),
            memory_type=MemoryType.USER,
            content=fact,
            metadata={"category": category, **(metadata or {})},
            user_id=self.user_id,
            confidence=confidence,
        )
        await self.store.save(entry)
        return entry

    async def recall(self, query: str = "", limit: int = 10) -> list[MemoryEntry]:
        """Recall facts about the user."""
        if query:
            return await self.store.search(
                query=query,
                memory_type=MemoryType.USER,
                user_id=self.user_id,
                limit=limit,
            )
        return await self.store.list_by_user(self.user_id, limit)

    async def recall_by_category(self, category: str) -> list[MemoryEntry]:
        """Recall facts by category."""
        all_memories = await self.recall(limit=1000)
        return [m for m in all_memories if m.metadata.get("category") == category]

    async def forget(self, id: str) -> bool:
        """Forget a specific memory."""
        return await self.store.delete(id)

    async def get_profile_string(self) -> str:
        """Get user profile as a string for LLM context."""
        memories = await self.recall(limit=20)
        if not memories:
            return "No user preferences stored yet."

        by_category: dict[str, list[str]] = {}
        for m in memories:
            cat = m.metadata.get("category", "general")
            if cat not in by_category:
                by_category[cat] = []
            by_category[cat].append(m.content)

        lines = ["User Profile:"]
        for cat, facts in by_category.items():
            lines.append(f"  {cat.title()}:")
            for fact in facts:
                lines.append(f"    - {fact}")

        return "\n".join(lines)

    def _generate_id(self, content: str) -> str:
        """Generate a deterministic ID for deduplication."""
        hash_input = f"{self.user_id}:{content}"
        return hashlib.sha256(hash_input.encode()).hexdigest()[:16]


class LearnedMemory:
    """
    Learned memory - generalizable insights that apply across users.

    Requires human-in-the-loop approval before saving to prevent
    knowledge base degradation.
    """

    def __init__(
        self,
        store: MemoryStore,
        require_approval: bool = True,
        approval_callback: Optional[Callable[[str], Awaitable[bool]]] = None,
    ):
        self.store = store
        self.require_approval = require_approval
        self.approval_callback = approval_callback
        self._pending: list[MemoryEntry] = []

    async def propose_learning(
        self,
        insight: str,
        category: str = "general",
        confidence: float = 0.8,
        source: str = None,
        metadata: dict = None,
    ) -> MemoryEntry:
        """
        Propose a new learning/insight.

        If require_approval is True, it will be held for approval.
        Otherwise, it's saved immediately.
        """
        entry = MemoryEntry(
            id=self._generate_id(insight),
            memory_type=MemoryType.LEARNED,
            content=insight,
            metadata={
                "category": category,
                "source": source,
                **(metadata or {}),
            },
            confidence=confidence,
            approved=not self.require_approval,
        )

        if self.require_approval:
            self._pending.append(entry)

            # If we have an approval callback, use it
            if self.approval_callback:
                approved = await self.approval_callback(insight)
                if approved:
                    entry.approved = True
                    await self.store.save(entry)
                    self._pending.remove(entry)
        else:
            await self.store.save(entry)

        return entry

    async def approve(self, id: str) -> bool:
        """Approve a pending learning."""
        for entry in self._pending:
            if entry.id == id:
                entry.approved = True
                await self.store.save(entry)
                self._pending.remove(entry)
                return True
        return False

    async def reject(self, id: str) -> bool:
        """Reject a pending learning."""
        for entry in self._pending:
            if entry.id == id:
                self._pending.remove(entry)
                return True
        return False

    def get_pending(self) -> list[MemoryEntry]:
        """Get all pending learnings awaiting approval."""
        return self._pending.copy()

    async def recall(self, query: str = "", category: str = None, limit: int = 10) -> list[MemoryEntry]:
        """Recall learned insights."""
        entries = await self.store.search(
            query=query or "",
            memory_type=MemoryType.LEARNED,
            limit=limit * 2,  # Fetch extra to filter
        )

        # Filter by category if specified
        if category:
            entries = [e for e in entries if e.metadata.get("category") == category]

        # Only return approved entries
        return [e for e in entries if e.approved][:limit]

    async def get_insights_string(self, category: str = None, limit: int = 10) -> str:
        """Get insights as a string for LLM context."""
        insights = await self.recall(category=category, limit=limit)
        if not insights:
            return ""

        lines = ["Learned Insights:"]
        for i in insights:
            cat = i.metadata.get("category", "general")
            lines.append(f"  [{cat}] {i.content}")

        return "\n".join(lines)

    def _generate_id(self, content: str) -> str:
        """Generate ID for the insight."""
        return hashlib.sha256(content.encode()).hexdigest()[:16]


class MemoryManager:
    """
    Central manager for all memory types.

    Provides unified interface and automatic fact extraction.
    """

    def __init__(
        self,
        store: Optional[MemoryStore] = None,
        db_path: str = "memory.db",
        require_learning_approval: bool = True,
    ):
        self.store = store or SQLiteMemoryStore(db_path)
        self.require_learning_approval = require_learning_approval

        self._sessions: dict[str, SessionMemory] = {}
        self._users: dict[str, UserMemory] = {}
        self._learned = LearnedMemory(self.store, require_learning_approval)

    def get_session(self, session_id: str) -> SessionMemory:
        """Get or create session memory."""
        if session_id not in self._sessions:
            self._sessions[session_id] = SessionMemory(self.store, session_id)
        return self._sessions[session_id]

    def get_user(self, user_id: str) -> UserMemory:
        """Get or create user memory."""
        if user_id not in self._users:
            self._users[user_id] = UserMemory(self.store, user_id)
        return self._users[user_id]

    @property
    def learned(self) -> LearnedMemory:
        """Access learned memory."""
        return self._learned

    async def build_context(
        self,
        session_id: str,
        user_id: Optional[str] = None,
        include_learned: bool = True,
        history_limit: int = 10,
    ) -> dict:
        """
        Build complete context for the LLM.

        Returns a dict with all relevant memory context.
        """
        context = {}

        # Session history
        session = self.get_session(session_id)
        history = await session.get_history(history_limit)
        context["conversation_history"] = [m.to_dict() for m in history]
        context["history_string"] = await session.get_context_string(history_limit)

        # User profile
        if user_id:
            user = self.get_user(user_id)
            user_memories = await user.recall(limit=20)
            context["user_profile"] = [m.to_dict() for m in user_memories]
            context["user_string"] = await user.get_profile_string()

        # Learned insights
        if include_learned:
            insights = await self._learned.recall(limit=10)
            context["learned_insights"] = [m.to_dict() for m in insights]
            context["insights_string"] = await self._learned.get_insights_string()

        return context

    async def extract_user_facts(
        self,
        text: str,
        user_id: str,
        llm_extractor: Optional[Callable[[str], Awaitable[list[dict]]]] = None,
    ) -> list[MemoryEntry]:
        """
        Extract and store user facts from text.

        Can use an LLM to identify facts, or falls back to simple patterns.
        """
        facts = []

        if llm_extractor:
            # Use LLM to extract facts
            extracted = await llm_extractor(text)
            for item in extracted:
                entry = await self.get_user(user_id).remember(
                    fact=item.get("fact", ""),
                    category=item.get("category", "general"),
                    confidence=item.get("confidence", 0.8),
                )
                facts.append(entry)
        else:
            # Simple pattern-based extraction
            patterns = [
                (r"(?:i|my)\s+(?:prefer|like|love|enjoy)\s+(.+)", "preferences"),
                (r"(?:i|my)\s+(?:hate|dislike|don't like)\s+(.+)", "dislikes"),
                (r"(?:i'm|i am)\s+(?:a|an)\s+(.+)", "identity"),
                (r"(?:i|my)\s+(?:work|job)\s+(?:is|as|at)\s+(.+)", "work"),
                (r"(?:call me|my name is)\s+(.+)", "name"),
            ]

            import re
            for pattern, category in patterns:
                matches = re.findall(pattern, text, re.IGNORECASE)
                for match in matches:
                    entry = await self.get_user(user_id).remember(
                        fact=match.strip(),
                        category=category,
                        confidence=0.7,
                    )
                    facts.append(entry)

        return facts

    async def record_interaction(
        self,
        session_id: str,
        user_input: str,
        assistant_response: str,
        user_id: Optional[str] = None,
        extract_facts: bool = True,
    ) -> None:
        """
        Record a complete interaction.

        Saves messages and optionally extracts user facts.
        """
        session = self.get_session(session_id)

        await session.add_message("user", user_input)
        await session.add_message("assistant", assistant_response)

        if extract_facts and user_id:
            await self.extract_user_facts(user_input, user_id)
