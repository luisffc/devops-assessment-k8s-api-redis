# Single-stage build for reliability
FROM python:3.13.5-slim

# Security: Update system packages
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Security: Create non-root user with specific UID/GID and home directory
RUN groupadd -r appuser -g 1000 && \
    useradd -r -g appuser -u 1000 -m -d /app -s /bin/bash appuser

# Set working directory
WORKDIR /app

# Security: Change ownership to appuser
RUN chown -R appuser:appuser /app

# Copy requirements first for better caching
COPY --chown=appuser:appuser requirements.txt .

# Security: Install packages as non-root user
USER appuser
RUN pip install --no-cache-dir --upgrade pip==25.1 && \
    pip install --no-cache-dir --user -r requirements.txt

# Add user's local bin to PATH
ENV PATH="/app/.local/bin:${PATH}"

# Copy application code
COPY --chown=appuser:appuser app.py .

# Expose non-root port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')" || exit 1

# Run the application with gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "--workers", "4", "--timeout", "30", "--keep-alive", "2", "--max-requests", "1000", "--max-requests-jitter", "100", "app:app"]
