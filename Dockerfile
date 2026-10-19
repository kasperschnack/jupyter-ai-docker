# Node's official multi-architecture image supplies Node/npm; nothing is installed on the host.
FROM node:24.22.0-bookworm-slim AS node

FROM quay.io/jupyter/scipy-notebook:2026-07-28

ARG JUPYTER_AI_VERSION=3.2.0
ARG CODEX_VERSION=0.163.0
ARG CODEX_ACP_VERSION=2.2.2

COPY --from=node /usr/local/bin/node /usr/local/bin/node
COPY --from=node --chown=${NB_UID}:${NB_GID} /usr/local/lib/node_modules/ /opt/conda/lib/node_modules/

USER ${NB_UID}

# Install into the existing environment, keeping its Python kernel and scientific packages.
RUN python -m pip install --no-cache-dir \
        "jupyter-ai==${JUPYTER_AI_VERSION}" \
        "jupyter-ai-acp-client==0.3.3" \
    && python -m pip check \
    && ln -s ../lib/node_modules/npm/bin/npm-cli.js /opt/conda/bin/npm \
    && ln -s ../lib/node_modules/npm/bin/npx-cli.js /opt/conda/bin/npx \
    && npm install --global --prefix=/opt/conda \
        "@openai/codex@${CODEX_VERSION}" \
        "@agentclientprotocol/codex-acp@${CODEX_ACP_VERSION}" \
    && npm cache clean --force

# A new named volume inherits this directory's ownership, mode, and initial config.
# Authentication is created only at runtime, inside that volume.
RUN mkdir -p /home/jovyan/.codex \
    && chmod 700 /home/jovyan/.codex \
    && printf 'cli_auth_credentials_store = "file"\n' > /home/jovyan/.codex/config.toml \
    && chmod 600 /home/jovyan/.codex/config.toml

# Ensure the adapter uses the same pinned CLI as the login command.
ENV CODEX_HOME=/home/jovyan/.codex \
    CODEX_PATH=/opt/conda/bin/codex

WORKDIR /home/jovyan/work
# The inherited check mistakes jpserver-mcp-*.json for a Jupyter server record.
# Probe the known Jupyter port directly instead of scanning runtime files.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8888/api', timeout=3).close()"]
CMD ["start-notebook.py", "--ServerApp.root_dir=/home/jovyan/work"]
