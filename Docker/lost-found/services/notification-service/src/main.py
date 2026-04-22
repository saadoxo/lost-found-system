from fastapi import FastAPI

app = FastAPI(title="Notification Service", version="1.0.0")

@app.get("/health")
def health():
    return {"status": "ok", "service": "notification-service"}

@app.get("/ready")
def ready():
    # Will check SQS + SES connectivity in Phase 3
    return {"status": "ready", "service": "notification-service"}
