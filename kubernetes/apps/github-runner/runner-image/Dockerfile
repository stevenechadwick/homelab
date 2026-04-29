# Custom GitHub Actions runner image for the dojo E2E workflow.
# Multi-arch capable; intended target is linux/arm64 (homelab nodes).
#
# What's baked in:
#   - Node 20
#   - Supabase CLI
#   - Docker CLI (talks to the DinD sidecar over tcp://localhost:2375)
#   - Playwright system deps + chromium browser
#   - psql client (for the seed step)
#   - jq, curl, git (used by the entrypoint registration script)
#
# Build & push for arm64 to the internal Gitea registry:
#   docker buildx build \
#     --platform linux/arm64 \
#     -t gitea.homelab.local/gitea_admin/github-runner:latest \
#     --push \
#     kubernetes/apps/github-runner/runner-image
#
# Then bounce the deployment:
#   kubectl rollout restart deployment/github-runner -n github-runner

FROM ubuntu:22.04

ARG TARGETARCH
ARG RUNNER_VERSION=2.334.0
ARG NODE_MAJOR=20
ARG SUPABASE_CLI_VERSION=1.226.4

ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_ALLOW_RUNASROOT=0 \
    PLAYWRIGHT_BROWSERS_PATH=/home/runner/.cache/ms-playwright

# Map Docker's TARGETARCH (amd64/arm64) to the GitHub runner's arch slug (x64/arm64)
RUN case "${TARGETARCH}" in \
        amd64) echo "x64"   > /tmp/runner_arch ;; \
        arm64) echo "arm64" > /tmp/runner_arch ;; \
        *) echo "unsupported arch ${TARGETARCH}" >&2; exit 1 ;; \
    esac

# Base packages + Node + Docker CLI repos
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git jq sudo unzip xz-utils \
        build-essential python3 \
        postgresql-client \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_${NODE_MAJOR}.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list \
    && curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=${TARGETARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu jammy stable" \
        > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends \
        nodejs \
        docker-ce-cli docker-buildx-plugin docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# Supabase CLI (deb is published per-arch)
RUN curl -fsSL "https://github.com/supabase/cli/releases/download/v${SUPABASE_CLI_VERSION}/supabase_${SUPABASE_CLI_VERSION}_linux_${TARGETARCH}.deb" \
        -o /tmp/supabase.deb \
    && dpkg -i /tmp/supabase.deb \
    && rm /tmp/supabase.deb

# Non-root runner user (matches actions-runner expectations)
RUN useradd -m -s /bin/bash -u 1001 runner \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/runner

USER runner
WORKDIR /home/runner

# GitHub Actions runner binary
RUN mkdir -p actions-runner && cd actions-runner \
    && RUNNER_ARCH=$(cat /tmp/runner_arch) \
    && curl -fsSL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
        -o runner.tar.gz \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz

# Playwright system deps + chromium (root needed for apt; then back to runner)
USER root
RUN cd /home/runner/actions-runner && ./bin/installdependencies.sh \
    && su - runner -c "npx --yes playwright@1.49.1 install --with-deps chromium" \
    && rm -rf /var/lib/apt/lists/*

USER runner
WORKDIR /home/runner/actions-runner
