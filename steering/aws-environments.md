---
inclusion: always
---

# AWS Environments & Deployment Model

All OmnisTools repositories share the same five AWS accounts and deployment lanes.

> Source of truth: this file lives in `OmnisTools/.github` under `steering/`.
> Repos carry only a short pointer plus their own lane/workspace table
> (see "Per-repo files"). Change shared rules here, by PR.

## Account → Environment Mapping

| Lane     | Branch       | GitHub Environment | TFC Project  | TFC Workspace pattern      | AWS Account ID | AWS Role ARN                                           |
| -------- | ------------ | ------------------ | ------------ | -------------------------- | -------------- | ------------------------------------------------------ |
| devtest  | `devtest`    | `dev`              | `Dev`        | `dev-{repo}`               | `709543209073` | `arn:aws:iam::709543209073:role/github-actions-deploy` |
| staging  | `staging`    | `staging`          | `Staging`    | `staging-{repo}`           | `981758561569` | `arn:aws:iam::981758561569:role/github-actions-deploy` |
| prod     | `production` | `prod`             | `Prod`       | `prod-{repo}`              | `526272178819` | `arn:aws:iam::526272178819:role/github-actions-deploy` |
| ai-dev   | `ai/dev`     | `ai-dev`           | `AI-Dev`     | `ai-dev-{repo}`            | `885102939857` | `arn:aws:iam::885102939857:role/github-actions-deploy` |
| ai-stage | `ai/stage`   | `ai-stage`         | `AI-Staging` | `ai-stage-{repo}`          | `075502354537` | `arn:aws:iam::075502354537:role/github-actions-deploy` |

### Branch naming rule

**The lane branch is named for its environment.** The dev environment is
`devtest`, so its branch is `devtest` in every repo. Feature branches are cut
from `main` and merged (by PR) into `devtest`; `main` is the source of truth.

- `staging` and `production` keep their names for now. The AWS accounts are
  `omnistools-preprod` / `omnistools-newprod` and the GitHub environments are
  `staging` / `prod`; revisiting those names is deferred.
- `ai/dev` and `ai/stage` already match the `ai-dev` / `ai-stage` environments.
- **Transition:** until the rename is done, these repos still use `dev` as the
  dev branch (TFC workspace `dev-*` tracks it): `infra-omnis`, `infra-iam`,
  `infra-shared`, `infra-stateless`, `omnis-serverless`, `report-lambda-omnis`.
  `backend-omnis` and `frontend-omnis` already use `devtest`. Treat `dev` as a
  legacy alias for `devtest` in those repos and do not create new `dev` branches
  elsewhere. `dev-report-lambda-omnis` also tracks `main` today and is to be
  moved to `devtest`.
- Terraform Cloud project names (`Dev`, `Staging`, `Prod`, ...) and workspace
  names (`dev-{repo}`) are unchanged by the branch rule.

### Per-repo files

Each repo keeps `.kiro/steering/aws-environments.md` containing a pointer to this
file and only its own details: the TFC workspace names for that repo, its
current dev branch name (`devtest` or the legacy `dev`), and any repo-specific
deploy notes.

## WordPress hosting accounts (OmnisTools & OmnisRisk marketing sites)

The five lanes above describe the **backend-omnis application**. The public
**WordPress** marketing sites (`omnistools.com`, `omnisrisk.com`, and their
`dev.` variants) are a separate workload with their own set of accounts and are
**not** part of the Standard five-lane promotion flow. The WordPress
CloudFormation stacks live under `OmnisToolsAWS/CloudFormation/WordPress/`
(`01-VPC` → `06-WPDashboard`) and are keyed off the `AWS::AccountId` in
`05-WPALB.yaml` (the `isTools`/`isRisk`/`isProd`/`isNonProd` conditions).

