"""
Memory System v2 - Addresses gaps in initial implementation.

Improvements:
1. Summarization - Condenses old memories using LLM or heuristics
2. Deduplication - Detects and merges similar memories
3. Compaction - Limits memory size, archives old entries
4. Persistence - Pending learnings saved to DB
5. Relevance - Better retrieval using recency + frequency + similarity
"""

import json
import sqlite3
import hashlib
import asyncio
import re
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Optional, Any, Callable, Awaitable
from enum import Enum
from difflib import SequenceMatcher


class MemoryType(Enum):
    SESSION = "session"
    USER = "user"
    LEARNED = "learned"
    SUMMARY = "summary"  # New: summarized memories


@dataclass
class MemoryEntry:
    """A single memory entry with metadata for relevance scoring."""
    id: str
    memory_type: MemoryType
    content: str
    metadata: dict = field(default_factory=dict)
    created_at: datetime = field(default_factory=datetime.now)
    updated_at: datetime = field(default_factory=datetime.now)
    session_id: Optional[str] = None
    user_id: Optional[str] = None
    confidence: float = 1.0
    approved: bool = True

    # New fields for better memory management
    access_count: int = 0  # How often this memory is retrieved
    last_accessed: Optional[datetime] = None
    source_ids: list[str] = field(default_factory=list)  # IDs of memories this summarizes
    is_archived: bool = False
    version: int = 1

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "type": self.memory_type.value,
            "content": self.content,
            "metadata": self.metadata,
            "created_at": self.created_at.isoformat(),
            "confidence": self.confidence,
            "access_count": self.access_count,
            "version": self.version,
        }

    def relevance_score(self, query: str = "") -> float:
        """
        Calculate relevance score based on multiple factors.
        Higher = more relevant.
        """
        score = 0.0

        # Recency boost (exponential decay over 7 days)
        age_hours = (datetime.now() - self.updated_at).total_seconds() / 3600
        recency_score = max(0, 1.0 - (age_hours / (7 * 24)))
        score += recency_score * 0.3

        # Access frequency boost
        freq_score = min(1.0, self.access_count / 10)
        score += freq_score * 0.2

        # Confidence boost
        score += self.confidence * 0.2

        # Query similarity boost (if query provided)
        if query:
            similarity = SequenceMatcher(None, query.lower(), self.content.lower()).ratio()
            score += similarity * 0.3
        else:
            score += 0.15  # Neutral if no query

        return score


@dataclass
class Message:
    role: str
    content: str
    timestamp: datetime = field(default_factory=datetime.now)
    metadata: dict = field(default_factory=dict)

    def to_dict(self) -> dict:
        return {
            "role": self.role,
            "content": self.content,
            "timestamp": self.timestamp.isoformat(),
        }


