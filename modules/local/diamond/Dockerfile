FROM python:3.8.20-slim

LABEL image.author.name="Johannes Kersting"
LABEL image.author.email="johannes.kersting@tum.de"

ENV DIAMOnD_version="2437974"

RUN apt-get update && \
  # apt-get installs and clean-up
  apt-get install -y --no-install-recommends \
    git \
    procps && \
  rm -rf /var/lib/apt/lists/* && \
  # download DIAMOnD, pinned to the commit used by the published image
  git clone https://github.com/dinaghiassian/DIAMOnD.git && \
  git -C DIAMOnD checkout ${DIAMOnD_version} && \
  # install python dependencies
  pip install --no-cache-dir \
    networkx==2.5 \
    scipy==1.5.2 \
    numpy==1.19.2
