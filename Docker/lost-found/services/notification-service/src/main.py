import json
import os
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime

import boto3
from fastapi import FastAPI

app = FastAPI(title="Notification Service", version="1.0.0")

SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "noreply@lostfound.internal")


def log(level: str, message: str, **kwargs):
    """Structured JSON to stdout — captured by CloudWatch."""
    entry = {
        "time": datetime.utcnow().isoformat(),
        "level": level,
        "service": "notification-service",
        "message": message,
    }
    entry.update(kwargs)
    print(json.dumps(entry), flush=True)


def lookup_user_email(user_id: str) -> str | None:
    """
    Fetch user email from auth-service via the internal ALB.
    Returns None if unreachable (local dev or ALB not set).
    """
    internal_alb = os.environ.get("INTERNAL_ALB_DNS")
    if not internal_alb:
        return None
    try:
        url = f"http://{internal_alb}/auth/users/{user_id}/email"
        with urllib.request.urlopen(url, timeout=3) as resp:
            data = json.loads(resp.read())
            return data.get("email")
    except Exception as exc:
        log("warn", "could not fetch user email", userId=user_id, error=str(exc))
        return None


def send_email(ses, to_address: str, subject: str, body_text: str, body_html: str):
    ses.send_email(
        Source=SENDER_EMAIL,
        Destination={"ToAddresses": [to_address]},
        Message={
            "Subject": {"Data": subject, "Charset": "UTF-8"},
            "Body": {
                "Text": {"Data": body_text, "Charset": "UTF-8"},
                "Html": {"Data": body_html, "Charset": "UTF-8"},
            },
        },
    )


def handle_match_found(match_data: dict):
    """
    Send email to both item owners when a match is detected.
    Skips silently if email lookup fails (no internal ALB in local dev).
    """
    region = os.environ.get("AWS_REGION", "us-east-1")
    ses = boto3.client("ses", region_name=region)

    lost_item_id  = match_data.get("lostItemId", "unknown")
    found_item_id = match_data.get("foundItemId", "unknown")
    score         = match_data.get("score", 0)
    lost_user_id  = match_data.get("lostUserId")
    found_user_id = match_data.get("foundUserId")

    subject = "Lost & Found — Potential Match Found"

    for user_id, role, other_id in [
        (lost_user_id,  "lost",  found_item_id),
        (found_user_id, "found", lost_item_id),
    ]:
        if not user_id:
            continue

        email = lookup_user_email(user_id)
        if not email:
            log("warn", "no email for user — skipping notification", userId=user_id)
            continue

        body_text = (
            f"Good news! We found a potential match for your {role} item.\n\n"
            f"Match confidence: {int(score * 100)}%\n"
            f"Your item ID: {lost_item_id if role == 'lost' else found_item_id}\n"
            f"Matched with item ID: {other_id}\n\n"
            f"Log in to review the match and initiate a claim."
        )
        body_html = f"""
        <html><body>
        <h2>Potential Match Found</h2>
        <p>We found a potential match for your <strong>{role}</strong> item.</p>
        <ul>
            <li>Match confidence: <strong>{int(score * 100)}%</strong></li>
            <li>Your item ID: {lost_item_id if role == 'lost' else found_item_id}</li>
            <li>Matched with item ID: {other_id}</li>
        </ul>
        <p>Log in to review the match and initiate a claim.</p>
        </body></html>
        """

        try:
            send_email(ses, email, subject, body_text, body_html)
            log("info", "email sent", userId=user_id, role=role,
                lostItemId=lost_item_id, foundItemId=found_item_id)
        except Exception as exc:
            log("error", "SES send failed", userId=user_id, error=str(exc))


def consume_queue():
    queue_url = os.environ.get("MATCH_FOUND_QUEUE_URL")
    if not queue_url:
        log("info", "MATCH_FOUND_QUEUE_URL not set — consumer disabled (local dev)")
        return

    sqs = boto3.client("sqs", region_name=os.environ.get("AWS_REGION", "us-east-1"))
    log("info", "Notification service queue consumer started", queue=queue_url)

    while True:
        try:
            resp = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20,
            )
            for msg in resp.get("Messages", []):
                try:
                    # SNS wraps the payload in an outer envelope with a "Message" field
                    outer = json.loads(msg["Body"])
                    inner = json.loads(outer["Message"]) if "Message" in outer else outer
                    match_data = inner.get("data", {})
                    log("info", "received match_found event",
                        lostItemId=match_data.get("lostItemId"),
                        foundItemId=match_data.get("foundItemId"),
                        score=match_data.get("score"))
                    handle_match_found(match_data)
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
    return {"status": "ok", "service": "notification-service"}


@app.get("/ready")
def ready():
    return {"status": "ready", "service": "notification-service"}