class MemoryStoreV2:
    """
    Improved SQLite memory store with:
    - Versioning
    - Archival
    - Better indexing
    - Pending learnings persistence
    """

    def __init__(self, db_path: str = "memory.db"):
        self.db_path = db_path
        self._init_db()

    def _init_db(self) -> None:
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()

        # Memory entries with new fields
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS memory_entries_v2 (
                id TEXT PRIMARY KEY,
                memory_type TEXT NOT NULL,
                content TEXT NOT NULL,
                metadata TEXT,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                session_id TEXT,
                user_id TEXT,
                confidence REAL DEFAULT 1.0,
                approved INTEGER DEFAULT 1,
                access_count INTEGER DEFAULT 0,
                last_accessed TEXT,
                source_ids TEXT,
                is_archived INTEGER DEFAULT 0,
                version INTEGER DEFAULT 1
            )
        """)

        # Messages with summary tracking
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS messages_v2 (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                metadata TEXT,
                is_summarized INTEGER DEFAULT 0
            )
        """)

        # Pending learnings (persisted!)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS pending_learnings (
                id TEXT PRIMARY KEY,
                content TEXT NOT NULL,
                metadata TEXT,
                created_at TEXT NOT NULL,
                confidence REAL DEFAULT 0.8,
                source TEXT
            )
        """)

        # Memory summaries
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS memory_summaries (
                id TEXT PRIMARY KEY,
                user_id TEXT,
                session_id TEXT,
                summary_type TEXT NOT NULL,
                content TEXT NOT NULL,
                source_count INTEGER,
                created_at TEXT NOT NULL,
                covers_until TEXT
            )
        """)

        # Indexes
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_v2_type ON memory_entries_v2(memory_type)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_v2_user ON memory_entries_v2(user_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_v2_session ON memory_entries_v2(session_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_v2_archived ON memory_entries_v2(is_archived)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_msg_session ON messages_v2(session_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_msg_summarized ON messages_v2(is_summarized)")

        conn.commit()
        conn.close()

    def _get_conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.row_factory = sqlite3.Row
        return conn

    async def save(self, entry: MemoryEntry) -> None:
        """Save with conflict resolution."""
        conn = self._get_conn()
        cursor = conn.cursor()

        # Check for existing entry
        cursor.execute("SELECT version, content FROM memory_entries_v2 WHERE id = ?", (entry.id,))
        existing = cursor.fetchone()

        if existing:
            # Increment version on update
            entry.version = existing["version"] + 1
            entry.updated_at = datetime.now()

        cursor.execute("""
            INSERT OR REPLACE INTO memory_entries_v2
            (id, memory_type, content, metadata, created_at, updated_at, session_id,
             user_id, confidence, approved, access_count, last_accessed, source_ids,
             is_archived, version)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
            entry.access_count,
            entry.last_accessed.isoformat() if entry.last_accessed else None,
            json.dumps(entry.source_ids),
            1 if entry.is_archived else 0,
            entry.version,
        ))

        conn.commit()
        conn.close()

    async def get(self, id: str, update_access: bool = True) -> Optional[MemoryEntry]:
        """Get entry and optionally update access stats."""
        conn = self._get_conn()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM memory_entries_v2 WHERE id = ?", (id,))
        row = cursor.fetchone()

        if row and update_access:
            cursor.execute("""
                UPDATE memory_entries_v2
                SET access_count = access_count + 1, last_accessed = ?
                WHERE id = ?
            """, (datetime.now().isoformat(), id))
            conn.commit()

        conn.close()
        return self._row_to_entry(row) if row else None

    async def search_relevant(
        self,
        query: str,
        memory_type: Optional[MemoryType] = None,
        user_id: Optional[str] = None,
        limit: int = 10,
    ) -> list[MemoryEntry]:
        """Search with relevance scoring."""
        conn = self._get_conn()
        cursor = conn.cursor()

        # Get candidates
        sql = "SELECT * FROM memory_entries_v2 WHERE is_archived = 0 AND approved = 1"
        params = []

        if memory_type:
            sql += " AND memory_type = ?"
            params.append(memory_type.value)

        if user_id:
            sql += " AND user_id = ?"
            params.append(user_id)

        # Get more than needed for scoring
        sql += " ORDER BY updated_at DESC LIMIT ?"
        params.append(limit * 3)

        cursor.execute(sql, params)
        rows = cursor.fetchall()
        conn.close()

        # Score and sort by relevance
        entries = [self._row_to_entry(row) for row in rows]
        entries.sort(key=lambda e: e.relevance_score(query), reverse=True)

        return entries[:limit]

    async def find_similar(self, content: str, threshold: float = 0.7) -> list[MemoryEntry]:
        """Find memories similar to given content."""
        conn = self._get_conn()
        cursor = conn.cursor()

        cursor.execute(
            "SELECT * FROM memory_entries_v2 WHERE is_archived = 0 AND approved = 1"
        )
        rows = cursor.fetchall()
        conn.close()

        similar = []
        content_lower = content.lower()

        for row in rows:
            entry = self._row_to_entry(row)
            similarity = SequenceMatcher(None, content_lower, entry.content.lower()).ratio()
            if similarity >= threshold:
                entry.metadata["similarity"] = similarity
                similar.append(entry)

        return sorted(similar, key=lambda e: e.metadata.get("similarity", 0), reverse=True)

    async def archive_old(self, older_than_days: int = 30, memory_type: Optional[MemoryType] = None) -> int:
        """Archive old memories."""
        conn = self._get_conn()
        cursor = conn.cursor()

        cutoff = (datetime.now() - timedelta(days=older_than_days)).isoformat()

        sql = "UPDATE memory_entries_v2 SET is_archived = 1 WHERE updated_at < ? AND is_archived = 0"
        params = [cutoff]

        if memory_type:
            sql += " AND memory_type = ?"
            params.append(memory_type.value)

        cursor.execute(sql, params)
        archived = cursor.rowcount
        conn.commit()
        conn.close()

        return archived

    async def get_memory_stats(self, user_id: Optional[str] = None) -> dict:
        """Get memory statistics."""
        conn = self._get_conn()
        cursor = conn.cursor()

        stats = {}

        # Count by type
        sql = "SELECT memory_type, COUNT(*) as cnt FROM memory_entries_v2 WHERE is_archived = 0"
        if user_id:
            sql += " AND user_id = ?"
            cursor.execute(sql + " GROUP BY memory_type", (user_id,))
        else:
            cursor.execute(sql + " GROUP BY memory_type")

        stats["by_type"] = {row["memory_type"]: row["cnt"] for row in cursor.fetchall()}

        # Total active
        sql = "SELECT COUNT(*) as cnt FROM memory_entries_v2 WHERE is_archived = 0"
        if user_id:
            cursor.execute(sql + " AND user_id = ?", (user_id,))
        else:
            cursor.execute(sql)
        stats["total_active"] = cursor.fetchone()["cnt"]

        # Total archived
        cursor.execute("SELECT COUNT(*) as cnt FROM memory_entries_v2 WHERE is_archived = 1")
        stats["total_archived"] = cursor.fetchone()["cnt"]

        # Pending learnings
        cursor.execute("SELECT COUNT(*) as cnt FROM pending_learnings")
        stats["pending_learnings"] = cursor.fetchone()["cnt"]

        conn.close()
        return stats

    # Pending learnings persistence
    async def save_pending_learning(self, entry: MemoryEntry) -> None:
        """Persist a pending learning."""
        conn = self._get_conn()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT OR REPLACE INTO pending_learnings
            (id, content, metadata, created_at, confidence, source)
            VALUES (?, ?, ?, ?, ?, ?)
        """, (
            entry.id,
            entry.content,
            json.dumps(entry.metadata),
            entry.created_at.isoformat(),
            entry.confidence,
            entry.metadata.get("source"),
        ))

        conn.commit()
        conn.close()

    async def get_pending_learnings(self) -> list[MemoryEntry]:
        """Get all pending learnings."""
        conn = self._get_conn()
        cursor = conn.cursor()

        cursor.execute("SELECT * FROM pending_learnings ORDER BY created_at DESC")
        rows = cursor.fetchall()
        conn.close()

        return [
            MemoryEntry(
                id=row["id"],
                memory_type=MemoryType.LEARNED,
                content=row["content"],
                metadata=json.loads(row["metadata"]) if row["metadata"] else {},
                created_at=datetime.fromisoformat(row["created_at"]),
                confidence=row["confidence"],
                approved=False,
            )
            for row in rows
        ]

    async def remove_pending_learning(self, id: str) -> bool:
        """Remove a pending learning."""
        conn = self._get_conn()
        cursor = conn.cursor()
        cursor.execute("DELETE FROM pending_learnings WHERE id = ?", (id,))
        removed = cursor.rowcount > 0
        conn.commit()
        conn.close()
        return removed

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
            access_count=row["access_count"],
            last_accessed=datetime.fromisoformat(row["last_accessed"]) if row["last_accessed"] else None,
            source_ids=json.loads(row["source_ids"]) if row["source_ids"] else [],
            is_archived=bool(row["is_archived"]),
            version=row["version"],
        )

    # Message methods
    async def save_message(self, session_id: str, message: Message) -> int:
        """Save message and return ID."""
        conn = self._get_conn()
        cursor = conn.cursor()

        cursor.execute("""
            INSERT INTO messages_v2 (session_id, role, content, timestamp, metadata)
            VALUES (?, ?, ?, ?, ?)
        """, (
            session_id,
            message.role,
            message.content,
            message.timestamp.isoformat(),
            json.dumps(message.metadata),
        ))

        msg_id = cursor.lastrowid
        conn.commit()
        conn.close()
        return msg_id

    async def get_messages(self, session_id: str, limit: int = 50, unsummarized_only: bool = False) -> list[Message]:
        """Get messages, optionally only unsummarized ones."""
        conn = self._get_conn()
        cursor = conn.cursor()

        sql = "SELECT * FROM messages_v2 WHERE session_id = ?"
        params = [session_id]

        if unsummarized_only:
            sql += " AND is_summarized = 0"

        sql += " ORDER BY timestamp ASC LIMIT ?"
        params.append(limit)

        cursor.execute(sql, params)
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

    async def mark_messages_summarized(self, session_id: str, up_to_id: int) -> None:
        """Mark messages as summarized."""
        conn = self._get_conn()
        cursor = conn.cursor()

        cursor.execute("""
            UPDATE messages_v2 SET is_summarized = 1
            WHERE session_id = ? AND id <= ?
        """, (session_id, up_to_id))

        conn.commit()
        conn.close()


class MemorySummarizer:
    """
    Summarizes memories to prevent unbounded growth.
    Uses local LLM if available, falls back to heuristics.
    """

    def __init__(
        self,
        llm_summarize: Optional[Callable[[str], Awaitable[str]]] = None,
        max_session_messages: int = 50,
        max_user_memories: int = 100,
    ):
        self.llm_summarize = llm_summarize
        self.max_session_messages = max_session_messages
        self.max_user_memories = max_user_memories

    async def summarize_session(self, messages: list[Message]) -> str:
        """Summarize a session's conversation."""
        if not messages:
            return ""

        # Build conversation text
        conversation = "\n".join(f"{m.role}: {m.content}" for m in messages)

        if self.llm_summarize:
            prompt = f"""Summarize this conversation in 2-3 sentences, focusing on:
- Key topics discussed
- Decisions made
- Action items or follow-ups

Conversation:
{conversation}

Summary:"""
            return await self.llm_summarize(prompt)

        # Fallback: Extract key points heuristically
        return self._heuristic_summarize(messages)

    async def summarize_user_facts(self, facts: list[MemoryEntry]) -> list[MemoryEntry]:
        """Consolidate similar user facts."""
        if len(facts) <= 5:
            return facts

        # Group by category
        by_category: dict[str, list[MemoryEntry]] = {}
        for fact in facts:
            cat = fact.metadata.get("category", "general")
            if cat not in by_category:
                by_category[cat] = []
            by_category[cat].append(fact)

        consolidated = []
        for category, cat_facts in by_category.items():
            if len(cat_facts) <= 2:
                consolidated.extend(cat_facts)
                continue

            # Consolidate this category
            if self.llm_summarize:
                facts_text = "\n".join(f"- {f.content}" for f in cat_facts)
                prompt = f"""Consolidate these related facts about the user into 1-2 key points:

{facts_text}

Consolidated facts (one per line):"""
                summary = await self.llm_summarize(prompt)

                # Create consolidated entry
                consolidated.append(MemoryEntry(
                    id=hashlib.sha256(summary.encode()).hexdigest()[:16],
                    memory_type=MemoryType.USER,
                    content=summary,
                    metadata={"category": category, "consolidated_from": len(cat_facts)},
                    source_ids=[f.id for f in cat_facts],
                    confidence=sum(f.confidence for f in cat_facts) / len(cat_facts),
                ))
            else:
                # Keep highest confidence ones
                cat_facts.sort(key=lambda f: f.confidence, reverse=True)
                consolidated.extend(cat_facts[:2])

        return consolidated

    def _heuristic_summarize(self, messages: list[Message]) -> str:
        """Simple heuristic summarization without LLM."""
        if not messages:
            return ""

        # Extract topics mentioned
        user_messages = [m.content for m in messages if m.role == "user"]

        # Simple keyword extraction
        all_text = " ".join(user_messages).lower()

        # Count word frequency (excluding common words)
        stop_words = {"the", "a", "an", "is", "are", "was", "were", "i", "you", "it",
                      "to", "for", "of", "in", "on", "and", "or", "but", "with", "this",
                      "that", "can", "do", "what", "how", "please", "help", "me", "my"}

        words = re.findall(r'\b\w+\b', all_text)
        word_freq = {}
        for word in words:
            if word not in stop_words and len(word) > 2:
                word_freq[word] = word_freq.get(word, 0) + 1

        # Top topics
        top_words = sorted(word_freq.items(), key=lambda x: x[1], reverse=True)[:5]
        topics = [w[0] for w in top_words]

        if topics:
            return f"Discussed: {', '.join(topics)}. {len(messages)} messages exchanged."
        return f"Session with {len(messages)} messages."


class MemoryDeduplicator:
    """
    Detects and merges duplicate/similar memories.
    """

    def __init__(self, similarity_threshold: float = 0.75):
        self.similarity_threshold = similarity_threshold

    def find_duplicates(self, memories: list[MemoryEntry]) -> list[tuple[MemoryEntry, MemoryEntry, float]]:
        """Find pairs of similar memories."""
        duplicates = []

        for i, m1 in enumerate(memories):
            for m2 in memories[i + 1:]:
                similarity = SequenceMatcher(
                    None,
                    m1.content.lower(),
                    m2.content.lower()
                ).ratio()

                if similarity >= self.similarity_threshold:
                    duplicates.append((m1, m2, similarity))

        return duplicates

    def merge_memories(self, m1: MemoryEntry, m2: MemoryEntry) -> MemoryEntry:
        """Merge two similar memories into one."""
        # Keep the more confident/recent one as base
        if m1.confidence > m2.confidence:
            base, other = m1, m2
        elif m2.confidence > m1.confidence:
            base, other = m2, m1
        elif m1.updated_at > m2.updated_at:
            base, other = m1, m2
        else:
            base, other = m2, m1

        # Merge metadata
        merged_metadata = {**other.metadata, **base.metadata}
        merged_metadata["merged_from"] = [base.id, other.id]

        return MemoryEntry(
            id=base.id,
            memory_type=base.memory_type,
            content=base.content,  # Use base content
            metadata=merged_metadata,
            created_at=min(base.created_at, other.created_at),
            updated_at=datetime.now(),
            session_id=base.session_id,
            user_id=base.user_id or other.user_id,
            confidence=max(base.confidence, other.confidence),
            access_count=base.access_count + other.access_count,
            source_ids=list(set(base.source_ids + other.source_ids + [other.id])),
            version=base.version + 1,
        )


class MemoryManagerV2:
    """
    Improved memory manager with:
    - Automatic summarization
    - Deduplication
    - Compaction
    - Better retrieval
    """

    def __init__(
        self,
        db_path: str = "memory_v2.db",
        llm_func: Optional[Callable[[str], Awaitable[str]]] = None,
        max_session_messages: int = 50,
        max_user_memories: int = 100,
        auto_compact: bool = True,
    ):
        self.store = MemoryStoreV2(db_path)
        self.summarizer = MemorySummarizer(llm_func, max_session_messages, max_user_memories)
        self.deduplicator = MemoryDeduplicator()
        self.llm_func = llm_func
        self.max_session_messages = max_session_messages
        self.max_user_memories = max_user_memories
        self.auto_compact = auto_compact

    async def add_message(self, session_id: str, role: str, content: str) -> None:
        """Add message and trigger summarization if needed."""
        message = Message(role=role, content=content)
        await self.store.save_message(session_id, message)

        if self.auto_compact:
            await self._maybe_summarize_session(session_id)

    async def remember_user_fact(
        self,
        user_id: str,
        fact: str,
        category: str = "general",
        confidence: float = 1.0,
    ) -> MemoryEntry:
        """
        Remember a fact about the user with deduplication.
        """
        # Check for similar existing facts
        similar = await self.store.find_similar(fact, threshold=0.75)
        user_similar = [s for s in similar if s.user_id == user_id]

        if user_similar:
            # Update existing instead of creating duplicate
            existing = user_similar[0]
            existing.confidence = max(existing.confidence, confidence)
            existing.access_count += 1
            existing.updated_at = datetime.now()
            await self.store.save(existing)
            return existing

        # Create new entry
        entry = MemoryEntry(
            id=hashlib.sha256(f"{user_id}:{fact}".encode()).hexdigest()[:16],
            memory_type=MemoryType.USER,
            content=fact,
            metadata={"category": category},
            user_id=user_id,
            confidence=confidence,
        )
        await self.store.save(entry)

        if self.auto_compact:
            await self._maybe_compact_user_memories(user_id)

        return entry

    async def propose_learning(
        self,
        insight: str,
        category: str = "general",
        source: str = None,
        confidence: float = 0.8,
    ) -> MemoryEntry:
        """
        Propose a learning - persisted to DB until approved/rejected.
        """
        entry = MemoryEntry(
            id=hashlib.sha256(insight.encode()).hexdigest()[:16],
            memory_type=MemoryType.LEARNED,
            content=insight,
            metadata={"category": category, "source": source},
            confidence=confidence,
            approved=False,
        )

        # Persist to pending table (survives crashes!)
        await self.store.save_pending_learning(entry)
        return entry

    async def approve_learning(self, id: str) -> bool:
        """Approve a pending learning."""
        pending = await self.store.get_pending_learnings()
        for entry in pending:
            if entry.id == id:
                entry.approved = True
                await self.store.save(entry)
                await self.store.remove_pending_learning(id)
                return True
        return False

    async def reject_learning(self, id: str) -> bool:
        """Reject a pending learning."""
        return await self.store.remove_pending_learning(id)

    async def get_pending_learnings(self) -> list[MemoryEntry]:
        """Get all pending learnings (from DB, not memory)."""
        return await self.store.get_pending_learnings()

    async def recall(
        self,
        query: str = "",
        user_id: Optional[str] = None,
        memory_type: Optional[MemoryType] = None,
        limit: int = 10,
    ) -> list[MemoryEntry]:
        """
        Recall memories with relevance ranking.
        """
        entries = await self.store.search_relevant(
            query=query,
            memory_type=memory_type,
            user_id=user_id,
            limit=limit,
        )

        # Update access counts
        for entry in entries:
            entry.access_count += 1
            entry.last_accessed = datetime.now()

        return entries

    async def get_session_context(self, session_id: str, limit: int = 20) -> dict:
        """Get session context including summary of older messages."""
        messages = await self.store.get_messages(session_id, limit=limit)

        return {
            "messages": [m.to_dict() for m in messages],
            "message_count": len(messages),
        }

    async def build_context(
        self,
        session_id: str,
        user_id: Optional[str] = None,
        query: str = "",
    ) -> dict:
        """Build complete context for LLM."""
        context = {}

        # Session messages
        session = await self.get_session_context(session_id)
        context["conversation_history"] = session["messages"]

        # User facts (relevance-ranked)
        if user_id:
            user_memories = await self.recall(
                query=query,
                user_id=user_id,
                memory_type=MemoryType.USER,
                limit=10,
            )
            context["user_facts"] = [m.content for m in user_memories]

        # Learned insights (relevance-ranked)
        learned = await self.recall(
            query=query,
            memory_type=MemoryType.LEARNED,
            limit=5,
        )
        context["insights"] = [m.content for m in learned]

        return context

    async def compact(self, user_id: Optional[str] = None) -> dict:
        """
        Run compaction: summarize, deduplicate, archive.
        Returns stats about what was compacted.
        """
        stats = {
            "sessions_summarized": 0,
            "duplicates_merged": 0,
            "memories_archived": 0,
        }

        # Archive old memories
        archived = await self.store.archive_old(older_than_days=30)
        stats["memories_archived"] = archived

        # Deduplicate user memories
        if user_id:
            user_memories = await self.store.search_relevant(
                query="",
                memory_type=MemoryType.USER,
                user_id=user_id,
                limit=1000,
            )
            duplicates = self.deduplicator.find_duplicates(user_memories)

            for m1, m2, similarity in duplicates:
                merged = self.deduplicator.merge_memories(m1, m2)
                await self.store.save(merged)
                # Archive the other one
                m2.is_archived = True
                await self.store.save(m2)
                stats["duplicates_merged"] += 1

        return stats

    async def get_stats(self, user_id: Optional[str] = None) -> dict:
        """Get memory statistics."""
        return await self.store.get_memory_stats(user_id)

    async def _maybe_summarize_session(self, session_id: str) -> None:
        """Summarize session if it exceeds threshold."""
        messages = await self.store.get_messages(session_id, limit=self.max_session_messages + 10)

        if len(messages) > self.max_session_messages:
            # Summarize older messages
            to_summarize = messages[:-10]  # Keep last 10 unsummarized
            summary = await self.summarizer.summarize_session(to_summarize)

            if summary:
                # Save summary as a memory
                entry = MemoryEntry(
                    id=hashlib.sha256(f"{session_id}:{datetime.now().isoformat()}".encode()).hexdigest()[:16],
                    memory_type=MemoryType.SUMMARY,
                    content=summary,
                    metadata={"session_id": session_id, "message_count": len(to_summarize)},
                    session_id=session_id,
                )
                await self.store.save(entry)

    async def _maybe_compact_user_memories(self, user_id: str) -> None:
        """Compact user memories if they exceed threshold."""
        memories = await self.store.search_relevant(
            query="",
            memory_type=MemoryType.USER,
            user_id=user_id,
            limit=self.max_user_memories + 20,
        )

        if len(memories) > self.max_user_memories:
            # Consolidate
            consolidated = await self.summarizer.summarize_user_facts(memories)

            # Archive old, save consolidated
            for m in memories:
                if m.id not in [c.id for c in consolidated]:
                    m.is_archived = True
                    await self.store.save(m)

            for c in consolidated:
                await self.store.save(c)
