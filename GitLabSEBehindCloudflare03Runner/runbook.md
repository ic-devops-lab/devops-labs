# GitLab SE Private Runner — Runbook

This runbook provisions a GitLab Runner VM inside the same private network as your GitLab VM and validates it with a minimal CI pipeline.

The lab assumes GitLab is still published externally through Cloudflare Zero Trust for **human access**, while the runner uses a **private internal path** for control-plane traffic and repository checkout.

## Prerequisites

### Host machine
- Linux/macOS/Windows host with:
  - Vagrant
  - VirtualBox (or another Vagrant provider)
  - `curl`, `ssh`, `git`

### Existing GitLab VM
- GitLab is already running from the previous lab
- GitLab is reachable on the private network
- You can access GitLab UI as an admin

## Assumptions / Environment Variables

All case-specific values are defined here and reused across the runbook.

```bash
# ===== Network =====
export LAB_NET_NAME="labnet"
export LAB_NET_CIDR="192.168.56.0/24"

export GITLAB_VM_PRIVATE_IP="192.168.56.10"
export RUNNER_VM_PRIVATE_IP="192.168.56.20"

# Internal GitLab entrypoint for the runner:
# use bundled NGINX/Workhorse on the private IP, not Puma directly
export GITLAB_PRIVATE_URL="http://${GITLAB_VM_PRIVATE_IP}:8081"

# ===== Runner identity =====
export RUNNER_NAME="20-instance-default-001"
export RUNNER_TAGS="private,docker,default,vm20"
export RUNNER_EXECUTOR="docker"
export GITLAB_RUNNER_DESCRIPTION="${RUNNER_NAME}"

# ===== GitLab runner registration =====
export GITLAB_RUNNER_REG_TOKEN="<PASTE_INSTANCE_RUNNER_REGISTRATION_TOKEN_HERE>"

# Optional: GitLab API token for stale runner cleanup
# Create it in GitLab UI:
# User avatar -> Edit profile -> Access tokens
# Scope: api
export GITLAB_API_TOKEN="<OPTIONAL_ADMIN_API_TOKEN>"

# ===== Demo project =====
export DEMO_PROJECT_NAME="private-runner-smoke"
export DEMO_DEFAULT_BRANCH="main"

# check
echo "$GITLAB_PRIVATE_URL $RUNNER_VM_PRIVATE_IP $RUNNER_NAME $RUNNER_TAGS"
```

# Runner Registration and Lifecycle

In this lab, the runner is registered automatically during VM provisioning by using a GitLab runner registration token.

Destroying the runner VM removes the local runner authentication token from `/etc/gitlab-runner/config.toml`. Recreating the VM therefore requires a new registration step. This is expected.

If you recreate the VM repeatedly, GitLab will accumulate offline runner entries unless you remove them manually or use the optional cleanup step described below.

---

## Phase 1 — Make it work

### Step 1 — Update the GitLab VM provisioner

Use `provision/gitlab/install_gitlab.sh` from this repository.

Why this change is needed:
- the older GitLab VM setup disabled bundled NGINX
- the runner needs an internal entrypoint that supports Git over HTTP checkout
- using Puma directly on `:8080` caused checkout failures
- using the public Cloudflare-protected domain caused redirects during non-interactive Git fetch

### Step 2 — Reprovision the GitLab VM

From the GitLab SE Behind Cloudflare repository root:

```bash
vagrant provision gitlab
```

If needed, rebuild the VM instead:

```bash
vagrant destroy gitlab
vagrant up gitlab
```

### Step 3 — Validate the private GitLab listener

On the GitLab VM:

```bash
vagrant ssh gitlab -c "sudo ss -tulpn | grep 8081"
vagrant ssh gitlab -c "curl -I ${GITLAB_PRIVATE_URL}/users/sign_in"
```

Expected result:
- bundled NGINX is listening on `:8081`
- `curl` returns HTTP response headers

### Step 4 — Obtain the runner registration token

Open the GitLab UI and navigate to:

```text
Admin Area → CI/CD → Runners
```

Copy the instance runner registration token and export it on the host:

```bash
export GITLAB_RUNNER_REG_TOKEN="<PASTE_INSTANCE_RUNNER_REGISTRATION_TOKEN_HERE>"

# check
echo "$GITLAB_RUNNER_REG_TOKEN"
```

### Step 5 — Optional: create a GitLab API token for stale runner cleanup

Open the GitLab UI and navigate to:

```text
User avatar → Edit profile → Access tokens
```

Create a token with:
- a descriptive name such as `runner-lab-cleanup`
- scope: `api`

Export it on the host:

```bash
export GITLAB_API_TOKEN="<OPTIONAL_ADMIN_API_TOKEN>"

# check
echo "${GITLAB_API_TOKEN:0:8}"
```

### Step 6 — Provision the runner VM

```bash
vagrant up runner
```

