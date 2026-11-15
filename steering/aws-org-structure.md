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
| OmnisTools / Dev | `ou-5qcl-sf5kcwh1` | `885102939857` omnistools-dev · `709543209073` omnistools-devtest · `793040131955` ai-dev |
| OmnisTools / Production | `ou-5qcl-p0326se5` | `526272178819` omnistools-newprod · `075502354537` omnistools-prod · `984429768971` ai-prod |
| OmnisTools / Stage | `ou-5qcl-wketa2sh` | `981758561569` omnistools-preprod · `697731339825` omnistools-staging (staging network owner) · `110980421396` ai-stage |

`ai-dev`, `ai-stage` and `ai-prod` are dedicated, VPC-less accounts. They consume
their lane's network share by OU membership alone and need no entry in
`vpc.yaml`. They exist and are placed in these OUs; re-pointing the AI lanes at
them is tracked in OT-800.

## Management OU

Org-level accounts that serve *both* product lines (Risk and Tools). They run
**no application, WordPress, or network workloads** — app/WP work never targets
a Management-OU account.

## Two orthogonal models (do not conflate)

- **Promotion-lane view** (`aws-environments.md`): ai-dev / ai-stage / devtest /
  staging / prod, keyed to branches and TFC workspaces.
- **Org-tier view** (this file): Dev / Production / Stage OUs per product line.

Same accounts, different axes. Example: `075502354537` is the `ai-stage`
promotion lane *and* sits in the OmnisTools/Production OU — both are correct.

## Network subnet sharing

Principle only; the CloudFormation mechanics live in
`OmnisToolsAWS/CloudFormation/vpc.yaml`.

A network stack shares its subnets (via AWS RAM) **only to its own segment OU**,
where segment = product line (Risk vs Tools) × tier (Dev, Stage or Prod):

- OmnisRisk and OmnisTools networks are **isolated from each other**.
- Dev, Stage and Prod tiers **do not cross**.
- Accounts not in a defined segment create **no share** (fail-closed; never org-wide).
- **A network is owned by one account and consumed by the others in its OU.**
  The owner deploys `vpc.yaml` and lists in its segment condition. Consumers need
  nothing in the template: they reach the share by OU membership alone.
  OmnisTools network owners: dev `885102939857` (`omnistools-dev`), staging
  `697731339825` (`omnistools-staging`), prod `075502354537` (`omnistools-prod`).
- **Staging network (OT-792, issue #15):** `omnistools-staging` owns a dedicated
  VPC (`10.14.96.0/20` in us-west-2) and shares it to the Stage OU.
  `omnistools-preprod`, in the Stage OU, can already see those subnets, but its
  workloads have **not migrated yet**. Preprod runs on the **Dev** network
  (`network-omnistools-dev-share`, alongside devtest), not on the Production
  network. Earlier versions of this file said preprod rides Production. That was
  wrong.
- **Do not deploy the OU-scoped share to `network-omnistools-dev` until preprod has
  migrated.** The live dev share still targets the whole org, which is how preprod
  uses it. Scoping it to the Dev OU would unshare the subnets from preprod. Per
  [AWS](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-sharing-share-subnet-working-with.html),
  resources already running in an unshared subnet keep running, but the participant
  can no longer create new resources there, and managed workflows that need
  continuous access (load balancer scaling, EKS node replacement, Lambda ENI
  creation) can fail. Preprod's EKS, ALB, RDS, Elasticsearch and Lambda would
  keep running until something needs to scale or be replaced, and then break.
