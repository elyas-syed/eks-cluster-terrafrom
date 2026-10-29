# Legacy configuration

This directory is retained for reference only. It is not called by the supported
root deployment and is not part of the supported CI/deployment path. Use the
repository root and `infrastructure/` modules for new deployments.

Do not apply both configurations against the same cluster. Existing users must
inventory their state and create an explicit resource-address migration plan
before moving to the modular root; simply switching directories can duplicate
or replace infrastructure. See `../docs/MIGRATION.md`.
