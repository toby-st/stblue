ARG IMAGE_NAME="${IMAGE_NAME:-laptop}"
ARG MAJOR_VERSION="${MAJOR_VERSION:-38}"
ARG BASE_IMAGE="${BASE_IMAGE:-quay.io/fedora-ostree-desktops/silverblue}"
ARG SOURCE_IMAGE="${SOURCE_IMAGE:-silverblue}"

FROM ${BASE_IMAGE}:${MAJOR_VERSION} AS main
COPY versions/${IMAGE_NAME}/* /tmp/
ADD build.sh /tmp/build.sh
ADD post-install.sh /tmp/post-install.sh
COPY files/ /

RUN /tmp/build.sh
RUN /tmp/extras.sh || echo "no extras to run"
RUN rm -rf /tmp/* /var/*
RUN ostree container commit && \
    mkdir -p /var/tmp && chmod -R 1777 /var/tmp