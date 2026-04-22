from fastapi import FastAPI

app = FastAPI(title="Matching Service", version="1.0.0")

@app.get("/health")
def health():
    return {"status": "ok", "service": "matching-service"}

@app.get("/ready")
def ready():
    # Will check SQS + DB connectivity in Phase 3
    return {"status": "ready", "service": "matching-service"}
