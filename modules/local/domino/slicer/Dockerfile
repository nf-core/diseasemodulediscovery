from python:3.9.25-slim

run apt-get update && \
  # apt-get installs and clean-up
  apt-get install -y --no-install-recommends \
    procps && \
  rm -rf /var/lib/apt/lists/* && \
  # pin pip to the version used in the modulediscovery mamba environment
  pip install --no-cache-dir pip==25.3 && \
  # install python dependencies with prebuilt wheels first, so pip doesn't
  # try to resolve domino-python's own pin down to numpy==1.18.1, which has
  # no wheel for this python version and fails to build from source
  pip install --no-cache-dir \
    networkx==2.4 \
    numpy==1.22.0 \
    scipy==1.9.3 \
    pandas==1.5.1 \
    pcst-fast==1.0.7 \
    statsmodels==0.13.0 \
    python-louvain==0.14 && \
  # install DOMINO from PyPI, skipping its own dependency resolution
  pip install --no-cache-dir --no-deps domino-python==0.1.1
