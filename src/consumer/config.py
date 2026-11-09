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
    """Immutable once loaded (frozen=True) - config shouldn't change mid-run
    under a running consumer; a fresh process picks up any new env vars.
    """

    bootstrap_servers: str
    consumer_group: str
    topics: frozenset[str]
    poll_timeout_seconds: float


def load_config() -> ConsumerConfig:
    """Read consumer settings from the environment, with local-dev defaults
    that work out of the box against infra/docker-compose.yml.
    """
    return ConsumerConfig(
        # localhost:9092 matches docker-compose.yml's Kafka port mapping - the
        # consumer is expected to run on the host, not inside the compose
        # network, so it reaches Kafka the same way a developer's shell would.
        bootstrap_servers=os.environ.get("KAFKA_BOOTSTRAP_SERVERS", "localhost:9092"),
        # One fixed group name (not per-instance) so multiple consumer
        # processes would share partition assignment and offsets rather than
        # each independently re-reading every message from the start.
        consumer_group=os.environ.get("KAFKA_CONSUMER_GROUP", "gitpulse-ingestion"),
        # Sourced from TopicMap (T007), not redeclared here, so the set of
        # topics this consumer subscribes to can't drift out of sync with
        # config/topic-map.properties.
        topics=TopicMap().topics,
        # 1 second: short enough that a stop/restart (quickstart.md scenario
        # 3) doesn't feel sluggish, long enough not to busy-loop the consumer
        # thread between polls when Kafka has nothing new to deliver.
        poll_timeout_seconds=float(os.environ.get("CONSUMER_POLL_TIMEOUT_SECONDS", "1.0")),
    )
