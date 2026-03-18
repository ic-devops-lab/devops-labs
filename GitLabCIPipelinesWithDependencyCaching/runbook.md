# Runbook: GitLab CI Dependency Caching — When It Helps and When It Doesn’t

## Goal

Build a practical GitLab CI lab to evaluate how dependency caching affects pipeline behavior.

Instead of assuming caching always improves performance, this lab focuses on:

- measuring real impact
- understanding when caching helps
- identifying cases where it does not

---

## Expected outcome

By the end of the lab, you should have:

- a small demo project in GitLab
- a multi-stage pipeline (prepare / quality / test)
- baseline runs without caching
- runs with caching enabled
- measured comparison of dependency installation time
- practical conclusions for real-world pipelines

---

## Scope

### We use:

- GitLab CI
- Python demo app
- pytest
- pip dependency caching
- multi-job pipeline

### We intentionally avoid:

- S3 cache backend
- distributed runners
- Docker layer caching

These are good candidates for follow-up labs.

---

## Lab concept

### Problem

In many CI pipelines, dependencies are installed from scratch in every job and every run.

### Hypothesis

Caching pip downloads should:

- reduce repeated dependency downloads
- improve install time
- potentially reduce total pipeline duration

### Reality to validate

- Does caching actually reduce install time?
- Does it improve total job duration?
- When is caching beneficial?

---

## Test project structure

```
gitlab-ci-cache-lab/
├── .gitlab-ci.yml
├── requirements.txt
├── app.py
└── tests/
    └── test_app.py
```

Dependencies used (intentionally heavier to amplify effect):

[requirements.txt](./examples/gitlab-ci-cache-lab/requirements.txt)

---

## Phase 1 — Baseline pipeline (no cache)

### Configuration

```yaml
stages:
  - prepare
  - quality
  - test

.default_python:
  image: python:3.12
  variables:
    PYTHONPATH: "$CI_PROJECT_DIR"

install-deps:
  extends:
    - .default_python
  stage: prepare
  script:
    - python --version
    - time pip install -r requirements.txt

lint:
  extends:
    - .default_python
  stage: quality
  script:
    - time pip install -r requirements.txt
    - python -m compileall .

test:
  extends:
    - .default_python
  stage: test
  script:
    - time pip install -r requirements.txt
    - pytest
```

> `PYTHONPATH: "$CI_PROJECT_DIR"` makes the repository root visible to Python

---

### What to do

- Run pipeline multiple times (at least 2–3)
- Observe behavior across jobs and runs

---

### What to observe

- dependencies downloaded in every job
- repeated installs in each stage
- similar install times across runs

---

### Important note

We measure:
- time pip install -r requirements.txt

This is more reliable than total job duration because:
- job time includes runner overhead
- image pull and setup time can dominate
- caching mainly affects dependency installation

---

### Phase 2 — Pipeline with caching

## Configuration

```yaml
stages:
  - prepare
  - quality
  - test

.cache:
  cache:
    key:
      files:
        - requirements.txt
    paths:
      - .cache/pip
    policy: pull-push

.default_python:
  image: python:3.12
  variables:
    PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"
    PYTHONPATH: "$CI_PROJECT_DIR"

install-deps:
  extends:
    - .cache
    - .default_python
  stage: prepare
  script:
    - python --version
    - time pip install -r requirements.txt

lint:
  extends:
    - .cache
    - .default_python
  stage: quality
  script:
    - time pip install -r requirements.txt
    - python -m compileall .

test:
  extends:
    - .cache
    - .default_python
  stage: test
  script:
    - time pip install -r requirements.txt
    - pytest
```

---

### Key implementation details

**Cache template**

We use a reusable .cache block:
- applied only where needed
- avoids unnecessary cache overhead
- keeps pipeline clean and modular

**PIP_CACHE_DIR**

This is a pip environment variable.

It ensures pip stores cache inside the project directory:
```
$CI_PROJECT_DIR/.cache/pip
```

Why this matters:
- default pip cache is outside project (~/.cache/pip)
- GitLab cannot cache it reliably
- redirecting enables GitLab cache reuse

**Cache key strategy**

```yaml
key:
  files:
    - requirements.txt
```

This ensures:
- unchanged dependencies → reuse cache
- updated dependencies → refresh cache

---

### What to observe (with cache)

- cache restore and upload in logs
- fewer repeated downloads (look for Using cached)
- pip install step may become faster on repeated runs
- total job duration may not change significantly

---

## Results

| Pipeline mode | Run | Observation                        | Pip install duration |
| ------------- | --- | ---------------------------------- | -------------------- |
| No cache      | 1   | full dependency download           | 00:00:38             |
| No cache      | 2   | full dependency download again     | 00:00:34             |
| With cache    | 1   | cache populated (overhead visible) | 00:00:40             |
| With cache    | 2   | cache reused, but similar duration | 00:00:38             |

> See my CI job logs [here](./docs/ci_job_logs.md)

---

## Analysis

### Key observation

Caching **did not significantly reduce total pipeline duration** in this lab.

### Why

Several factors likely explain this:
- fast package downloads (possibly local mirror / Hetzner cache)
- pip already efficient with wheels
- cache archive/download overhead
- runner and container startup time dominating total duration

---

### Important insight

Caching is not always a performance optimization.

It depends on:
- dependency size
- network conditions
- pipeline structure
- cache backend performance

---

### Where caching still helps

Even without visible speed improvement, caching can:
- reduce repeated external downloads
- lower outbound traffic costs
- improve resilience against network issues
- provide benefits in larger pipelines or distributed runners

---

## Key takeaway

> Dependency caching should be applied selectively, based on measurable impact — not assumed as a universal optimization.

## Next steps (and prossible future labs)

- GitLab cache vs artifacts
- S3-compatible cache backend (MinIO, AWS S3)
- speeding up Docker builds in CI
- optimizing multi-stage pipelines
