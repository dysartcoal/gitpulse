"""Structured logging setup for the consumer.

Emits one JSON object per log line so log volume/warning signals (e.g.
a future "poll returned exactly 300 events" counterpart on the consumer
side, or idempotency duplicate-drop counts) are easy to grep or ship to
a log aggregator, rather than parsing free-text messages.
"""

from __future__ import annotations

import json
import logging
import sys
from datetime import UTC, datetime


class JsonFormatter(logging.Formatter):
    """One JSON object per log record - see module docstring for why.

    timestamp is explicit UTC (not the log line's implicit local time) so
    log lines are comparable across the consumer and NiFi containers
    regardless of the host machine's timezone.
    """

    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }
        # Only present when there's an actual exception, so a normal log line
        # doesn't carry a redundant null/empty field - keeps grep/aggregator
        # output clean for the overwhelming majority of non-error lines.
        if record.exc_info:
            payload["exc_info"] = self.formatException(record.exc_info)
        return json.dumps(payload)


def configure_logging(level: str = "INFO") -> None:
    """Route all logging through one JSON stdout handler.

    Replaces root.handlers outright (rather than appending) so calling this
    more than once in a process - e.g. if a future entrypoint or a test
    imports and configures logging twice - can't leave duplicate handlers
    behind that would print every log line more than once.
    """
    handler = logging.StreamHandler(sys.stdout)
    handler.setFormatter(JsonFormatter())

    root = logging.getLogger()
    root.setLevel(level)
    root.handlers = [handler]
