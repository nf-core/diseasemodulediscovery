FROM python:3.10.21-slim

LABEL image.author.name="Johannes Kersting"
LABEL image.author.email="johannes.kersting@tum.de"

ENV ROBUST_version="e8861de"

RUN apt-get update && \
  # apt-get installs and clean-up
  apt-get install -y --no-install-recommends \
    build-essential \
    git \
    procps && \
  # download ROBUST, pinned to a commit; the commit built into the published image was
  # force-pushed away upstream, but its sources are identical to this one
  git clone https://github.com/bionetslab/robust.git && \
  git -C robust checkout ${ROBUST_version} && \
  # install python dependencies
  pip install --no-cache-dir \
    numpy==1.22.4 \
    matplotlib==3.5.2 \
    pandas==1.4.2 \
    networkx==2.8.3 \
    pcst_fast==1.0.7 && \
  # remove build-only packages to keep the image lightweight
  apt-get purge -y --auto-remove build-essential && \
  rm -rf /var/lib/apt/lists/*
