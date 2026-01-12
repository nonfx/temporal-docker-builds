# Safe base-server
ARG BASE_IMAGE=alpine:3.23

# Dockerize builder
FROM golang:1.25.5-alpine3.23 AS builder
RUN apk add --no-cache git
ARG DOCKERIZE_VERSION=v0.9.9
RUN go install github.com/jwilder/dockerize@${DOCKERIZE_VERSION}
RUN cp $(which dockerize) /usr/local/bin/dockerize

##### base-server target #####
FROM ${BASE_IMAGE} AS base-server

RUN apk update && apk upgrade --no-cache
RUN apk add --no-cache --upgrade \
    ca-certificates \
    tzdata \
    bash \
    'curl>=8.14.1-r2' \
    'libssl3>=3.5.4-r0' \
    'libcrypto3>=3.5.4-r0'

COPY --from=builder /usr/local/bin/dockerize /usr/local/bin

SHELL ["/bin/bash", "-c"]

##### Temporal Server #####
FROM base-server as temporal-server
ARG TARGETARCH
ARG TEMPORAL_SHA=unknown

WORKDIR /etc/temporal

ENV TEMPORAL_HOME=/etc/temporal
EXPOSE 6933 6934 6935 6939 7233 7234 7235 7239

# TODO switch WORKDIR to /home/temporal and remove "mkdir" and "chown" calls.
RUN addgroup -g 1000 temporal
RUN adduser -u 1000 -G temporal -D temporal
RUN mkdir /etc/temporal/config
RUN chown -R temporal:temporal /etc/temporal/config
USER temporal

# store component versions in the environment
ENV TEMPORAL_SHA=${TEMPORAL_SHA}

# binaries
COPY ./build/${TARGETARCH}/temporal-server /usr/local/bin
COPY ./build/${TARGETARCH}/temporal /usr/local/bin

# configs
COPY ./temporal/config/dynamicconfig/docker.yaml /etc/temporal/config/dynamicconfig/docker.yaml
COPY ./temporal/docker/config_template.yaml /etc/temporal/config/config_template.yaml

# scripts
COPY ./docker/entrypoint.sh /etc/temporal/entrypoint.sh
COPY ./docker/start-temporal.sh /etc/temporal/start-temporal.sh

### Server release image ###
FROM temporal-server as server
ENTRYPOINT ["/etc/temporal/entrypoint.sh"]

### Server auto-setup image ###
##### Admin Tools #####
# This is injected as a context via the bakefile so we don't take it as an ARG
FROM temporaliotest/admin-tools as admin-tools
FROM temporal-server as auto-setup

WORKDIR /etc/temporal

# binaries
COPY ./build/${TARGETARCH}/temporal-cassandra-tool /usr/local/bin
COPY ./build/${TARGETARCH}/temporal-sql-tool /usr/local/bin

# configs
COPY  ./temporal/schema /etc/temporal/schema

# scripts
COPY ./docker/entrypoint.sh /etc/temporal/entrypoint.sh
COPY ./docker/start-temporal.sh /etc/temporal/start-temporal.sh
COPY ./docker/auto-setup.sh /etc/temporal/auto-setup.sh

ENTRYPOINT ["/etc/temporal/entrypoint.sh"]
CMD ["autosetup"]
