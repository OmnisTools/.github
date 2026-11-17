---
inclusion: always
---

# AWS Organization & OU Structure

Companion to `aws-environments.md`. That file describes the *promotion lanes*
and deployment flow; this file describes the *organization tree* — the OUs, the
account→OU memberships, and the network-sharing boundaries. They are two
orthogonal views of the same accounts; do not "correct" one into the other.

## Org identity

- Organization: `o-udbnu9lppf`  ·  Root: `r-5qcl`
- Management / payer account: `140155194318` (owns all OU ARNs)
- OU ARN form: `arn:aws:organizations::140155194318:ou/o-udbnu9lppf/<ou-id>`

## OU tree (verified live via the `omnis-master` profile)

| OU | OU ID | Accounts |
| -- | ----- | -------- |
| Management | `ou-5qcl-4pntns4l` | `140155194318` omnis-management (payer/org) · `928791154155` omnis-management (account automation/SSM) · `943145460040` omnis-sso (IAM Identity Center) · `933344248885` omnis-central (Kiro/hub) |
| OmnisRisk | `ou-5qcl-1ppj7q2z` | *(grouping OU — no direct accounts)* |
| OmnisRisk / Dev | `ou-5qcl-1qxu2w17` | `184243409136` omnisrisk-dev |
| OmnisRisk / Prod | `ou-5qcl-pu24hhud` | `416417230199` omnisrisk-prod |
| OmnisTools | `ou-5qcl-o6ydmf1m` | *(grouping OU — no direct accounts)* |
| OmnisTools / Dev | `ou-5qcl-sf5kcwh1` | `885102939857` omnistools-dev (dev network owner + WordPress) · `709543209073` omnistools-devtest · `793040131955` ai-dev |
| OmnisTools / Production | `ou-5qcl-p0326se5` | `526272178819` omnistools-newprod · `075502354537` omnistools-prod (prod network owner + WordPress) · `984429768971` ai-prod |
| OmnisTools / Stage | `ou-5qcl-wketa2sh` | `697731339825` omnistools-staging (staging network owner + WordPress) · `981758561569` omnistools-preprod · `110980421396` ai-stage |

## Management OU

Org-level accounts that serve *both* product lines (Risk and Tools). They run
**no application, WordPress, or network workloads** — app/WP work never targets
a Management-OU account.

## Two orthogonal models (do not conflate)

- **Promotion-lane view** (`aws-environments.md`): ai-dev / ai-stage / devtest /
  staging / prod, keyed to branches and TFC workspaces.
- **Org-tier view** (this file): Dev / Production / Stage OUs per product line.

Same accounts, different axes. Example: `110980421396` is the `ai-stage`
promotion lane *and* sits in the OmnisTools/Stage OU — both are correct.

## AI accounts (OT-800)

`ai-dev` (`793040131955`), `ai-stage` (`110980421396`) and `ai-prod`
(`984429768971`) are dedicated, **VPC-less** accounts, one per AI lane, placed in
the Dev, Stage and Production OUs. They own no network. They consume the
subnets their segment's network owner shares through AWS RAM, by OU membership
alone, so they need **no entry in `vpc.yaml`** (only network *owners* are listed
there). They were split out of the network-owner accounts `885102939857` and
`075502354537`, which still host the dev and prod networks and WordPress.

## Network subnet sharing

Principle only; the CloudFormation mechanics live in
`OmnisToolsAWS/CloudFormation/vpc.yaml`.

A network stack shares its subnets (via AWS RAM) **only to its own segment OU**,
where segment = product line (Risk vs Tools) × tier (Dev vs Prod):

- OmnisRisk and OmnisTools networks are **isolated from each other**.
- Dev and Prod tiers **do not cross**.
- Accounts not in a defined segment create **no share** (fail-closed; never org-wide).
- **Staging network:** `697731339825` (omnistools-staging, Stage OU) owns the
  dedicated staging VPC and shares it to the Stage OU
  (`network-omnistools-staging-share`, issue #15 / OT-792).
- **preprod still runs on the DEV network.** The preprod application account
  `981758561569` (Stage OU) has its EKS cluster, ALB, RDS, OpenSearch and
  report-generate Lambda in the **dev** subnets (`10.14.16-21`), not the
  production network and not the staging network. Moving it to the staging
  network has not been done. This preprod staging application is not part of the
  `ai-stage` lane.

### Deployed state vs. intended state (verified live 2026-11-14)

The principle above is the intended model. As deployed today:

- `network-omnistools-dev-share` (owner `885102939857`) targets the **whole
  organization** (`o-udbnu9lppf`), not the Dev OU. Every account in the org, the
  three AI accounts and preprod included, sees the dev subnets. This is how
  preprod reaches them. The OU-scoped `vpc.yaml` (OT-794) is not yet deployed to
  the dev stack, and deploying it as written would unshare the dev subnets from
  preprod (Stage OU) until preprod is moved or added as a principal.
- `network-omnistools-prod` (owner `075502354537`) is ACTIVE and targets the
  Production OU, so `ai-prod` can already see the prod subnets (`10.14.0-5`). The
  share is not a resource of the `network-omnistools-prod` CloudFormation stack.
- `network-omnistools-staging-share` (owner `697731339825`) targets the Stage OU
  and is visible to `ai-stage` and preprod.
