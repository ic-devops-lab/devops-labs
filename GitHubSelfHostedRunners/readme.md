# Self-hosted GitHub Actions Runners on Linux Server
Owning Your GitLab CI
---

This lab explores how to move GitHub Actions workloads from
GitHub-hosted runners to a self-managed Linux server.

The focus is not installation mechanics --- it is runner scope,
lifecycle management, and execution control.

The setup supports:

-   A repository-bound runner
-   An organization-level shared runner
-   Multiple runners on the same host
-   Service-managed lifecycle via systemd
-   Explicit scheduling using labels

📖 Article: *(link to be added)*

------------------------------------------------------------------------

## What This Lab Demonstrates

-   Designing runner scope (repo vs organization)
-   Managing multiple runners on one Linux host
-   Turning a runner into a persistent system service
-   Preventing accidental cross-scheduling via label strategy
-   Structuring runners for future growth

This lab treats CI execution as infrastructure --- not just
configuration.

------------------------------------------------------------------------

![Scheme: GitLab Self-hosted runners](./docs/images/github-selfhosted-runners.png)

------------------------------------------------------------------------

## Architecture Overview

### Initial Setup --- Repository Runner

Single repository-bound runner.

```
Repository
↓
GitHub Actions
↓
Self-hosted runner (manual or service-managed)
↓
Linux server
```

Characteristics:

-   Bound to one repository
-   Minimal isolation
-   Direct execution on the host

------------------------------------------------------------------------

### Expanded Setup --- Organization + Repository Runners

Service-managed runners with explicit scope separation.

```
GitHub Organization
↓
Org-level runner (systemd)
↓
Linux server

Personal Repository
↓
Repo-level runner (systemd)
↓
Same Linux server
```

Key improvements:

-   systemd-managed lifecycle
-   Label-based scheduling
-   Optional runner groups
-   Clear directory separation

------------------------------------------------------------------------

## Repository Structure

```
self-hosted-gh-runners/
├── README.md
├── runbook.md
├── docs/
│ └── architecture.md
└── examples/
```

Runner directories on the server:
```
/opt/gh-actions-runners/
├── personal-runner-1/
└── organization-runner-1/
```

Each runner:
-   Has its own directory
-   Has its own systemd service
-   Has independent configuration
-   Can be scaled horizontally

------------------------------------------------------------------------

## How to Use This Repository

1.  Follow `runbook.md` step by step.
2.  Validate repository runner.
3.  Configure organization runner if needed.
4.  Verify label-based targeting works as expected.

All commands are reproducible on Ubuntu 24.04.

------------------------------------------------------------------------

## Scope and Non-Goals

This lab does **not** cover:

-   Ephemeral runners
-   Autoscaling
-   Kubernetes-based runners
-   Advanced network isolation
-   Production-grade hardening

Those are potential future labs.

------------------------------------------------------------------------

## Design Decisions

-   Separate directory per runner
-   Explicit label separation:
    -   `personal`
    -   `org`
    -   `ci`
-   One Linux host for simplicity
-   Manual token usage (no automation yet)

Trade-off:

Multiple runners share CPU, memory, and disk.\
This is acceptable for a laboratory environment.

------------------------------------------------------------------------

## Extensions / Next Ideas

-   Ephemeral runners per job
-   Containerized job isolation
-   Resource limits (cgroups)
-   Separate VM per isolation boundary
-   Runner autoscaling based on queue depth

------------------------------------------------------------------------
