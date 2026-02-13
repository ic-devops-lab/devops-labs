# Securing a Remote Linux Host with firewalld and OpenVPN

This lab demonstrates how to transform a freshly rented public Linux
server into a controlled, hardened entry point using firewalld and
OpenVPN.

The focus is not on installing tools, but on deliberately reducing the
exposed attack surface and separating public services from
administrative access.

------------------------------------------------------------------------

## Article

Full architecture walkthrough and explanation:

> (Add article link here after publishing)

------------------------------------------------------------------------

## What This Lab Demonstrates

-   Establishing a deterministic firewall baseline with firewalld
-   Replacing public SSH exposure with a private VPN access plane
-   Implementing split‑tunnel administrative VPN design
-   Restricting SSH and RDP to VPN + controlled IP
-   Disabling root SSH login safely
-   Building reproducible infrastructure with validation at every step

------------------------------------------------------------------------

## Architecture Overview

### Phase 1 --- Make it work

-   firewalld deny‑by‑default policy
-   Public SSH temporarily allowed
-   HTTP/HTTPS exposed intentionally
-   Persistent firewall configuration via systemd

### Phase 2 --- Reduce trust / Harden access

-   OpenVPN deployed for administrative access
-   Split‑tunnel mode (no forced internet routing)
-   SSH and RDP restricted to:
    -   VPN subnet
    -   Home public IP
-   Root login disabled

### Final State

Public exposure limited to:

-   HTTP / HTTPS (if required)
-   OpenVPN UDP port

Administrative access available only via authenticated VPN membership.

![Phase 1 scheme](./docs/ProtectRemoteHostWithFirewallAndVPN-1.png)
![Phase 2 scheme](./docs/ProtectRemoteHostWithFirewallAndVPN-2.png)
![Final scheme](./docs/ProtectRemoteHostWithFirewallAndVPN-3.png)

------------------------------------------------------------------------

## Repository Structure

    lab-name/
    ├── README.md
    ├── runbook.md
    ├── docs/
    │   ├── architecture.md
    │   └── images/
    ├── scripts/
    │   ├── firewalld/
    │   │   ├── phase1/
    │   │   └── phase2/
    │   └── openvpn/
    ├── examples/
    └── diagrams/

------------------------------------------------------------------------

## How to Use This Repository

1.  Follow the runbook step‑by‑step.
2.  Copy scripts from `scripts/` rather than rewriting them manually.
3.  Validate after each phase before continuing.
4.  Reboot once at the end to confirm persistence.

This lab is intentionally incremental. Do not skip validation steps.

------------------------------------------------------------------------

## Scope and Non‑Goals

This lab focuses on securing a single public Linux host.

It does not cover:

-   High‑availability VPN setups
-   Multi‑region deployment
-   Automated provisioning via Terraform/Ansible (future labs)
-   Advanced intrusion detection

------------------------------------------------------------------------

## Extensions / Next Ideas

-   Replace OpenVPN with WireGuard and compare operational complexity
-   Add Fail2Ban for additional protection
-   Mirror firewall policy at provider level
-   Convert the host into a bastion/jump host pattern
-   Automate everything with configuration management

------------------------------------------------------------------------

## Published Labs in This Series

-   GitLab Behind Cloudflare Zero Trust\
    https://dev.to/iuri_covaliov/self-hosting-gitlab-behind-cloudflare-zero-trust-a-practical-devops-lab-18ce
