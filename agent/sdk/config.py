"""
Configuration management for Sol Unified Agent.

Loads config from ~/.config/solunified/agent.toml
"""

import os
from pathlib import Path
from dataclasses import dataclass, field
from typing import Optional

try:
    import tomli
except ImportError:
    tomli = None


@dataclass
class APIConfig:
    """Sol Unified API configuration."""
    sol_unified_url: str = "http://localhost:7654"
    timeout_seconds: int = 30


@dataclass
class AgentConfig:
    """Claude agent configuration."""
    model: str = "claude-sonnet-4-20250514"
    max_tokens: int = 4096
    temperature: float = 0.7


@dataclass
class DaemonConfig:
    """Background daemon configuration."""
    check_interval_minutes: int = 15
    prep_lead_time_hours: int = 2
    max_concurrent_preps: int = 3


@dataclass
class MeetingPrepConfig:
    """Meeting prep workflow configuration."""
    include_web_research: bool = True
    include_clipboard_context: bool = True
    brief_max_length: int = 2000


@dataclass
class LoggingConfig:
    """Logging configuration."""
    level: str = "INFO"
    file: Optional[str] = "/tmp/solunified-agent.log"


@dataclass
class Config:
    """Main configuration container."""
    api: APIConfig = field(default_factory=APIConfig)
    agent: AgentConfig = field(default_factory=AgentConfig)
    daemon: DaemonConfig = field(default_factory=DaemonConfig)
    meeting_prep: MeetingPrepConfig = field(default_factory=MeetingPrepConfig)
    logging: LoggingConfig = field(default_factory=LoggingConfig)

    @classmethod
    def load(cls, config_path: Optional[Path] = None) -> "Config":
        """Load configuration from TOML file."""
        if config_path is None:
            config_path = Path.home() / ".config" / "solunified" / "agent.toml"

        config = cls()

        if config_path.exists() and tomli is not None:
            with open(config_path, "rb") as f:
                data = tomli.load(f)

            # Load API config
            if "api" in data:
                for key, value in data["api"].items():
                    if hasattr(config.api, key):
                        setattr(config.api, key, value)

            # Load agent config
            if "agent" in data:
                for key, value in data["agent"].items():
                    if hasattr(config.agent, key):
                        setattr(config.agent, key, value)

            # Load daemon config
            if "daemon" in data:
                for key, value in data["daemon"].items():
                    if hasattr(config.daemon, key):
                        setattr(config.daemon, key, value)

            # Load meeting prep config
            if "meeting_prep" in data:
                for key, value in data["meeting_prep"].items():
                    if hasattr(config.meeting_prep, key):
                        setattr(config.meeting_prep, key, value)

            # Load logging config
            if "logging" in data:
                for key, value in data["logging"].items():
                    if hasattr(config.logging, key):
                        setattr(config.logging, key, value)

        # Override with environment variables
        if os.environ.get("SOL_API_URL"):
            config.api.sol_unified_url = os.environ["SOL_API_URL"]

        return config


# Global config instance
_config: Optional[Config] = None


def get_config() -> Config:
    """Get the global configuration instance."""
    global _config
    if _config is None:
        _config = Config.load()
    return _config


def reload_config() -> Config:
    """Reload configuration from disk."""
    global _config
    _config = Config.load()
    return _config
