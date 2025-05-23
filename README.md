# Azure Site Recovery (ASR) with Platform-Managed Keys POC

This project demonstrates Azure Site Recovery (ASR) capabilities for Azure-to-Azure VM replication with Server-Side Encryption using Platform-Managed Keys (SSE-PMK). The infrastructure is managed using Pulumi with Azure Blob Storage as the state backend.

- [Azure Site Recovery (ASR) with Platform-Managed Keys POC](#azure-site-recovery-asr-with-platform-managed-keys-poc)
  - [Key Components](#key-components)
  - [Getting Started](#getting-started)
    - [Pulumi State Backend Setup](#pulumi-state-backend-setup)
      - [Quick Start](#quick-start)
      - [Prerequisites](#prerequisites)
      - [What Gets Created](#what-gets-created)
      - [Manual Commands (if needed)](#manual-commands-if-needed)
      - [Troubleshooting](#troubleshooting)
      - [Cleanup](#cleanup)
    - [Pulumi Configuration](#pulumi-configuration)
      - [Configuration File Setup](#configuration-file-setup)
      - [Required Configuration Values](#required-configuration-values)
      - [Setting Configuration Values](#setting-configuration-values)
    - [Deployment](#deployment)

## Key Components

- Source VM with SSE-PMK encryption
- Recovery Services Vault for ASR
- Azure-to-Azure replication configuration
- Target region infrastructure for failover

## Getting Started

### Pulumi State Backend Setup

Before deploying the ASR infrastructure, you need to set up the Pulumi state backend using Azure Blob Storage.

#### Quick Start

```bash
# 1. Setup backend
./setup-pulumi-backend.sh


# 2. Validate setup
./validate-backend.sh
```

#### Prerequisites

- Azure CLI installed and logged in (`az login`)
- Appropriate Azure permissions (create resources, assign RBAC)
- Pulumi CLI installed (optional - can be done later)

#### What Gets Created

| Resource | Name | Purpose |
|----------|------|---------|
| Resource Group | `pulumi-state-rg` | Container for backend resources |
| Storage Account | `pulumistate<suffix>` | Stores Pulumi state files |
| Blob Container | `pulumi-backend` | Container for state blobs |
| RBAC Role | Storage Blob Data Contributor | Access permissions |

**Backend URL:** `azblob://pulumi-backend`

#### Manual Commands (if needed)

```bash
# Prerequisites
az login
az account set --subscription "<SUBSCRIPTION_ID>"


# Configure Pulumi
export AZURE_STORAGE_ACCOUNT=pulumistate<suffix>
pulumi login azblob://pulumi-backend
```

#### Troubleshooting

**Check current backend:**

```bash
pulumi whoami -v
```

**Re-login to backend:**

```bash
pulumi login azblob://pulumi-backend
```

**Verify Azure resources:**

```bash
az group show --name pulumi-state-rg
az storage account list --resource-group pulumi-state-rg
```

#### Cleanup

```bash
# Delete Pulumi resources first
pulumi destroy


# Then delete backend resources
az group delete --name pulumi-state-rg
```

⚠️ **Warning:** Deleting the backend makes it harder to manage remaining Pulumi resources.

### Pulumi Configuration

Since `Pulumi.dev.yaml` is excluded from version control for security reasons, you need to create and configure it locally after setting up the backend.

#### Configuration File Setup

Create a `Pulumi.dev.yaml` file in the project root with the following structure:

```yaml
encryptionsalt: v1:Nbyai7cCbXw=:v1:V+X0OMAPW+Vc7TtY:eC9aesY108uutfwbI2IlmePhCfLG+A==
config:
  azure-native:location: eastus
  pulumi-asr-pmk-poc:targetLocation: westus
  pulumi-asr-pmk-poc:resourceGroupNamePrefix: pmkAsrPoc
  pulumi-asr-pmk-poc:vmAdminUsername: azureuser
  pulumi-asr-pmk-poc:vmAdminPassword:
    secure: v1:DmE5mEeNw76HMFPQ:tPHKJwWydH/GoMwLfH9nQG1ZUDR8sdr+qo6oFQ==
  pulumi-asr-pmk-poc:sourceVmName: sourcevm-pmk
  pulumi-asr-pmk-poc:vmSize: Standard_DS2_v2
  pulumi-asr-pmk-poc:sourceVmImagePublisher: Canonical
  pulumi-asr-pmk-poc:sourceVmImageOffer: 0001-com-ubuntu-server-jammy
  pulumi-asr-pmk-poc:sourceVmImageSku: 22_04-lts-gen2
  pulumi-asr-pmk-poc:sourceVmImageVersion: latest
```

#### Required Configuration Values

| Configuration Key | Description | Example Value |
|-------------------|-------------|---------------|
| `azure-native:location` | Primary Azure region for source resources | `eastus` |
| `pulumi-asr-pmk-poc:targetLocation` | Target Azure region for ASR replication | `westus` |
| `pulumi-asr-pmk-poc:resourceGroupNamePrefix` | Prefix for resource group names | `pmkAsrPoc` |
| `pulumi-asr-pmk-poc:vmAdminUsername` | VM administrator username | `azureuser` |
| `pulumi-asr-pmk-poc:vmAdminPassword` | VM administrator password (encrypted) | `<secure_value>` |
| `pulumi-asr-pmk-poc:sourceVmName` | Name of the source VM | `sourcevm-pmk` |
| `pulumi-asr-pmk-poc:vmSize` | Azure VM size | `Standard_DS2_v2` |
| `pulumi-asr-pmk-poc:sourceVmImagePublisher` | VM image publisher | `Canonical` |
| `pulumi-asr-pmk-poc:sourceVmImageOffer` | VM image offer | `0001-com-ubuntu-server-jammy` |
| `pulumi-asr-pmk-poc:sourceVmImageSku` | VM image SKU | `22_04-lts-gen2` |
| `pulumi-asr-pmk-poc:sourceVmImageVersion` | VM image version | `latest` |

#### Setting Configuration Values

You can set configuration values using the Pulumi CLI:

```bash
# Set basic configuration
pulumi config set azure-native:location eastus
pulumi config set pulumi-asr-pmk-poc:targetLocation westus
pulumi config set pulumi-asr-pmk-poc:resourceGroupNamePrefix pmkAsrPoc
pulumi config set pulumi-asr-pmk-poc:vmAdminUsername azureuser
pulumi config set pulumi-asr-pmk-poc:sourceVmName sourcevm-pmk
pulumi config set pulumi-asr-pmk-poc:vmSize Standard_DS2_v2

# Set VM image configuration
pulumi config set pulumi-asr-pmk-poc:sourceVmImagePublisher Canonical
pulumi config set pulumi-asr-pmk-poc:sourceVmImageOffer 0001-com-ubuntu-server-jammy
pulumi config set pulumi-asr-pmk-poc:sourceVmImageSku 22_04-lts-gen2
pulumi config set pulumi-asr-pmk-poc:sourceVmImageVersion latest

# Set secure password (will be encrypted automatically)
pulumi config set --secret pulumi-asr-pmk-poc:vmAdminPassword <your_secure_password>
```

**Important Notes:**
- The `vmAdminPassword` should be set as a secret using the `--secret` flag
- Ensure your password meets Azure VM password requirements (12+ characters, complexity requirements)
- The `encryptionsalt` is generated automatically when you first set a secret value
- All team members need to configure their own `Pulumi.dev.yaml` file locally

### Deployment

Once you have completed the backend setup and configuration, you can deploy the ASR infrastructure:

```bash
# Deploy the infrastructure
pulumi up
```

This command will:
1. Preview the resources to be created
2. Prompt for confirmation
3. Deploy the Azure Site Recovery infrastructure including:
   - Source VM with SSE-PMK encryption
   - Recovery Services Vault
   - Azure-to-Azure replication configuration
   - Target region infrastructure

**Note:** The deployment may take several minutes to complete, especially the ASR replication setup.
