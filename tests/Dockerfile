ARG UBUNTU_IMAGE=ubuntu:latest
FROM ${UBUNTU_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install --yes --no-install-recommends \
        bash \
        gcc \
        libc6-dev \
        python3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
COPY examples /work/examples
COPY tests/run.py /work/tests/run.py

ENTRYPOINT ["python3", "/work/tests/run.py"]
