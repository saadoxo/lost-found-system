import json
import logging
import os
import threading
import time

import boto3
from fastapi import FastAPI

logging.basicConfig(
    level=logging.INFO,
    format='{"time": "%(asctime)s", "level": "%(levelname)s", "service": "notification-service", "message": "%(message)s"}'
)
logger = logging.getLogger(__name__)

app = FastAPI(title="Notification Service", version="1.0.0")

# Email sender — must be verified in SES
SENDER_EMAIL = os.environ.get("SENDER_EMAIL", "noreply@lostfound.internal")


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


def lookup_user_email(user_id: str) -> str | None:
    """
    Fetch user email from the auth service via internal ALB.
    Falls back to None if the internal ALB isn't reachable (local dev).
    """
    internal_alb = os.environ.get("INTERNAL_ALB_DNS")
    if not internal_alb:
        return None

    import urllib.request
    import urllib.error

    try:
        url = f"http://{internal_alb}/auth/users/{user_id}/email"
        with urllib.request.urlopen(url, timeout=3) as resp:
            data = json.loads(resp.read())
            return data.get("email")
    except Exception as exc:
        logger.warning(f"Could not fetch email for user {user_id}: {exc}")
        return None


def handle_match_found(match_data: dict):
    """
    Sends email notifications to both the lost-item owner and the found-item owner
    when the matching service detects a potential match.
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
            logger.warning(f"No email for user {user_id} — skipping notification")
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
            logger.info(f"Email sent to user {user_id} ({role}) for match lost={lost_item_id} found={found_item_id}")
        except ses.exceptions.MessageRejected as exc:
            logger.error(f"SES rejected email for {user_id}: {exc}")
        except Exception as exc:
            logger.error(f"Failed to send email for {user_id}: {exc}")


def consume_queue():
    queue_url = os.environ.get("MATCH_FOUND_QUEUE_URL")
    if not queue_url:
        logger.info("MATCH_FOUND_QUEUE_URL not set — queue consumer disabled (local dev)")
        return

    sqs = boto3.client("sqs", region_name=os.environ.get("AWS_REGION", "us-east-1"))
    logger.info("Notification service queue consumer started")

    while True:
        try:
            resp = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20,
            )
            for msg in resp.get("Messages", []):
                try:
                    # Messages from SNS are wrapped in an envelope
                    outer = json.loads(msg["Body"])
                    # SNS wraps the payload in a "Message" string field
                    if "Message" in outer:
                        inner = json.loads(outer["Message"])
                    else:
                        inner = outer

                    match_data = inner.get("data", {})
                    logger.info(f"Received match_found event: lost={match_data.get('lostItemId')} found={match_data.get('foundItemId')}")
                    handle_match_found(match_data)
                    sqs.delete_message(QueueUrl=queue_url, ReceiptHandle=msg["ReceiptHandle"])
                except Exception as exc:
                    logger.error(f"Message processing failed: {exc}")
        except Exception as exc:
            logger.error(f"SQS receive error: {exc}")
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