| Property   | Site(s)                                      | Lane | AWS Account ID | Local `aws --profile` |
| ---------- | -------------------------------------------- | ---- | -------------- | --------------------- |
| OmnisTools | `dev.omnistools.com`                         | dev  | `885102939857` | `omnistools-dev`      |
| OmnisTools | `omnistools.com` / `www.omnistools.com`      | prod | `075502354537` | `omnistools-prod`     |
| OmnisRisk  | `dev.omnisrisk.com`                          | dev  | `184243409136` | `omnisrisk-dev`       |
| OmnisRisk  | `omnisrisk.com` / `www.omnisrisk.com`        | prod | `416417230199` | `omnisrisk-prod`      |

Notes that avoid the common foot-guns:

- **OmnisTools WordPress shares the AI-track accounts.** The OmnisTools
  WordPress dev/prod sites are hosted in `885102939857` (= the `ai-dev` lane
  account) and `075502354537` (= the `ai-stage` lane account). This is
  intentional and historical — the OmnisTools WordPress site is **not** hosted
  in the Standard-flow `production` account `526272178819`. When a tool or
  script says "omnistools / prod" for WordPress it means `075502354537`, **not**
  `526272178819`. Do not "correct" WordPress account IDs to the Standard-flow
  prod account.
- **OmnisRisk has its own two accounts**, `184243409136` (dev) and
  `416417230199` (prod), used only for the OmnisRisk WordPress site. These are
  separate from every backend-omnis lane and from the OmnisTools WordPress
  accounts.
- These four account IDs are the ones hard-coded in the WordPress secret
  rotation helpers (`CloudFormation/WordPress/rotate-wp-admin-password.sh`,
  `rotate-db-password.sh`) and asserted by their `expected_account()` identity
  guard. The guard fails closed, so running with the wrong `--profile` is
  refused rather than mis-targeted.
