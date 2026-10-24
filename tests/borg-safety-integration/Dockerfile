FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/opt/borgmatic/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

RUN apt-get update \
    && apt-get install --yes --no-install-recommends bash borgbackup ca-certificates curl git jq openssh-client python3-venv python3-yaml \
    && python3 -m venv /opt/borgmatic \
    && rm --recursive --force /var/lib/apt/lists/*

ARG BORGMATIC_VERSION=2.1.7
ARG YQ_VERSION=v4.47.2
ARG TARGETARCH
RUN /opt/borgmatic/bin/pip install --no-cache-dir "borgmatic==${BORGMATIC_VERSION}" \
    && curl --fail --silent --show-error --location --retry 3 \
       "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_${TARGETARCH}" \
       --output /usr/local/bin/yq \
    && chmod 755 /usr/local/bin/yq \
    && yq --version | grep --fixed-strings "${YQ_VERSION}"

WORKDIR /workspace
CMD ["bash", "tests/borg-safety-integration/test.sh"]
