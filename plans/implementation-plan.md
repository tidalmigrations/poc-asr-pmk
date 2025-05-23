# Detailed Plan & Checklist for Pulumi Stack (ASR with SSE-PMK POC - Part 1) with Azure Blob Storage Backend

**Phase -1: Configure Pulumi State Backend (Azure Blob Storage)**

* [x] **0.1. Prerequisites for Backend Setup:**
    * [x] Azure CLI installed and configured (`az login`).
    * [x] Desired Azure subscription selected (`az account set --subscription "<YOUR_BACKEND_SUBSCRIPTION_ID>"`). This can be the same or different from your POC resources' subscription.
* [x] **0.2. Create Azure Resources for Pulumi State Backend (Manual or via Azure CLI/Portal):**
    * *These resources are typically created outside of the Pulumi project they will manage, as they store the state for that project.*
    * [x] **Create a dedicated Resource Group for Pulumi State:**
        * Name suggestion: `pulumi-state-rg`
        * Location: Choose a suitable Azure region (e.g., `eastus`).
        * Command (Azure CLI): `az group create --name pulumi-state-rg --location eastus`
    * [x] **Create an Azure Storage Account for Pulumi State:**
        * Name suggestion: `pulumistate<unique_suffix>` (must be globally unique, lowercase, numbers only, 3-24 chars).
        * Resource Group: `pulumi-state-rg`
        * Location: Same as the resource group.
        * SKU: `Standard_LRS` (Locally-redundant storage is usually sufficient and cost-effective for state).
        * Kind: `StorageV2`
        * Command (Azure CLI): `az storage account create --name pulumistate<unique_suffix> --resource-group pulumi-state-rg --location eastus --sku Standard_LRS --kind StorageV2`
    * [x] **Create a Blob Container within the Storage Account:**
        * Name suggestion: `pulumi-backend` (or project-specific like `asr-pmk-poc-state`).
        * Storage Account Name: The one created above.
        * Public access level: `Private` (no anonymous access).
        * Command (Azure CLI - requires Storage Account Key or RBAC role):
            * Get storage account key: `az storage account keys list --resource-group pulumi-state-rg --account-name pulumistate<unique_suffix> --query "[0].value" -o tsv`
            * Set environment variable (temporary for this command): `AZURE_STORAGE_KEY="<your_storage_account_key>"`
            * Create container: `az storage container create --name pulumi-backend --account-name pulumistate<unique_suffix> --auth-mode key` (or use `--auth-mode login` if you have appropriate RBAC like "Storage Blob Data Contributor")
