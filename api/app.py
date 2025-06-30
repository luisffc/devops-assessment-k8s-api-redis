#!/usr/bin/env python3
"""
Simple Flask API with Redis caching for DevOps Assessment
"""

import logging
import os
from datetime import datetime

import redis
from flask import Flask, jsonify, request

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Redis configuration
REDIS_HOST = os.environ.get("REDIS_HOST", "localhost")
REDIS_PORT = int(os.environ.get("REDIS_PORT", 6379))
REDIS_PASSWORD = os.environ.get("REDIS_PASSWORD", None)
REDIS_PASSWORD_FILE = os.environ.get("REDIS_PASSWORD_FILE", None)
CACHE_TTL = int(os.environ.get("CACHE_TTL", 300))  # 5 minutes default

# Read Redis password from file if provided (AWS Secrets Manager)
if REDIS_PASSWORD_FILE and os.path.exists(REDIS_PASSWORD_FILE):
    try:
        with open(REDIS_PASSWORD_FILE, "r") as f:
            REDIS_PASSWORD = f.read().strip()
        logger.info("Redis password loaded from file")
    except Exception as e:
        logger.error(f"Failed to read Redis password from file: {e}")

# Initialize Redis connection
redis_client = None
try:
    logger.info(f"Attempting to connect to Redis at {REDIS_HOST}:{REDIS_PORT}")
    logger.info(f"Redis password provided: {'Yes' if REDIS_PASSWORD else 'No'}")

    redis_client = redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        password=REDIS_PASSWORD,
        decode_responses=True,
        socket_connect_timeout=5,
        socket_timeout=5,
        retry_on_timeout=True,
    )
    # Test connection
    redis_client.ping()
    logger.info(f"Successfully connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
except redis.ConnectionError as e:
    logger.error(f"Failed to connect to Redis: {e}")
    redis_client = None
except Exception as e:
    logger.error(f"Unexpected error connecting to Redis: {e}")
    redis_client = None


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint"""
    redis_status = "disconnected"
    redis_error = None

    if redis_client:
        try:
            redis_client.ping()
            redis_status = "connected"
        except Exception as e:
            redis_error = str(e)
            logger.error(f"Redis ping failed: {e}")

    response_data = {
        "status": "healthy",
        "timestamp": datetime.utcnow().isoformat(),
        "redis_status": redis_status,
        "redis_host": REDIS_HOST,
        "redis_port": REDIS_PORT,
        "redis_password_set": bool(REDIS_PASSWORD),
        "version": "1.0.0",
    }

    if redis_error:
        response_data["redis_error"] = redis_error

    return (
        jsonify(response_data),
        200,
    )


@app.route("/store", methods=["POST"])
def store_key_value():
    """Store key-value pair in Redis"""
    if not redis_client:
        return jsonify({"error": "Redis not available"}), 503

    try:
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON payload provided"}), 400

        key = data.get("key")
        value = data.get("value")

        if not key or value is None:
            return jsonify({"error": 'Both "key" and "value" are required'}), 400

        # Store in Redis
        redis_client.set(key, value)
        logger.info(f"Stored key '{key}' with value '{value}'")

        return (
            jsonify(
                {
                    "message": "Key-value pair stored successfully",
                    "key": key,
                    "value": value,
                    "timestamp": datetime.utcnow().isoformat(),
                }
            ),
            200,
        )

    except redis.RedisError as e:
        logger.error(f"Redis error while storing key-value: {e}")
        return jsonify({"error": "Failed to store key-value pair"}), 500
    except Exception as e:
        logger.error(f"Error processing request: {e}")
        return jsonify({"error": "Invalid request"}), 400


@app.route("/keys", methods=["GET"])
def get_keys():
    """Get all Redis keys"""
    if not redis_client:
        return jsonify({"error": "Redis not available"}), 503

    try:
        keys = redis_client.keys("*")
        logger.info(f"Retrieved {len(keys)} keys from Redis")

        return (
            jsonify(
                {
                    "keys": keys,
                    "count": len(keys),
                    "timestamp": datetime.utcnow().isoformat(),
                }
            ),
            200,
        )

    except redis.RedisError as e:
        logger.error(f"Redis error while retrieving keys: {e}")
        return jsonify({"error": "Failed to retrieve keys"}), 500


@app.route("/debug", methods=["GET"])
def debug_config():
    """Debug endpoint to show configuration (for troubleshooting only)"""
    return jsonify(
        {
            "redis_host": REDIS_HOST,
            "redis_port": REDIS_PORT,
            "redis_password_set": bool(REDIS_PASSWORD),
            "redis_password_file": REDIS_PASSWORD_FILE,
            "cache_ttl": CACHE_TTL,
            "redis_client_exists": redis_client is not None,
            "environment_vars": {
                k: v
                for k, v in os.environ.items()
                if k.startswith(("REDIS_", "CACHE_", "DEBUG"))
            },
        }
    )


@app.errorhandler(404)
def not_found(error):
    return jsonify({"error": "Endpoint not found"}), 404


@app.errorhandler(500)
def internal_error(error):
    return jsonify({"error": "Internal server error"}), 500


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    debug = os.environ.get("DEBUG", "False").lower() == "true"

    logger.info(f"Starting API server on port {port}")
    app.run(host="0.0.0.0", port=port, debug=debug)
