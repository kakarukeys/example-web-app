# Example Web App

A hello world [Streamlit](https://streamlit.io) application, packaged as a Docker image and published to Amazon ECR by GitHub Actions.

### Requirements

* Python 3.14+
* [Poetry](https://python-poetry.org/docs/#installation)
* Docker (or Podman)

### Installing

1. Clone the project,

```sh
git clone git@github.com:kakarukeys/example-web-app.git
cd example-web-app
```

2. Install the [dotenv plugin](https://github.com/pivoshenko/poetry-plugin-dotenv) and create your local env file

```sh
poetry self add poetry-plugin-dotenv@latest
cp .env.example .env
```

`poetry-plugin-dotenv` loads `.env` from the project root (or any parent directory) into the environment before every `poetry` command, so `poetry run streamlit ...` sees the values without exporting anything by hand.

3. Install a python virtual environment

```sh
poetry install
```

4. Start the streamlit app

```sh
poetry run streamlit run app/app.py
```

The app is served on <http://localhost:8501>.

## Checks

```sh
poetry run flake8 app tests   # style, configured in .flake8
poetry run mypy .             # static types, configured in mypy.ini
poetry run pytest             # tests, configured in pytest.ini
```

`tests/test_app.py` drives the app through Streamlit's own test harness (`streamlit.testing.v1.AppTest`), so a failing test means the app really renders something else — not just that an import broke. Every function carries annotations because `mypy.ini` sets `disallow_untyped_defs`.

## Docker

```sh
docker build --build-arg APP_VERSION=local --tag example-web-app:local .
docker run --rm --publish 8501:8501 example-web-app:local
```

The container runs as uid 1000, has no home directory and writes nothing at all, so it runs unchanged with a read-only root filesystem — as in ECS with `readonlyRootFilesystem: true`, where `/tmp` is read-only too:

```sh
docker run --rm --read-only --publish 8501:8501 example-web-app:local
```

`HOME=/tmp` exists only so that `$HOME` resolves to a readable path; nothing writes to it. If a later dependency needs a writable cache (e.g. matplotlib), point it at an explicit mount (`MPLCONFIGDIR`, `XDG_CACHE_HOME`) added to the task definition rather than relying on `HOME`.

## Versioning

The version has a single source of truth in the code: `version` under `[project]` in `pyproject.toml`. Nothing else stores it. The image name and tag, the `APP_VERSION` build argument and the `v<version>-build<run>` git tag are all derived from it at build time by CI (`poetry version --short`), so bumping is a one-line change in one file.

Use Poetry, which rewrites `pyproject.toml`:

```sh
poetry version patch   # 0.1.0 -> 0.1.1
poetry version minor   # 0.1.0 -> 0.2.0
poetry version major   # 0.1.0 -> 1.0.0
```

Both of these are acceptable practices:

* bump when the coders start to open a new chapter — the version marks the start of a body of work, and every image built along the way carries it;
* bump when the coders are about to cut a new release — the version marks the finished increment, and the bump lands in the commit or pull request that prepares the release.

Because image tags also include the CI run number (`<version>-build<run number>`), several builds of the same version remain distinct.

## Project Structure

```
.
├── app/app.py                                  # Streamlit entry point (main(), get_app_version())
├── tests/test_app.py                           # Rendered-output test (AppTest)
├── .env.example                                # Local environment template (copy to .env)
├── .flake8                                     # flake8 configuration
├── mypy.ini                                    # mypy configuration
├── pytest.ini                                  # pytest configuration
├── .github/workflows/build.yaml                # Lint, type check, test, build and publish
├── Dockerfile                                  # Container definition
├── poetry.lock                                 # Python dependencies lock file
├── pyproject.toml                              # Python dependencies
└── README.md                                   # This file
```

## Continuous Integration

`.github/workflows/build.yaml` runs three checks in parallel on every push and pull request, and publishes an image only when all three pass. They are one job, `checks`, fanned out by `strategy.matrix`, so the Python/Poetry/cache setup is written once and each leg adds only its command:

| Job | Runs |
|---|---|
| `checks` — `Lint` | `poetry run flake8 app tests` |
| `checks` — `Type check` | `poetry run mypy .` |
| `checks` — `Test` | `poetry run pytest -q` |
| `post-build` | `git tag` and push, after `publish` |

* **pull request** — the three checks only (superseded runs are cancelled); no image is built, nothing is published;
* **push to `main`** — the three checks, then `publish` (needs `checks`): builds `linux/amd64` and `linux/arm64` and pushes the manifest list to Amazon ECR:

```
<registry>/<project name>:<github sha>                  # immutable, one per commit
<registry>/<project name>:<version>-build<run number>  # project version + build number
<registry>/<project name>:latest
```

A final `post-build` job then pushes the matching git tag `v<version>-build<run number>` for the built commit, skipping it when a re-run already created that tag.

### Repository configuration

| Kind | Name | Value |
|---|---|---|
| variable | `BUILD_ROLE_ARN` | IAM role assumed through GitHub OIDC (needs ECR push rights) |

`AWS_REGION` is fixed in the workflow's `env:` block, and the registry, repository name and image tag are derived at run time. Pull request runs need no configuration — `publish` and `post-build` are skipped, so only the `checks` job's Python environment is set up.
