from python:3.7-slim

run apt-get update && \
  # apt-get installs and clean-up
  apt-get install -y --no-install-recommends \
    build-essential \
    git \
    procps && \
  # download ROBUST
  git clone --depth 1 https://github.com/bionetslab/robust.git && \
  # install python dependencies
  pip install --no-cache-dir \
    numpy \
    matplotlib \
    pandas \
    networkx \
    pcst_fast && \
  # remove build-only packages to keep the image lightweight
  apt-get purge -y --auto-remove build-essential && \
  rm -rf /var/lib/apt/lists/*
