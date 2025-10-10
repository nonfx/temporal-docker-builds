##### Build base-admin-tools locally #####
FROM alpine:3.22 AS cqlsh-builder

# These are necessary to install cqlsh
RUN apk add --update --no-cache \
    python3-dev \
    musl-dev \
    libev-dev \
    gcc \
    pipx

RUN pipx install --global cqlsh

FROM alpine:3.22 AS base-admin-tools

RUN apk upgrade --no-cache
RUN apk add --no-cache \
    python3 \
    libev \
    ca-certificates \
    tzdata \
    bash \
    'curl>=8.14.1-r2' \
    jq \
    yq \
    mysql-client \
    'postgresql17-client>=17.6-r0' \
    'expat>=2.7.2-r0' \
    'sqlite-libs>=3.49.2-r1' \
    'libssl3>=3.5.4-r0' \
    'libcrypto3>=3.5.4-r0' \
    tini

COPY --from=cqlsh-builder /opt/pipx/venvs/cqlsh /opt/pipx/venvs/cqlsh
RUN ln -s /opt/pipx/venvs/cqlsh/bin/cqlsh /usr/local/bin/cqlsh

# validate cqlsh installation
RUN cqlsh --version

##### Admin Tools #####
# This is injected as a context via the bakefile so we don't take it as an ARG
FROM temporaliotest/server as server

##### Temporal admin tools #####
FROM base-admin-tools as temporal-admin-tools
ARG TARGETARCH

COPY ./build/${TARGETARCH}/temporal /usr/local/bin
COPY ./build/${TARGETARCH}/temporal-cassandra-tool /usr/local/bin
COPY ./build/${TARGETARCH}/temporal-sql-tool /usr/local/bin
COPY ./build/${TARGETARCH}/tdbg /usr/local/bin
COPY ./temporal/schema /etc/temporal/schema

# Alpine has a /etc/bash/bashrc that sources all files named /etc/bash/*.sh for
# interactive shells, so we can add completion logic in /etc/bash/temporal-completion.sh
# Completion for temporal depends on the bash-completion package.
RUN apk add --no-cache bash-completion && \
    temporal completion bash > /etc/bash/temporal-completion.sh && \
    addgroup -g 1000 temporal && \
    adduser -u 1000 -G temporal -D temporal
USER temporal
WORKDIR /etc/temporal

# Keep the container running.
ENTRYPOINT ["tini", "--", "sleep", "infinity"]
