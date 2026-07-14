FROM ghcr.io/berriai/litellm:v1.91.2

COPY rate_limit_callback.py /app/rate_limit_callback.py
COPY patch_litellm.py /tmp/patch_litellm.py
RUN python /tmp/patch_litellm.py && rm /tmp/patch_litellm.py
