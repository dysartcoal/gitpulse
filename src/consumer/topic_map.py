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
    """The loaded event-type -> topic mapping, with a fallback for unknown types.

    A thin object rather than a bare dict so callers get `topic_for`'s
    guaranteed-fallback lookup (never a KeyError on an unrecognized type) and
    the `topics` property, both without re-deriving the fallback logic at
    every call site.
    """

    def __init__(self, path: Path = DEFAULT_TOPIC_MAP_PATH) -> None:
        self._mapping = load_topic_map(path)

    def topic_for(self, event_type: str) -> str:
        """Return the Kafka topic for a GitHub event `type`, or the fallback topic.

        Never raises for an unrecognized type - data-model.md requires that
        an unrecognized-but-well-formed event still gets persisted somewhere,
        not dropped, so a lookup miss falls through to the fallback topic
        rather than propagating a KeyError up to the caller.
        """
        return self._mapping.get(event_type, self._mapping[_DEFAULT_KEY])

    @property
    def topics(self) -> frozenset[str]:
        """Every distinct topic named in the map, including the fallback.

        Used by infra/create_topics.py to know the full set of topics to
        create up front, and by the consumer to know what to subscribe to -
        both need the fallback topic included, or an unrecognized event type
        would route to a topic that was never created.
        """
        return frozenset(self._mapping.values())
