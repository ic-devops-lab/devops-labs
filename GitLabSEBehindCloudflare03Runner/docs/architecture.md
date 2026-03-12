# Architecture notes

## Goal

Keep GitLab accessible to humans through Cloudflare Zero Trust, while letting CI jobs run fully inside the private network.

## Final traffic split

### Human access

```text
Browser
  -> Cloudflare Access
  -> Cloudflare Tunnel / reverse proxy path
  -> GitLab public entrypoint
```

### Runner control plane and checkout

```text
Runner VM
  -> http://<GITLAB_VM_PRIVATE_IP>:8081
  -> bundled NGINX / Workhorse
  -> GitLab
```

## Why this split matters

The runner originally failed in three different ways:

1. `http://<GITLAB_VM_PRIVATE_IP>` failed because nothing listened on port 80
2. `http://<GITLAB_VM_PRIVATE_IP>:8080` reached Puma directly and later failed for Git checkout
3. `https://<DOMAIN>` followed the public path and hit Cloudflare Access redirects during non-interactive Git fetch

The private NGINX listener on `:8081` fixes all three:

- runner registration works
- API calls stay internal
- `clone_url` points checkout to the same internal entrypoint

## Key configuration decisions

### On the GitLab VM

- keep `external_url` as the public Cloudflare-protected domain
- enable bundled NGINX
- bind bundled NGINX to the private IP on `:8081`
- keep Workhorse exposed on `:8181` for compatibility with the earlier topology
- keep Puma on `:8080` for troubleshooting only

### On the runner VM

- use Docker executor
- register as an instance runner
- set explicit runner tags
- write `clone_url` to the internal GitLab URL
- skip duplicate registration when the local runner token already exists

## Operational consequence

This lab is not just “adding a runner.” It is introducing a second GitLab access path with a different purpose:

- **public path** for people
- **private path** for CI

That distinction is the main architectural lesson of the lab.
