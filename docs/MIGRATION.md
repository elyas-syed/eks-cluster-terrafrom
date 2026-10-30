# Existing deployment safety

The repository root on `main` is the supported deployment configuration. New
deployments can follow the root README without a migration step. These notes
apply only when reusing infrastructure or state created with an older revision.
Fresh-deployment tests do not validate every existing cluster's upgrade path.

Back up state, retain existing variable values, and review a full plan before
applying. Stop if the plan proposes unexpected replacements or deletions.

1. Keep `cluster_version` at the existing version initially, then upgrade one
   minor version at a time with compatible add-ons and workload API checks.
2. Existing clusters created with bootstrap creator admin enabled must explicitly
   set `bootstrap_cluster_creator_admin_permissions = true`. That creation-time
   setting is immutable; changing it can force replacement. New clusters default
   to false and require explicit `access_entries`.
3. Set `authentication_mode` explicitly to the existing mode for the first plan.
   Review AWS's allowed one-way transitions before adopting API-only mode.
4. Public endpoint access now defaults to false. For a public API, explicitly
   enable it and provide allowed CIDRs. Arrange private connectivity first if
   switching an existing cluster to private-only access.
5. Keep existing availability zones and node instance types explicitly in your
   variable file. Region-based zone discovery and the larger default instance
   type are intended for new deployments; changing either can replace resources.
6. Custom labels, taints, update limits, and launch-template selections are now
   honored. Review their effect on scheduling and node rollouts before applying.
   Existing external launch templates must supply their own compatible networking
   and bootstrap settings.
7. Cluster-admin policy associations move into the compute module using a `moved`
   block. Do not remove the block while older state may still be upgraded.
   STS callers resolve to persistent role ARNs; check whether that changes any
   existing access-entry principal.
8. CloudWatch retention now defaults to 30 days. Set it explicitly if retaining
   the previous 7-day setting is necessary.
9. Add-ons no longer default to stale fixed versions. Pin currently deployed
   versions initially, then upgrade deliberately. Pod Identity Agent is enabled
   by default for new configurations; disable it by supplying an explicit
   `cluster_addons` map if it is not wanted.
10. Optional ingress is a separate stack and reuses the root IAM role. If an old
    platform state owns that same role, reconcile ownership before applying;
    do not destroy a role still used by the root. Import/move resources only
    after inventorying both states. Read controller CRD upgrade instructions.

## S3 locking

Terraform 1.10+ supports `use_lockfile = true`. For an existing DynamoDB-backed
bootstrap stack, set `enable_dynamodb_locking = true` so its table is retained.
During migration, configure both `dynamodb_table` and `use_lockfile` in backend
clients; migrate every client before removing DynamoDB locking. Back up state
and follow the Terraform backend migration prompts. Do not delete the old table
while clients still depend on it.

## Legacy terraform/ directory

The legacy standalone resources have different addresses from the modular root.
No generic automatic migration is supplied: inventory actual state, map resources
one by one, and validate a no-replacement plan. Do not apply a fresh root state
against an existing legacy cluster and expect Terraform to adopt it automatically.