- WordPress compute/ALB/RDS run in `us-west-2`. The SSM SecureString secrets
  (`/wordpress/<property>/<lane>/{admin_password,db_password}`) currently live
  in `us-west-1` for historical Updraft reasons — this is a **known deviation
  being remediated** (move to `us-west-2`, tracked in issue #18); secrets should
  be co-located with the app region, not cross-region.

## Promotion Flow

- Standard: `main` → feature `branch` → (PR) `devtest` → `staging` → `production` → (PR) `main`
- AI: `ai/dev` → `ai/stage`

`main` is the source of truth. Feature work is cut from `main`, enters the
lanes at `devtest`, and returns to `main` after production:

1. **Develop.** Cut a short-lived feature `branch` from `main`. Open a PR into
   `devtest` and merge it after review. Nothing is committed to `main` or to a
   lane branch directly.
2. **Promote.** Each merge into `devtest` or `staging` opens the next promotion
   PR (`devtest` → `staging`, `staging` → `production`). A human reviews and
   merges each one; Terraform Cloud applies stay manual-confirm.
3. **Reconcile.** After a release reaches `production`, open a PR
   `production` → `main` so trunk and the lanes agree. New branches are then cut
   from `main`, which makes `devtest` identical to `main` except for work still
   in flight through the lanes.

Never skip a lane, and never promote backwards (no `staging` → `devtest`).
Hotfixes follow the same path unless the user explicitly approves otherwise.

### AI Track Isolation

The AI track is deliberately separate from the Standard flow and must stay that way.

- **The AI track forks from `production`.** `ai/dev` is cut from `production` — never from `main`, `devtest`, or `staging`. `ai/stage` is not cut from `production`; it is created and updated only by the AI promotion flow from `ai/dev`.
- **AI work never writes to a Standard-flow branch.** `main`, `devtest`, `staging`, and `production` are read-only to AI-lane work. Reading any of them is fine — fetch, log, diff. Beyond reading, exactly two operations may consume a Standard-flow branch, and both are scoped to `production`: cutting `ai/dev` from it, and merging it forward into `ai/dev`. Never use `main`, `devtest`, or `staging` as the source for either. Committing, merging, or pushing *to* any Standard-flow branch is prohibited.
- **AI promotion automation lives on the AI branches.** `promote-ai.yml` on `ai/dev` drives `ai/dev` → `ai/stage`. The Standard flow's `promote.yml` is never modified to serve the AI lanes.
- **The two flows never cross-promote.** There is no promotion from `ai/stage` into `staging`, `production`, or `main`, and no Standard lane promotes into an AI lane. The one permitted Standard→AI operation is *synchronization*, not promotion: merge `production` forward into `ai/dev` to pick up Standard-flow changes.
- **Why:** the AI lanes deploy to their own AWS accounts (ai-dev `885102939857`, ai-stage `075502354537`). An AI proof-of-concept must not be able to disturb the release path for the production system.

## Conventions

- **Region by workload type** — do not assume a single global region:
  - **App / regional workloads → `us-west-2`** (EKS, ALB, RDS, backend-omnis lanes, WordPress compute). Secrets (SSM SecureString) live in the **same region as the app** — never cross-region.
  - **Global / non-region-specific infrastructure → `us-east-1`** (IAM roles, Route53, and anything not tied to a region always deploys here).
- IAM role is always `github-actions-deploy` in every account (provisioned by the `infra-iam` TFC workspace).
- Use OIDC (`role-to-assume`) in GitHub Actions — never use static IAM access keys.
- Each GitHub environment exposes exactly two variables: `AWS_ROLE_ARN` and `AWS_DEFAULT_REGION`.
- TFC workspace naming pattern: `{prefix}-{repo-name}` where the prefix is the TFC project, lowercased: `dev` (for the `devtest` lane), `staging`, `prod`, `ai-dev`, `ai-stage`. The `devtest` lane's workspaces use the `dev-` prefix (e.g. `dev-backend-omnis`), never `devtest-`.
- TFC workspaces are grouped by lane into TFC Projects: `Dev`, `Staging`, `Prod`, `AI-Dev`, `AI-Staging`.

## Tooling Responsibilities

| Tool            | Responsibility                                            |
| --------------- | --------------------------------------------------------- |
| Terraform Cloud | Infrastructure provisioning (TFC workspace per lane)      |
| GitHub Actions  | App deployment: Docker build → ECR push → `helm upgrade`  |

## Rules for AI Assistants

- When generating CI/CD workflows, always use OIDC (`role-to-assume`) — never `aws-access-key-id` / `aws-secret-access-key`.
- When referencing an environment, use the lane name and its corresponding account ID from the table above.
- Infrastructure changes go through TFC; application changes go through GitHub Actions — do not conflate the two.
- Never suggest creating new IAM roles for deployment; `github-actions-deploy` already exists in every account.
- When creating a new TFC workspace, place it in the correct TFC Project matching its lane.
- When running any `aws` CLI command locally, ALWAYS use `--profile <profile>`. For **application lanes** (backend-omnis and the infra repos), match the lane: devtest → `omnistools-devtest`, staging → `omnistools-preprod`, prod → `omnistools-newprod`, ai-dev → `omnistools-dev`, ai-stage → `omnistools-prod`. For **WordPress** (OmnisTools / OmnisRisk marketing sites), do not use this mapping: select the profile from the WordPress hosting table above (`omnistools-dev`, `omnistools-prod`, `omnisrisk-dev`, `omnisrisk-prod`).
- NEVER run `aws` CLI commands without `--profile` — they will fail with NoCredentials.
- AI-lane work MUST NOT commit, merge, or push to `main`, `devtest`, `staging`, or `production` — those branches are read-only to the AI track. Cut and update `ai/dev` from `production` instead, and let the AI promotion flow create and update `ai/stage` from `ai/dev`.
- When an AI branch needs Standard-flow changes, merge `production` forward into `ai/dev`. This synchronization merge is permitted; promoting or cherry-picking from an AI branch into a Standard-flow branch is not.
