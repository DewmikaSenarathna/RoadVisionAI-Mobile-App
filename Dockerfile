FROM python:3.11-slim

# Avoid prompts from apt
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

WORKDIR /app

# Install minimal build deps as a fallback, keep image small
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
 && rm -rf /var/lib/apt/lists/*

# Copy and install dependencies. Try to use wheels first, fall back to source if needed.
COPY requirements.txt ./
RUN python -V && pip install --upgrade pip setuptools wheel && \
    pip install --only-binary :all: -r requirements.txt || pip install -r requirements.txt

# Copy application
COPY . /app

EXPOSE 10000

# Use environment PORT provided by Render. Default to 10000 locally.
ENV PORT=10000

CMD ["/bin/sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
