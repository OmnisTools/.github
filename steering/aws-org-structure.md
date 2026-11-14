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
| OmnisTools / Dev | `ou-5qcl-sf5kcwh1` | `885102939857` omnistools-dev · `709543209073` omnistools-devtest |
| OmnisTools / Production | `ou-5qcl-p0326se5` | `526272178819` omnistools-newprod · `075502354537` omnistools-prod |
| OmnisTools / Stage | `ou-5qcl-wketa2sh` | `981758561569` omnistools-preprod |

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
where segment = product line (Risk vs Tools) × tier (Dev vs Prod):

- OmnisRisk and OmnisTools networks are **isolated from each other**.
- Dev and Prod tiers **do not cross**.
- Accounts not in a defined segment create **no share** (fail-closed; never org-wide).
- **Staging exception:** OmnisTools staging (`omnistools-preprod`, Stage OU)
  currently rides the **Production** network, so it shares with the
  OmnisTools/Production OU. A dedicated staging network is tracked in issue #15.
