FROM ubuntu:20.04

# author: Ole Schuett

# Install Ubuntu packages.
RUN export DEBIAN_FRONTEND=noninteractive DEBCONF_NONINTERACTIVE_SEEN=true && \
    apt-get update && apt-get install -y --no-install-recommends \
    clang-format \
    git \
    less \
    python3 \
    python3-pip \
    python3-wheel \
    python3-setuptools \
    rubygems \
    shellcheck \
    vim \
  && rm -rf /var/lib/apt/lists/*

# Install Markdownlint.
RUN gem install mdl

# Install Black Python Formatter.
RUN pip3 install black

# Clone cp2k repository (needed for CI mode).
RUN git clone --quiet --recursive --single-branch -b master https://github.com/cp2k/cp2k.git /workspace/cp2k

# Install Flask app.
RUN pip3 install flask gunicorn
WORKDIR /opt/cp2k-precommit
COPY precommit_server.py .

ARG REVISION
ENV REVISION=${REVISION}

COPY entrypoint.sh .
CMD ["./entrypoint.sh"]

#EOF