* [x] **0.3. Login to the Azure Blob Storage Backend with Pulumi:**
    * [x] Before initializing your Pulumi project (or if changing an existing project's backend), run:
        `pulumi login azblob://<container-name>`
        * Example: `pulumi login azblob://pulumi-backend`
    * [x] Pulumi will use your Azure CLI credentials by default. Ensure your Azure CLI user/service principal has permissions to the blob container (e.g., "Storage Blob Data Owner" or "Storage Blob Data Contributor" on the container or storage account).
    * [x] Alternatively, you can set environment variables for Pulumi to use a specific storage account key (less recommended for user accounts, more for CI/CD with service principals):
        * `AZURE_STORAGE_ACCOUNT`: Your storage account name (e.g., `pulumistate<unique_suffix>`)
        * `AZURE_STORAGE_KEY`: The access key for the storage account.

**✅ Phase -1 Complete: Automated via `setup-pulumi-backend.sh` and `validate-backend.sh` scripts**

**Phase 0: Project Setup & Prerequisites (for POC Infrastructure)**

* [x] **1. Initialize Pulumi Project (if not already done after `pulumi login`):**
    * [x] Create a new directory for your project (e.g., `pulumi-asr-pmk-poc`).
    * [x] Change into the directory.
    * [x] Run `pulumi new azure-typescript` (or `azure-typescript`). *If you ran `pulumi login` to the Azure backend *before* `pulumi new`, the project will automatically be configured to use that backend.*
    * [x] Ensure you are logged into the Azure CLI (`az login`) for deploying POC resources.
    * [x] Set the desired Azure subscription for POC resources (`az account set --subscription "<YOUR_POC_SUBSCRIPTION_ID>"`).
* [x] **2. Define Pulumi Configuration:**
    * [x] Open `Pulumi.dev.yaml` (or your current stack's YAML).
    * [x] Define essential configuration variables:
        * [x] `azure-native:location`: Primary (source) Azure region (e.g., `eastus`).
        * [x] `targetLocation`: Secondary (target/DR) Azure region (e.g., `westus`).
        * [x] `resourceGroupNamePrefix`: A prefix for all resource group names (e.g., `pmkAsrPoc`).
        * [x] `vmAdminUsername`: Admin username for the source VM.
        * [x] `vmAdminPassword`: Admin password for the source VM (use Pulumi secrets: `pulumi config set --secret vmAdminPassword`).
        * [x] `sourceVmName`: Name for the source VM (e.g., `sourcevm-pmk`).
        * [x] `vmSize`: Azure VM size (e.g., `Standard_DS2_v2`).
        * [x] Optional: `sourceVmImagePublisher`, `sourceVmImageOffer`, `sourceVmImageSku`, `sourceVmImageVersion` (e.g., for a specific Windows or Linux image). Default can be a common Ubuntu LTS or Windows Server.

**Phase 1: Core Infrastructure - Resource Groups & Networking**

* [x] **3. Create Resource Groups:**
    * [x] **Source Resource Group:**
        * Name: `{config.resourceGroupNamePrefix}-source-rg`
        * Location: `config.azure-native:location`
        * Pulumi Resource: `azure_native.resources.ResourceGroup`
    * [x] **Target Resource Group:**
        * Name: `{config.resourceGroupNamePrefix}-target-rg`
        * Location: `config.targetLocation`
        * Pulumi Resource: `azure_native.resources.ResourceGroup`
    * [x] **Recovery Services Resource Group:**
        * Name: `{config.resourceGroupNamePrefix}-recovery-rg`
        * Location: `config.targetLocation` (or as desired)
        * Pulumi Resource: `azure_native.resources.ResourceGroup`
* [x] **4. Setup Source Region Networking:**
    * [x] **Source Virtual Network (VNet):**
        * Name: `source-vnet`
        * Resource Group: Source Resource Group
        * Location: `config.azure-native:location`
        * Address Space: e.g., `10.0.0.0/16`
        * Pulumi Resource: `azure_native.network.VirtualNetwork`
    * [x] **Source Subnet:**
        * Name: `source-subnet`
        * Resource Group: Source Resource Group
        * VNet Name: Source VNet
        * Address Prefix: e.g., `10.0.1.0/24`
        * Pulumi Resource: `azure_native.network.Subnet`
* [x] **5. Setup Target Region Networking (for Failover):**
    * [x] **Target Virtual Network (VNet):**
        * Name: `target-vnet`
        * Resource Group: Target Resource Group
        * Location: `config.targetLocation`
        * Address Space: e.g., `10.1.0.0/16`
        * Pulumi Resource: `azure_native.network.VirtualNetwork`
    * [x] **Target Subnet:**
        * Name: `target-subnet`
        * Resource Group: Target Resource Group
        * VNet Name: Target VNet
        * Address Prefix: e.g., `10.1.1.0/24`
        * Pulumi Resource: `azure_native.network.Subnet`

**Phase 2: Recovery Services Vault & ASR Primitives**

* [x] **6. Create Recovery Services Vault (RSV):**
    * Name: `{config.resourceGroupNamePrefix}-rsv`
    * Resource Group: Recovery Services Resource Group
    * Location: Location of Recovery Services Resource Group
    * SKU: `Standard`
    * Properties: `publicNetworkAccess`: `Enabled`
    * Pulumi Resource: `azure_native.recoveryservices.Vault`
* [x] **7. (Optional but Recommended) Create ASR Cache Storage Account:**
    * Name: `asr{config.resourceGroupNamePrefix.lower().replace("-","")}cache`
    * Resource Group: Source Resource Group
    * Location: `config.azure-native:location`
    * SKU: `Standard_LRS`
    * Kind: `StorageV2`
    * Pulumi Resource: `azure_native.storage.StorageAccount`
* [x] **8. Define ASR Replication Policy:**
    * Name: `asr-pmk-policy`
    * Resource Group: Recovery Services Resource Group
    * Vault Name: Recovery Services Vault name
    * Properties: A2A policy with `appConsistentFrequencyInMinutes`: `240`, `crashConsistentFrequencyInMinutes`: `5`, `recoveryPointHistory`: `1440`
    * Pulumi Resource: `azure_native.recoveryservices.ReplicationPolicy`

**Phase 3: Source Virtual Machine**

* [ ] **9. Create Network Interface (NIC) for Source VM:**
    * Name: `{config.sourceVmName}-nic`
    * Resource Group: Source Resource Group
    * Location: `config.azure-native:location`
    * IP Configuration: Name: `ipconfig1`, Subnet ID: Source Subnet ID, Private IP Allocation: `Dynamic`
    * Pulumi Resource: `azure_native.network.NetworkInterface`
* [ ] **10. Create Source Virtual Machine:**
    * Name: `config.sourceVmName`
    * Resource Group: Source Resource Group
    * Location: `config.azure-native:location`
    * Hardware Profile: `vmSize`: `config.vmSize`
    * Storage Profile: Image Reference (as per config), OS Disk (Name: `{config.sourceVmName}-osdisk`, Create Option: `FromImage`, Managed Disk Type: `Standard_LRS` or `Premium_LRS`), Optional Data Disk (Name: `{config.sourceVmName}-datadisk-01`, Create Option: `Empty`, Size: `32GB`, LUN: `0`, Managed Disk Type: `Standard_LRS`)
    * OS Profile: Computer Name: `config.sourceVmName`, Admin Username: `config.vmAdminUsername`, Admin Password: `config.vmAdminPassword`
    * Network Profile: Network Interface ID: Source VM NIC ID
    * Pulumi Resource: `azure_native.compute.VirtualMachine`

**Phase 4: ASR Configuration for VM Replication (Azure-to-Azure)**

* [ ] **11. Create ASR Fabric (Azure):** (Conceptual - often implicitly handled)
* [ ] **12. Create ASR Protection Container:**
    * Name: `asr-protection-container-source`
    * Resource Group: Recovery Services Resource Group
    * Vault Name: Recovery Services Vault name
    * Fabric Name: Source Azure fabric name
    * Pulumi Resource: `azure_native.recoveryservices.ReplicationProtectionContainer`
* [ ] **13. Create ASR Protection Container Mapping:**
    * Name: `asr-container-mapping`
    * Resource Group: Recovery Services Resource Group
    * Vault Name: Recovery Services Vault name
    * Fabric Name: Azure fabric name
    * Protection Container Name: ASR Protection Container name
    * Properties: `targetProtectionContainerId`: Target protection container ID, `policyId`: ASR Replication Policy ID, `instanceType`: `AzureToAzure`
    * Pulumi Resource: `azure_native.recoveryservices.ReplicationProtectionContainerMapping`
* [ ] **14. Enable Replication for the VM (Replication Protected Item):**
    * Name: `{config.sourceVmName}-rpi`
    * Resource Group: Recovery Services Resource Group
    * Vault Name: Recovery Services Vault name
    * Fabric Name: Source Azure fabric name
    * Protection Container Name: ASR Protection Container name
    * Properties: `sourceVmId`: Source VM ID, `policyId`: ASR Replication Policy ID, `providerSpecificDetails` (`instanceType: "AzureToAzure"`): `targetResourceId`: Target RG ID, `targetResourceGroupId`: Target RG ID, `targetVmName`: `{config.sourceVmName}-dr`, `targetVnetId`: Target VNet ID, `targetSubnetName`: Target Subnet Name, `recoveryResourceGroupId`: Target RG ID, `cacheStorageAccountId`: Cache Storage Account ID, `managedDisks`: (OS and Data disks, `diskId`, `stagingStorageAccountId`, `targetManagedDiskType`. **No `diskEncryptionSetId` for PMK**).
    * Pulumi Resource: `azure_native.recoveryservices.ReplicationProtectedItem`

**Phase 5: Deployment & Initial Verification**

* [ ] **15. Deploy the Stack:**
    * [ ] Run `pulumi up`.
    * [ ] Review the preview and confirm.
* [ ] **16. Define Pulumi Stack Outputs:**
    * [ ] Source VM ID, Source VM Public IP (if any), RSV Name & ID, Replication Protected Item Name & ID.
* [ ] **17. Initial Portal/CLI Verification (Post `pulumi up`):**
    * [ ] Check resource creation.
    * [ ] **Verify Source VM Disk Encryption:** (Portal/CLI) "SSE with platform-managed key".
    * [ ] Check RSV -> Replicated Items for VM status (progressing to "Protected").

**Phase 6: ASR Specific Testing (Manual Steps - as per your document 1.3)**

* [ ] **18. Wait for Initial Replication to Complete.**
* [ ] **19. Perform a Test Failover** (RSV -> Replicated Items -> Test failover -> Select recovery point & Target VNet).
* [ ] **20. Verify Failed-Over Test VM:**
    * [ ] Connect and check functionality.
    * [ ] **Verify disk encryption on TEST VM** (Portal/CLI): "SSE with platform-managed key".
* [ ] **21. Cleanup Test Failover** (RSV -> Replicated items -> Cleanup test failover).

**Phase 7: Cleanup**

* [ ] **22. Destroy Pulumi Stack (POC Resources):**
    * [ ] `pulumi destroy`.
* [ ] **23. (Optional) Cleanup Pulumi State Backend Resources (Manual or via Azure CLI/Portal):**
    * [ ] If you no longer need the state backend storage account and container, you can delete them.
        * `az storage container delete --name pulumi-backend --account-name pulumistate<unique_suffix> --auth-mode key`
        * `az storage account delete --name pulumistate<unique_suffix> --resource-group pulumi-state-rg`
        * `az group delete --name pulumi-state-rg`
    * *Be cautious: deleting the state backend makes it harder to manage any remaining resources from that stack.*

---

This updated plan now includes the crucial steps for setting up and using Azure Blob Storage as your Pulumi backend. Remember to execute the Phase -1 steps *before* you start creating the Pulumi project for your POC infrastructure, or ensure your project is correctly configured to use this backend if it already exists.