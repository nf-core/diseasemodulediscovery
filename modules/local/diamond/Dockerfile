from python:3.8.20-slim

run apt-get update && \
  # apt-get installs and clean-up
  apt-get install -y --no-install-recommends \
    git \
    procps && \
  rm -rf /var/lib/apt/lists/* && \
  # download DIAMOnD, pinned to the commit used by the published image
  git clone https://github.com/dinaghiassian/DIAMOnD.git && \
  git -C DIAMOnD checkout 2437974 && \
  # install python dependencies
  pip install --no-cache-dir \
    networkx==2.5 \
    scipy==1.5.2 \
    numpy==1.19.2
