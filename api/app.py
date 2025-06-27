#!/usr/bin/env python3
"""
Simple Flask API with Redis caching for DevOps Assessment
"""

import logging
import os
from datetime import datetime, timezone

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
CACHE_TTL = int(os.environ.get("CACHE_TTL", 300))  # 5 minutes default

# Initialize Redis connection with retry logic
redis_client = None
redis_connection_error = None


def connect_to_redis():
    """Attempt to connect to Redis with error details"""
    global redis_client, redis_connection_error

    try:
        logger.info(f"Attempting to connect to Redis at {REDIS_HOST}:{REDIS_PORT}")
        logger.info(f"Redis password provided: {'Yes' if REDIS_PASSWORD else 'No'}")

        client = redis.Redis(
            host=REDIS_HOST,
            port=REDIS_PORT,
            password=REDIS_PASSWORD if REDIS_PASSWORD else None,
            decode_responses=True,
            socket_connect_timeout=5,
            socket_timeout=5,
            retry_on_timeout=True,
        )
        # Test connection
        client.ping()
        logger.info(f"Successfully connected to Redis at {REDIS_HOST}:{REDIS_PORT}")
        redis_client = client
        redis_connection_error = None
        return True
    except redis.ConnectionError as e:
        error_msg = f"Failed to connect to Redis: {e}"
        logger.error(error_msg)
        redis_connection_error = error_msg
        redis_client = None
        return False
    except Exception as e:
        error_msg = f"Unexpected error connecting to Redis: {e}"
        logger.error(error_msg)
        redis_connection_error = error_msg
        redis_client = None
        return False


# Try initial connection
connect_to_redis()


@app.route("/health", methods=["GET"])
def health_check():
    """Health check endpoint"""
    redis_status = "disconnected"
    redis_error = None

    # If redis_client doesn't exist, try to connect
    if not redis_client:
        connect_to_redis()

    if redis_client:
        try:
            redis_client.ping()
            redis_status = "connected"
        except Exception as e:
            redis_error = str(e)
            logger.error(f"Redis ping failed: {e}")
            # Try to reconnect on ping failure
            connect_to_redis()

    response_data = {
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "redis_status": redis_status,
        "redis_host": REDIS_HOST,
        "redis_port": REDIS_PORT,
        "redis_password_set": bool(REDIS_PASSWORD),
        "version": "1.0.0",
    }

    if redis_error:
        response_data["redis_error"] = redis_error
    if redis_connection_error:
        response_data["redis_connection_error"] = redis_connection_error

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
                    "timestamp": datetime.now(timezone.utc).isoformat(),
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
                    "timestamp": datetime.now(timezone.utc).isoformat(),
                }
            ),
            200,
        )

    except redis.RedisError as e:
        logger.error(f"Redis error while retrieving keys: {e}")
        return jsonify({"error": "Failed to retrieve keys"}), 500
