"""Idempotently create the Kafka topics named in config/topic-map.properties.

Run once against the broker from infra/docker-compose.yml:

    python infra/create_topics.py [--bootstrap-servers localhost:9092]

One partition, replication factor 1 - matching the single-broker setup
(ADR-0005). Explicit creation rather than relying on Kafka's
auto-create-on-publish default, so partition count and replication are a
deliberate, documented choice (T008).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from confluent_kafka.admin import AdminClient, NewTopic
from confluent_kafka.error import KafkaError

# Allow running this script directly (`python infra/create_topics.py`) without
# requiring `pip install -e .` first.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from consumer.topic_map import TopicMap  # noqa: E402


def create_topics(bootstrap_servers: str) -> None:
    admin = AdminClient({"bootstrap.servers": bootstrap_servers})
    topics = sorted(TopicMap().topics)

    new_topics = [NewTopic(name, num_partitions=1, replication_factor=1) for name in topics]
    futures = admin.create_topics(new_topics)

    for topic, future in futures.items():
        try:
            future.result()
            print(f"created topic: {topic}")
        except Exception as exc:  # confluent-kafka raises KafkaException
            error = getattr(exc, "args", [None])[0]
            if error and error.code() == KafkaError.TOPIC_ALREADY_EXISTS:
                print(f"topic already exists, skipping: {topic}")
            else:
                raise


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--bootstrap-servers",
        default="localhost:9092",
        help="Kafka bootstrap servers (default: localhost:9092)",
    )
    args = parser.parse_args()
    create_topics(args.bootstrap_servers)


if __name__ == "__main__":
    main()
