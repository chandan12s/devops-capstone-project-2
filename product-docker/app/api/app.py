from flask import Flask, jsonify, request
import time
import os
import logging

logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s %(message)s')
logger = logging.getLogger(__name__)

app = Flask(__name__)

APP_VERSION = os.environ.get("APP_VERSION", "1.0.0")
ENVIRONMENT = os.environ.get("ENVIRONMENT", "dev")

analytics_store = {"events": [], "total_processed": 0}

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy", "version": APP_VERSION, "env": ENVIRONMENT}), 200

@app.route("/ready", methods=["GET"])
def ready():
    return jsonify({"status": "ready"}), 200

@app.route("/api/v1/events", methods=["POST"])
def ingest_event():
    data = request.get_json()
    if not data or "event_type" not in data:
        return jsonify({"error": "event_type is required"}), 400
    event = {
        "id": len(analytics_store["events"]) + 1,
        "event_type": data["event_type"],
        "payload": data.get("payload", {}),
        "timestamp": time.time(),
        "processed_by": f"api-{ENVIRONMENT}"
    }
    analytics_store["events"].append(event)
    analytics_store["total_processed"] += 1
    logger.info(f"Ingested event: {event['event_type']} id={event['id']}")
    return jsonify({"status": "accepted", "event_id": event["id"]}), 201

@app.route("/api/v1/events", methods=["GET"])
def get_events():
    return jsonify({"total": analytics_store["total_processed"], "events": analytics_store["events"][-10:]}), 200

@app.route("/api/v1/stats", methods=["GET"])
def get_stats():
    event_types = {}
    for e in analytics_store["events"]:
        t = e["event_type"]
        event_types[t] = event_types.get(t, 0) + 1
    return jsonify({"total_events": analytics_store["total_processed"], "by_type": event_types, "environment": ENVIRONMENT, "version": APP_VERSION}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
