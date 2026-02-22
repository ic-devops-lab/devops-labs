# Labels Cheat Sheet

## Personal Runner

Recommended labels:

- self-hosted
- linux
- x64
- personal

Targeting example:

runs-on: [self-hosted, linux, x64, personal]

---

## Organization Runner

Recommended labels:

- self-hosted
- linux
- x64
- org
- ci

Targeting example:

runs-on: [self-hosted, linux, x64, org, ci]

---

## Avoid

Avoid overly broad selectors like:

runs-on: [self-hosted, linux]

This may match unintended runners if multiple exist on the same host.
