from python:3.8-slim

run apt-get update && \
  # apt-get installs and clean-up
  apt-get install -y --no-install-recommends \
    git \
    procps && \
  rm -rf /var/lib/apt/lists/* && \
  # download DIAMOnD
  git clone https://github.com/dinaghiassian/DIAMOnD.git && \
  # install python dependencies
  pip install --no-cache-dir \
    networkx \
    scipy \
    numpy
