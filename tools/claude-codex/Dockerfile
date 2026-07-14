FROM ghcr.io/berriai/litellm:v1.91.2

COPY patch_litellm.py /tmp/patch_litellm.py
RUN python /tmp/patch_litellm.py && rm /tmp/patch_litellm.py
