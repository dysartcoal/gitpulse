"""Thin loader for config/topic-map.properties.

This is the consumer's copy of the single source of truth NiFi also reads
(via PropertiesFileLookupService) for GitHub event type -> Kafka topic
routing. Keeping one file read by both, rather than two independently
maintained mappings, is the point (see research.md / kafka-topic-contract.md).
"""

from __future__ import annotations

from pathlib import Path

DEFAULT_TOPIC_MAP_PATH = Path(__file__).resolve().parents[2] / "config" / "topic-map.properties"

_DEFAULT_KEY = "default"


def load_topic_map(path: Path = DEFAULT_TOPIC_MAP_PATH) -> dict[str, str]:
    """Parse a `key=value` properties file into a dict.

    Blank lines and lines starting with `#` are ignored. Raises ValueError
    if the file has no `default` entry - every topic map must define a
    fallback topic for event types it doesn't explicitly list.
    """
    mapping: dict[str, str] = {}
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        key, _, value = line.partition("=")
        mapping[key.strip()] = value.strip()

    if _DEFAULT_KEY not in mapping:
        raise ValueError(f"{path} has no '{_DEFAULT_KEY}' entry - a fallback topic is required")

    return mapping


class TopicMap:
    """The loaded event-type -> topic mapping, with a fallback for unknown types."""

    def __init__(self, path: Path = DEFAULT_TOPIC_MAP_PATH) -> None:
        self._mapping = load_topic_map(path)

    def topic_for(self, event_type: str) -> str:
        """Return the Kafka topic for a GitHub event `type`, or the fallback topic."""
        return self._mapping.get(event_type, self._mapping[_DEFAULT_KEY])

    @property
    def topics(self) -> frozenset[str]:
        """Every distinct topic named in the map, including the fallback."""
        return frozenset(self._mapping.values())
