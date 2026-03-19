# GitLab CI Dependency Caching Lab

## Overview

This lab demonstrates how dependency caching works in GitLab CI and evaluates its real impact on pipeline performance.

Instead of assuming caching always improves speed, this lab shows:

- how to implement pip dependency caching
- how caching behaves in multi-job pipelines
- when caching helps — and when it does not

---

## Article

Full architecture walkthrough and explanation:

👉 https://dev.to/iuri_covaliov/gitlab-ci-caching-didnt-speed-up-my-pipeline-heres-why-21o3

---

## Repository Structure

```
DevOps-Labs-Repo/
├── GitLabCIPipelinesWithDependencyCaching/
│   ├── docs/
│   │   └── ci_jobs_logs.md
│   ├── gitlab-ci-cache-lab/
│   │   ├── .gitlab-ci.yml
│   │   ├── app.py
│   │   ├── requirements.txt
│   │   └── tests/
│   │       └── test_app.py
│   ├── readme.md
│   └── runbook.md
```

### Key components

- `gitlab-ci-cache-lab/` — demo project used in CI pipeline
- `docs/ci_jobs_logs.md` — captured pipeline logs and measurements
- `runbook.md` — detailed lab instructions and explanation
- `readme.md` — high-level overview (this file)

---

## Tech Stack

- GitLab CI
- Python 3.12
- pytest
- pip dependency caching

---

## Lab Concept

### Problem

In many CI pipelines, dependencies are installed repeatedly in every job and every run.

### Hypothesis

Caching pip downloads should:

- reduce repeated dependency downloads
- speed up installation
- improve pipeline performance

### What we validate

- Does caching reduce install time?
- Does it reduce total pipeline duration?
- When is caching actually useful?

---

## Pipeline Design

The pipeline consists of three stages:

- **prepare** → install dependencies
- **quality** → compile/lint
- **test** → run tests

Each job installs dependencies to simulate real-world pipelines where multiple jobs need the same environment.

---

## Dependency Set

The lab uses intentionally heavier dependencies:

```
pytest
requests
pandas
scikit-learn
matplotlib
scipy
```

This increases installation cost and makes caching effects easier to observe.

---

## Implementation

### Cache configuration

```yaml
.cache:
  cache:
    key:
      files:
        - requirements.txt
    paths:
      - .cache/pip
    policy: pull-push
```

### pip configuration

```yaml
PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"
```

This ensures pip uses a directory that GitLab can cache.

---

## Results Summary

| Mode        | Run | Observation                  | Duration |
|-------------|-----|------------------------------|----------|
| No cache    | 1   | full download                | ~38s     |
| No cache    | 2   | full download again          | ~34s     |
| With cache  | 1   | cache populated              | ~40s     |
| With cache  | 2   | cache reused, similar timing | ~38s     |

---

## Key Findings

### No significant speed improvement

Caching did not noticeably reduce total pipeline duration.

### Why

- fast dependency downloads (likely local mirror)
- pip already efficient
- cache upload/download overhead
- runner startup dominates runtime

### What caching still improves

- reduces repeated external downloads
- can reduce outbound traffic costs
- improves resilience to network issues
- becomes more useful in larger pipelines

---

## Key Insight

> Dependency caching is not always a performance optimization — its impact depends on context.

---

## When caching helps

- large dependency trees
- slower networks
- distributed runners
- frequent pipeline executions

---

## When it may not help

- small projects
- fast mirrors (e.g., Hetzner)
- short pipelines
- high cache overhead

---

## Next Steps

Planned follow-up labs:

- GitLab cache vs artifacts
- S3-compatible cache backend (MinIO / AWS S3)
- Docker build caching
- pipeline optimization strategies

---

## Related Files

- See [`runbook.md`](runbook.md) for step-by-step instructions
- See [`docs/ci_jobs_logs.md`](./docs/ci_job_logs.md) for raw pipeline logs and timing data

---

## Related labs

- [GitLab SE behind Cloudflare Zero Trust](./GitLabSE-behind-CloudFlare/readme.md)
- [GitLab SE behind Cloudflare Zero Trust: Part 2. Introducing the Tunnels](./GitLabSEBehindCloudflare02Tunnels/readme.md)
- [GitLab SE Behind Cloudflare: Part 3. Private Runner](./GitLabSEBehindCloudflare03Runner/README.md)
