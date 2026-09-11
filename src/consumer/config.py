"""Consumer configuration, sourced from environment variables.

No GITHUB_TOKEN handling here: the consumer never calls the GitHub API,
only Kafka. The PAT belongs to NiFi's InvokeHTTP call (see T009's
nifi/flow/github-events-flow.xml) - passed through docker-compose.yml
straight to the NiFi container, never through the consumer.
"""

from __future__ import annotations

import os
from dataclasses import dataclass

from consumer.topic_map import TopicMap


@dataclass(frozen=True)
class ConsumerConfig:
    bootstrap_servers: str
    consumer_group: str
    topics: frozenset[str]
    poll_timeout_seconds: float


def load_config() -> ConsumerConfig:
    return ConsumerConfig(
        bootstrap_servers=os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),
        consumer_group=os.environ.get("KAFKA_CONSUMER_GROUP", "gitpulse-ingestion"),
        topics=TopicMap().topics,
        poll_timeout_seconds=float(os.environ.get("CONSUMER_POLL_TIMEOUT_SECONDS", "1.0")),
    )
