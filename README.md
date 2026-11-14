# Omnis Tools Inc

Omnis Tools GitHub organization

## Shared Kiro steering

`steering/` is the source of truth for rules shared by every OmnisTools repo
(AWS lanes and branch naming, org structure, GitHub identity, workflow
orchestration). Change them here by PR. To refresh a local workspace:

```bash
scripts/sync-steering.sh /path/to/OmnisTools
```

Each repo keeps only a pointer plus its own lane/workspace details in
`.kiro/steering/aws-environments.md`.
