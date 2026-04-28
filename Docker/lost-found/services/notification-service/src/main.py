from fastapi import FastAPI
import threading, logging, json, os, boto3

app = FastAPI(title="Notification Service", version="1.0.0")
logger = logging.getLogger(__name__)

@app.get("/health")
def health():
    return {"status": "ok", "service": "notification-service"}

@app.get("/ready")
def ready():
    return {"status": "ready", "service": "notification-service"}

@app.on_event("startup")
async def start_consumer():
    thread = threading.Thread(target=consume_queue, daemon=True)
    thread.start()

def consume_queue():
    queue_url = os.environ.get("MATCH_FOUND_QUEUE_URL")
    if not queue_url:
        logger.info("No SQS queue URL set — running without queue consumer (local dev)")
        return

    sqs = boto3.client("sqs", region_name=os.environ.get("AWS_REGION", "us-east-1"))

    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=queue_url,
                MaxNumberOfMessages=10,
                WaitTimeSeconds=20
            )
            for message in response.get("Messages", []):
                try:
                    body = json.loads(message["Body"])
                    send_notification(body.get("data", {}))
                    sqs.delete_message(
                        QueueUrl=queue_url,
                        ReceiptHandle=message["ReceiptHandle"]
                    )
                except Exception as e:
                    logger.error(f"Failed to process notification: {e}")
        except Exception as e:
            logger.error(f"SQS receive error: {e}")
            import time; time.sleep(5)

def send_notification(match_data):
    """
    Sends email via AWS SES when a match is found.
    Full implementation: load email template, call SES SendEmail.
    """
    logger.info(f"Sending notification for match: {match_data}")
    # TODO: implement SES email sending in Phase 3C