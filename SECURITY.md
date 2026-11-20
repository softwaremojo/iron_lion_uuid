# Security policy

## Supported versions

IronLion is pre-1.0. Security fixes go into the latest release only.

## Reporting a vulnerability

Please report vulnerabilities privately, not in a public issue. Use GitHub's
private vulnerability reporting: on the repository's **Security** tab, choose
**Report a vulnerability**.

Include what you found, the version affected, and steps or code to reproduce
it. We'll acknowledge the report, work on a fix with you in the private
advisory, and publish the advisory with the fixed release.

## Scope

- The gem's Ruby code.
- The SQL it generates and installs in Postgres: the `iron_lion_uuid(...)`
  function, the `iron_lion_assign_id()` trigger function, and their helpers.
