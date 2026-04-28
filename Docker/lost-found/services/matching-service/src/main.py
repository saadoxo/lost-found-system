from fastapi import FastAPI
import asyncio, threading, logging, json, os, boto3
from datetime import datetime

app = FastAPI(title="Matching Service", version="1.0.0")
logger = logging.getLogger(__name__)

@app.get("/health")
def health():
    return {"status": "ok", "service": "matching-service"}

@app.get("/ready")
def ready():
    return {"status": "ready", "service": "matching-service"}

@app.on_event("startup")
async def start_consumer():
    thread = threading.Thread(target=consume_queue, daemon=True)
    thread.start()

def consume_queue():
    queue_url = os.environ.get("ITEM_CREATED_QUEUE_URL")
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
                    process_item(body.get("data", {}))
                    sqs.delete_message(
                        QueueUrl=queue_url,
                        ReceiptHandle=message["ReceiptHandle"]
                    )
                except Exception as e:
                    logger.error(f"Failed to process message: {e}")
        except Exception as e:
            logger.error(f"SQS receive error: {e}")
            import time; time.sleep(5)

def process_item(item):
    """
    Matching algorithm placeholder.
    Receives an item_created event and finds potential matches.
    Full implementation: query DB for items of opposite type,
    same category, similar location/date, score them, publish match_found.
    """
    logger.info(f"Processing item for matching: id={item.get('id')} type={item.get('type')}")
    # TODO: implement matching logic in Phase 3C