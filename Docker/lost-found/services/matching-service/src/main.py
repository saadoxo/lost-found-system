import json
import os
import threading
import time
from datetime import datetime, timedelta

import boto3
import psycopg2
import psycopg2.extras
from fastapi import FastAPI, Response

app = FastAPI(title="Matching Service", version="1.0.0")


def log(level: str, message: str, **kwargs):
    """Structured JSON to stdout — captured by CloudWatch."""
    entry = {
        "time": datetime.utcnow().isoformat(),
        "level": level,
        "service": "matching-service",
        "message": message,
    }
    entry.update(kwargs)
    print(json.dumps(entry), flush=True)


def get_db():
    return psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=int(os.environ.get("DB_PORT", 5432)),
        dbname=os.environ.get("DB_NAME", "lostfound"),
        user=os.environ.get("DB_USER", "lostfound"),
        password=os.environ["DB_PASSWORD"],
        sslmode="require",
        cursor_factory=psycopg2.extras.RealDictCursor,
    )


def score_match(new_item: dict, candidate: dict) -> float:
    """
    Score how likely two items are a match. Returns 0.0–1.0.
    Weights: category (40%), location keyword overlap (35%), date proximity (25%).
    """
    score = 0.0

    # Category must match exactly
    if new_item.get("category") != candidate.get("category"):
        return 0.0
    score += 0.40

    # Location: count shared words (case-insensitive)
    new_loc = set((new_item.get("location") or "").lower().split())
    cand_loc = set((candidate.get("location") or "").lower().split())
    if new_loc and cand_loc:
        overlap = len(new_loc & cand_loc) / max(len(new_loc), len(cand_loc))
        score += 0.35 * overlap

    # Date proximity: full score within 7 days, sliding to 0 at 30 days
    try:
        d1 = datetime.fromisoformat(str(new_item.get("date")))
        d2 = datetime.fromisoformat(str(candidate.get("date")))
        gap = abs((d1 - d2).days)
        if gap <= 7:
            score += 0.25
        elif gap <= 30:
            score += 0.25 * (1 - (gap - 7) / 23)
    except (TypeError, ValueError):
        pass

    return round(score, 3)


def find_matches(item: dict) -> list:
    """
    Query RDS for items of the opposite type in the same category
    within 30 days. Returns candidates scoring >= 0.5, best first.
    """
    opposite = "found" if item.get("type") == "lost" else "lost"
    cutoff = (datetime.utcnow() - timedelta(days=30)).date()

    try:
        conn = get_db()
        cur = conn.cursor()
        cur.execute(
            """
            SELECT id, type, title, category, location, date, user_id
            FROM items
            WHERE type = %s
              AND category = %s
              AND status = 'active'
              AND date >= %s
              AND id != %s
            LIMIT 50
            """,
            (opposite, item.get("category"), cutoff, item.get("id")),
        )
        candidates = cur.fetchall()
        cur.close()
        conn.close()
    except Exception as exc:
        log("error", "DB query failed", error=str(exc))
        return []

    results = []
    for candidate in candidates:
        s = score_match(item, dict(candidate))
        if s >= 0.5:
            results.append({"item": dict(candidate), "score": s})

    results.sort(key=lambda x: x["score"], reverse=True)
    return results[:5]


def publish_match_found(sqs, queue_url: str, new_item: dict, match: dict):
    payload = {
        "event": "match_found",
        "timestamp": datetime.utcnow().isoformat(),
        "data": {
            "lostItemId":  new_item["id"] if new_item.get("type") == "lost" else match["item"]["id"],
            "foundItemId": new_item["id"] if new_item.get("type") == "found" else match["item"]["id"],
            "score":       match["score"],
            "lostUserId":  new_item["user_id"] if new_item.get("type") == "lost" else match["item"]["user_id"],
            "foundUserId": new_item["user_id"] if new_item.get("type") == "found" else match["item"]["user_id"],
        },
    }
    sqs.send_message(QueueUrl=queue_url, MessageBody=json.dumps(payload))
    log("info", "match_found published",
        lostItemId=payload["data"]["lostItemId"],
        foundItemId=payload["data"]["foundItemId"],
        score=match["score"])


def process_item(item: dict):
    match_queue_url = os.environ.get("MATCH_FOUND_QUEUE_URL")
    if not match_queue_url:
        log("warn", "MATCH_FOUND_QUEUE_URL not set — skipping publish")
        return

    matches = find_matches(item)
    if not matches:
        log("info", "no matches found", itemId=item.get("id"))
        return

    sqs = boto3.client("sqs", region_name=os.environ.get("AWS_REGION", "us-east-1"))
    for match in matches:
        try:
            publish_match_found(sqs, match_queue_url, item, match)
        except Exception as exc:
            log("error", "failed to publish match_found", error=str(exc))


def consume_queue():
    queue_url = os.environ.get("ITEM_CREATED_QUEUE_URL")
    if not queue_url:
        log("info", "ITEM_CREATED_QUEUE_URL not set — consumer disabled (local dev)")
        return

    sqs = boto3.client("sqs", region_name=os.environ.get("AWS_REGION", "us-east-1"))
    log("info", "Matching service queue consumer started", queue=queue_url)

    while True:
        try:
            resp = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20,
            )
            for msg in resp.get("Messages", []):
                try:
                    body = json.loads(msg["Body"])
                    item_data = body.get("data", {})
                    log("info", "processing item",
                        itemId=item_data.get("id"),
                        itemType=item_data.get("type"),
                        category=item_data.get("category"))
                    process_item(item_data)
                    sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=msg["ReceiptHandle"])
                except Exception as exc:
                    log("error", "message processing failed", error=str(exc))
        except Exception as exc:
            log("error", "SQS receive error", error=str(exc))
            time.sleep(5)


@app.on_event("startup")
async def start_consumer():
    t = threading.Thread(target=consume_queue, daemon=True)
    t.start()


@app.get("/health")
def health():
    return {"status": "ok", "service": "matching-service"}


@app.get("/ready")
def ready():
    try:
        conn = get_db()
        conn.close()
        return {"status": "ready", "service": "matching-service"}
    except Exception as exc:
        log("warn", "ready check failed — DB not reachable", error=str(exc))
        return Response(content='{"status":"not ready"}', status_code=503, media_type="application/json")
