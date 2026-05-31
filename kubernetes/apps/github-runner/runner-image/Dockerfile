# Custom GitHub Actions runner image for the dojo E2E workflow.
# Multi-arch capable; intended target is linux/arm64 (homelab nodes).
#
# What's baked in:
#   - Node 22
#   - Supabase CLI
#   - Docker CLI (talks to the DinD sidecar over tcp://localhost:2375)
#   - Playwright system deps + chromium browser (under /opt/ms-playwright)
#   - psql client (for the seed step)
#   - jq, curl, git (used by the entrypoint registration script)
#
# Layout note: the actions-runner binary lives at /opt/actions-runner and the
# Playwright cache at /opt/ms-playwright. /home/runner is mounted from a PVC
# at runtime, so anything baked there is shadowed. The pod's entrypoint copies
# the runner into /home/runner/actions-runner on first boot, and the pod env
# sets PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright.
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
ARG NODE_MAJOR=22
ARG SUPABASE_CLI_VERSION=2.84.2
ARG PLAYWRIGHT_VERSION=1.59.1

ENV DEBIAN_FRONTEND=noninteractive \
    RUNNER_ALLOW_RUNASROOT=0 \
    PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright

# Map Docker's TARGETARCH (amd64/arm64) to the GitHub runner's arch slug (x64/arm64)
RUN case "${TARGETARCH}" in \
        amd64) echo "x64"   > /tmp/runner_arch ;; \
        arm64) echo "arm64" > /tmp/runner_arch ;; \
        *) echo "unsupported arch ${TARGETARCH}" >&2; exit 1 ;; \
    esac

# Base packages + Node + Docker CLI repos
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl gnupg git jq sudo unzip xz-utils rsync \
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

# GitHub Actions runner binary at /opt/actions-runner (out of /home/runner so
# the runtime PVC mount doesn't shadow it).
RUN mkdir -p /opt/actions-runner && cd /opt/actions-runner \
    && RUNNER_ARCH=$(cat /tmp/runner_arch) \
    && curl -fsSL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-${RUNNER_ARCH}-${RUNNER_VERSION}.tar.gz" \
        -o runner.tar.gz \
    && tar xzf runner.tar.gz \
    && rm runner.tar.gz \
    && ./bin/installdependencies.sh \
    && chown -R runner:runner /opt/actions-runner

# Playwright system deps + chromium at /opt/ms-playwright (also outside /home/runner).
RUN mkdir -p /opt/ms-playwright \
    && chown runner:runner /opt/ms-playwright \
    && su - runner -c "PLAYWRIGHT_BROWSERS_PATH=/opt/ms-playwright npx --yes playwright@${PLAYWRIGHT_VERSION} install --with-deps chromium" \
    && rm -rf /var/lib/apt/lists/*

USER runner
WORKDIR /home/runner