Provisioning will:
- install Docker
- install GitLab Runner
- use helper scripts from `/opt/provision/runner`
- optionally remove stale offline runners with the same description
- register the runner
- set `clone_url` to the internal GitLab URL
- start the `gitlab-runner` service

Verify on the VM:

```bash
vagrant ssh runner -c "docker --version && gitlab-runner --version && sudo gitlab-runner list"
vagrant ssh runner -c "sudo grep -nE 'url =|clone_url =' /etc/gitlab-runner/config.toml"
```

Expected result:
- Docker version is displayed
- GitLab Runner version is displayed
- the configured runner is listed
- both `url` and `clone_url` point to `${GITLAB_PRIVATE_URL}`

### Step 7 — Verify the runner in GitLab

Open the GitLab UI and navigate to:

```text
Admin Area → CI/CD → Runners
```

Expected result:
- a runner named `${RUNNER_NAME}` is present
- its tags include `${RUNNER_TAGS}`
- its status is `online`

### Step 8 — Create the demo project and push the example pipeline

Create a project named `${DEMO_PROJECT_NAME}` in GitLab.

Then push the example files:

```bash
mkdir -p /tmp/${DEMO_PROJECT_NAME}
cp -a examples/private-runner-smoke/. /tmp/${DEMO_PROJECT_NAME}/
cd /tmp/${DEMO_PROJECT_NAME}

git init
git checkout -b "${DEMO_DEFAULT_BRANCH}"
git add .
git commit -m "Add private runner smoke pipeline"
```

Add your GitLab remote and push the branch.

Expected result:
- a pipeline starts automatically

### Step 9 — Validate pipeline execution

Open:

```text
Project → CI/CD → Pipelines
```

Expected result in the job logs:
- runner name matches `${RUNNER_NAME}`
- runner tags include `${RUNNER_TAGS}`
- repository checkout succeeds without Cloudflare redirects
- the job prints system and network information
- the job reaches `${CI_SERVER_URL}` successfully

## Runner VM Recreation

### Step 10 — Destroy the runner VM

```bash
vagrant destroy runner
```

Expected result:
- the runner VM is removed
- GitLab later shows the previous runner entry as `offline`

### Step 11 — Recreate the runner VM

```bash
vagrant up runner
```

Expected result:
- the VM is created again
- the provisioning script runs again
- the runner registers again

If `GITLAB_API_TOKEN` is set and valid, the provisioning script removes older offline runners with the same description before registration.

### Step 12 — Manual cleanup path when API cleanup is not used

Open the GitLab UI and navigate to:

```text
Admin Area → CI/CD → Runners
```

You may see entries such as:

```text
102-instance-default-001   offline
102-instance-default-001   online
```

Delete the offline entries manually.

## Phase 2 — Reduce trust / Harden access

### Step 1 — Restrict runner scheduling

In GitLab UI:

```text
Admin Area → CI/CD → Runners
```

Set:
- **Run untagged jobs**: disabled
- runner tags: `${RUNNER_TAGS}`

This prevents the runner from executing jobs without tags. Usually runners are task specific and to use one you need you're adding the tags that your runner has to a job config in CI/CD pipeline.

For example:
```
smoke:runner-info:
  stage: smoke
  image: alpine:3.20
  tags: ['docker']
  script:
  ...
```

Ensure `.gitlab-ci.yml` includes:

```yaml
tags:
  - private
  - docker
```

### Step 2 — Disable privileged Docker mode

**Why this change matters**:
>The smoke pipeline only runs basic commands inside a standard Docker container. It does not need elevated container privileges. Setting privileged = false reduces the runner’s attack surface and limits what a job can do to the runner host if a pipeline is malicious or misconfigured.

```bash
vagrant ssh runner -c "sudo sed -i 's/^\\s*privileged\\s*=.*/  privileged = false/' /etc/gitlab-runner/config.toml || true"
vagrant ssh runner -c "sudo systemctl restart gitlab-runner && sudo systemctl is-active gitlab-runner"
```

Verify:

```bash
vagrant ssh runner -c "sudo grep privileged /etc/gitlab-runner/config.toml"
```

Expected result:

```text
privileged = false
```

## Validation Checklist

```bash
# GitLab reachable from runner via internal NGINX/Workhorse path
vagrant ssh runner -c "curl -I ${GITLAB_PRIVATE_URL}/users/sign_in"

# Runner service active
vagrant ssh runner -c "systemctl is-active gitlab-runner"

# Runner registered
vagrant ssh runner -c "sudo gitlab-runner list"

# Clone URL configured
vagrant ssh runner -c "sudo grep -n 'clone_url' /etc/gitlab-runner/config.toml"

# Docker functional
vagrant ssh runner -c "docker info >/dev/null && echo DOCKER_OK"
```

And in GitLab UI:
- the runner is online
- the pipeline succeeded
- the job was picked by the `${RUNNER_NAME}` runner
