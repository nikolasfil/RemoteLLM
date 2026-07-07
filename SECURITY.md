# Security Policy

RemoteLLM is a self-hosted Docker Compose stack. If you find a security
issue in the project itself (not in how you've configured your own
deployment), please report it privately rather than opening a public issue.

## Reporting a Vulnerability

Email **nikolas13in@gmail.com** with a description of the issue and steps
to reproduce. This is a solo-maintained project, so there's no fixed SLA,
but reports will be acknowledged and worked on as soon as possible.

Please do not open a public GitHub issue for suspected vulnerabilities.

## Scope

In scope: the code, Dockerfiles, Compose configuration, and scripts in this
repository.

Out of scope: hardening of your own deployment (exposed ports, weak
passwords, missing TLS, etc.) — see [docs/SECURITY_REVIEW.md](docs/SECURITY_REVIEW.md)
for a self-hosting exposure checklist instead.
