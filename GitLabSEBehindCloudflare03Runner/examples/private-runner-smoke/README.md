# private-runner-smoke

Minimal GitLab project used to validate a private GitLab Runner with Docker executor.

## What this project proves

- the job is picked by the intended private runner
- the Docker executor starts containers successfully
- the runner can reach GitLab on the internal URL
- repository checkout works inside the CI job

## Why this example matters

This project is intentionally small because the lab is validating runner plumbing, not application build logic.

It also reflects an important architectural choice from the lab:
- human access goes through the public GitLab URL protected by Cloudflare Zero Trust
- CI checkout and runner traffic stay on the private network

That is why the runner is configured with an internal `clone_url`.
