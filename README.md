# JupyterLab with Jupyter AI and Codex

Requires Docker Desktop running on macOS (Apple Silicon or Intel), an internet
connection for the build and agent, and a ChatGPT account with Codex access.
All Python/Node dependencies stay in Docker. Notebooks and `.chat` files stay in
the directory where you launch it.

## Build and install

Clone the repository, then build and install:

```sh
git clone https://github.com/kasperschnack/jupyter-ai-docker.git
cd jupyter-ai-docker
docker build -t jupyter-ai:local .
mkdir -p ~/bin
install -m 755 jupyter-ai ~/bin/jupyter-ai
```

Ensure `~/bin` is on your PATH (add `export PATH="$HOME/bin:$PATH"` to
`~/.zshrc` if needed), then open a new terminal.

```sh
cd /path/to/notebook-project
jupyter-ai
```

Open <http://localhost:8888> and use the Jupyter token shown in your terminal,
or open the printed token URL. Keep that terminal open. Ctrl+C stops Jupyter
(confirm shutdown if prompted); Docker removes the container afterward. The
launcher uses `exec`, and the base image's Tini entrypoint forwards signals and
reaps child processes. Only `127.0.0.1:8888` is published.

## Authenticate once

In JupyterLab, open **File → New → Terminal** and run:

```sh
codex login --device-auth
codex login status
```

Follow the device-login link in your Mac browser and enter the displayed code.
Device login may need enabling in ChatGPT security settings or by your workspace
admin. This uses your eligible ChatGPT/Codex subscription; no API key is required.
See [official OpenAI authentication documentation](https://developers.openai.com/codex/auth/).
Do not share the device code or credential files.

After login, create a new chat or select Codex again. If a previously opened
chat still reports an authentication error, restart `jupyter-ai`; login persists.

The `jupyter-ai-codex` Docker named volume holds `/home/jovyan/.codex`, including
configuration and `auth.json`. New volumes inherit ownership by `jovyan` (UID
1000) and private directory permissions from the image. Later launches reuse
the volume and refreshed credentials. It is separate from your Mac's Codex
configuration. Rebuilding/removing the image does not remove it; deleting the
volume, Docker Desktop data, or running `codex logout` requires logging in again.
Credentials are never copied into the build or printed by the launcher.

## Use Codex

Create a **Chat** from the JupyterLab launcher or chat sidebar and select or
mention **@Codex**. Keep the notebook open and attach cells/files as useful.
Approve tool requests when appropriate. Codex can inspect files, create/edit
notebooks, and execute cells through the supplied Python kernel and Jupyter MCP
tools. The browser must remain connected for frontend notebook commands.

Jupyter AI automatically detects `codex-acp`. Its built-in Jupyter MCP server
provides notebook tools without a custom MCP configuration or a separate port.
Additional tools can optionally be configured per project in
`.jupyter/mcp_settings.json`; none are needed here. See the official
[getting started guide](https://jupyter-ai.readthedocs.io/en/stable/getting-started.html)
and [notebook/MCP guide](https://jupyter-ai.readthedocs.io/en/stable/users/index.html).

## Updates

The Dockerfile pins the base image date, Node 24 LTS, Jupyter AI, its ACP client,
Codex CLI, and the ACP adapter. The adapter explicitly uses the pinned CLI via
`CODEX_PATH`. Transitive dependencies still resolve at build time; this is not
a full dependency lock. Keep the built image for identical subsequent runs.

Edit the version pins after reviewing release compatibility, then rebuild:

```sh
docker build --pull -t jupyter-ai:local .
```

Rebuilds preserve notebooks and the authentication volume. Restart JupyterLab
to use the rebuilt image. No launcher reinstall is necessary unless you edit it.

## Troubleshooting

- **Docker connection error:** start Docker Desktop.
- **Image missing:** build with the exact tag `jupyter-ai:local`.
- **Port already allocated:** stop the existing service/container using port 8888.
- **Repeated `/mcpapi` 404s:** rebuild and restart. The base image's health check
  can mistake the MCP runtime record for Jupyter's; this image overrides it to
  probe Jupyter directly. The FastMCP upgrade banner is informational; upgrading
  to a new major version independently may violate Jupyter AI's dependencies.
- **Mount denied:** allow the project directory in Docker Desktop file sharing.
- **Codex not authenticated:** run `codex login status` in the JupyterLab terminal;
  repeat device login if the account session was revoked or expired.
- **Device login disabled:** enable it in account/workspace settings. The default
  browser login callback is not published by this launcher.
- **No Codex/chat tools:** restart after rebuilding, refresh the browser, and run
  `jupyter labextension list`, `jupyter server extension list`, `codex --version`,
  and `codex-acp --version` in the JupyterLab terminal.
- **Existing volume has wrong ownership:** stop JupyterLab, then repair only that
  volume with `docker run --rm --user root --mount type=volume,source=jupyter-ai-codex,target=/home/jovyan/.codex jupyter-ai:local sh -c 'chown -R 1000:100 /home/jovyan/.codex && chmod 700 /home/jovyan/.codex'`.
  Normal launches run as `jovyan`; no host-directory ownership changes are needed.

## Validation

Verified on macOS Apple Silicon with Docker Desktop, 2026-10-19:

- Image builds successfully; `pip check` reports no broken requirements.
- JupyterLab 4.6.2 and Jupyter AI 3.2.0 are installed. AI/chat, ACP, persona,
  notebook commands, and MCP extensions are enabled and validate successfully.
- Node 24.22.0, Codex CLI 0.163.0, and Codex ACP 2.2.2 run inside the container.
- The initialized persona manager advertises **Codex** as its available agent;
  its built-in MCP configuration is valid. ACP `initialize` succeeds.
- The running server serves the authenticated Lab page, kernel API, and AI router
  health endpoint with the requested root directory. A real NumPy notebook cell
  executes successfully through the bundled `python3` kernel.
- The live MCP server lists notebook read/create/edit and cell execution tools.
- The actual launcher handles a host project path containing spaces, and files
  written on either side of the bind mount are visible on the other side.
- Container processes run as UID 1000; a new Codex volume is private and writable.
  Modified configuration and a deliberately invalid placeholder `auth.json`
  survive container replacement using an isolated test volume, subsequently removed.
- Ctrl+C through the launcher's terminal stops the server and removes its container.
- After replacing the inherited health check, Docker reports the container healthy,
  no `/mcpapi` probes occur, and the live MCP server still lists all 17 tools.

Runtime validation used a test-only Docker wrapper to publish port
`127.0.0.1:18888`, because another Jupyter server occupied port 8888. The
delivered launcher always uses `127.0.0.1:8888`; stop any existing server on that
port before launching this environment.

Interactive ChatGPT authentication, actual token refresh across launches, browser
UI interaction, and an authenticated Codex notebook-tool conversation have **not**
been verified. To finish checking: log in, create a Chat, select **@Codex**, ask it
to create a notebook with a cell computing `sum(range(5))`, and run the cell.
Approve its tool requests and confirm the result is `10`. Exit and relaunch,
then repeat without logging in. Intel builds have not been tested.
