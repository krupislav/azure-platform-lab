# azure-platform-lab

The **platform** side of an Azure landing zone, built with Terraform: state storage,
the shared hub network, and onboarding of new environments.

The environments themselves (dev, later stage and prod) and the workloads running in
them live in a separate repo: **azure-platform-envs**.

> Lab project for AZ-104 / AZ-400 practice. Not a production system.

## Why two repos

| Repo | What it holds | Who runs it |
|---|---|---|
| **azure-platform-lab** (this one) | Things that grant access or are shared by every environment | Platform admin, from their PC |
| **azure-platform-envs** | One environment's infrastructure, then its workloads | GitHub Actions pipeline, one identity per environment |

The rule behind the split: **a pipeline never manages its own permissions.** The env
pipeline has Contributor, which cannot assign roles, and it has no Microsoft Graph
rights, so it cannot create groups. Everything that needs those rights lives here.

## The layers

Run in this order. Each layer has its own state file, so a mistake in one can't touch
the others.

| # | Layer | Folder | State file | What it creates |
|---|---|---|---|---|
| 1 | **bootstrap** | `infra/bootstrap` | `bootstrap.tfstate` | Where Terraform keeps its state |
| 2 | **global** | `infra/global` | `global.tfstate` | The hub and the shared services, once for all environments |
| 3 | **onboarding** | `infra/onboarding` | `onboarding.tfstate` | Everything an environment needs *before* its own pipeline can run |

### 1. bootstrap: the state storage

Resource group `rg-tfstate-cc`:

- Storage account `sttfstate0`, container `tfstate`: one state file per layer and environment.
- Protection: GZRS, blob versioning, 7-day soft delete for blobs and containers,
  `prevent_destroy`, and an Azure `CanNotDelete` lock.
- Access: no storage keys (Entra sign-in only). Roles go to groups, not people:
  - `sg-tfstate-admins`: Storage Blob Data Contributor (read and write)
  - `sg-tfstate-readers`: Storage Blob Data Reader, on the `tfstate` container only

It was built by hand first (its state needs somewhere to live), then taken over with
`import` blocks. It changes rarely and is always run by hand.

### 2. global: the hub and shared services

Resource group `rg-hub-cc` (network):

- Hub VNet `vnet-hub-cc` (`10.20.0.0/16`) with subnets for the VPN gateway, Firewall,
  Bastion and Application Gateway (most of them used later)
- **Private DNS zones** for blob and Key Vault, linked to the hub. One zone per
  service, shared by every spoke.

Resource group `rg-shared-cc` (shared services):

- Log Analytics workspace `log-shared-cc`: all environments send logs here.
- Container registry `acrshared0`: an image is built once and promoted between environments.

### 3. onboarding: a new environment's front door

For each environment in `local.environments` (today: `dev`):

| Creates | Why it can't be in the env pipeline |
|---|---|
| Resource group `rg-<env>-cc` | Roles below are scoped to it, so it must exist first |
| Managed identity `id-github-<env>` | This *is* the pipeline's identity |
| Federated credentials `fc-pr` and `fc-env-<env>` | They trust the env repo's GitHub OIDC tokens: PRs for plan, the `<env>` environment for apply. No secrets. |
| Contributor on `rg-<env>-cc` | A pipeline can't grant itself access |
| Network Contributor on `rg-hub-cc` | The spoke's peering and DNS links live in the hub's RG |
| Membership in `sg-tfstate-admins` | So the pipeline can read and write its state |
| Groups `sg-kv-<env>-admins` and `-readers`, with Key Vault roles on the RG | Creating groups needs Graph rights |

**Group membership is not in Terraform.** Terraform creates the groups and their
roles. Adding or removing people is an admin task done after onboarding, so joiners
and leavers never need a code change.

To onboard a new environment: add it to `local.environments`, run plan and apply here,
then create its folder in azure-platform-envs.

## Conventions

- Names: `<type>-<purpose>-<env>-cc` (`cc` = Canada Central).
- Every resource gets an `env` tag (`global` here). A policy on the management group requires it.
- No subscription, tenant or client IDs in this repo. Terraform reads the subscription
  from `ARM_SUBSCRIPTION_ID`.

## Running a layer

```powershell
az account show --query user.name -o tsv   # check who you are first
cd infra/<layer>
terraform init
terraform plan
terraform apply
```

## Known gaps (to fix later)

- `sg-tfstate-admins` can write every state file. Each environment should only reach its own.
- No pipeline here yet. Planned: a locked-down platform pipeline with approvals, plus a
  scheduled drift check (`plan -detailed-exitcode`).
- No branch protection on `main` yet.

## How the layers build on each other

Each layer is something the layers after it depend on:

| Layer | What it creates | What it gives the layers after it | What breaks without it |
|---|---|---|---|
| **1. bootstrap**<br>(admin, by hand) | `sttfstate0` + `tfstate` container<br>`sg-tfstate-admins` / `-readers` | **A place for every state file:** global, onboarding and dev all keep their state here.<br>**The tfstate admins group:** onboarding adds the pipeline identity to it, so the pipeline can read and write `dev.tfstate`. | No layer can `terraform init`, because there's nowhere to keep or lock state. |
| **2. global**<br>(admin) | `rg-hub-cc`: hub VNet, private DNS zones<br>`rg-shared-cc`: Log Analytics, `acrshared0` | **To onboarding:** `rg-hub-cc` exists, so it can give the pipeline Network Contributor there.<br>**To dev:** the hub VNet to peer with, the DNS zones to link and to register the Key Vault record in, and later ACR for images and Log Analytics for logs. | dev can't peer or resolve `privatelink` names, and every spoke would build its own copy. |
| **3. onboarding**<br>(admin rights) | `rg-dev-cc`<br>`id-github-dev` + `fc-pr`, `fc-env-dev`<br>Contributor on rg-dev, Network Contributor on rg-hub<br>membership in `sg-tfstate-admins`<br>`sg-kv-dev-admins` / `-readers` + Key Vault roles | **To dev's pipeline:** an empty RG to build in, an identity GitHub can log in as with no password, and exactly the rights it needs: build in rg-dev, add peering and DNS links in rg-hub, write its state.<br>**To people:** the groups are already set up to reach the vault once it exists. | The pipeline can't log in, has nowhere to build, and can't grant itself rights, because Contributor can't assign roles. |
| **4. dev**<br>(pipeline, in azure-platform-envs) | spoke VNet, subnets, NSGs, peering, DNS links, Key Vault + private endpoint | **To workloads (next):** a network to run in, a private Key Vault for secrets, and a path to the hub. | Nothing to deploy the app into. |

In short, each layer sets up something the next one needs:
- **bootstrap**: *where* state lives
- **global**: *what* is shared
- **onboarding**: *who* may build, and *where*
- **dev**: *what* the app runs on
