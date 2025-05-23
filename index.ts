import * as pulumi from "@pulumi/pulumi";
import * as resources from "@pulumi/azure-native/resources";
import * as network from "@pulumi/azure-native/network";
import * as recoveryservices from "@pulumi/azure-native/recoveryservices";
import * as storage from "@pulumi/azure-native/storage";
import * as compute from "@pulumi/azure-native/compute";
import * as authorization from "@pulumi/azure-native/authorization";
import * as command from "@pulumi/command";

// Azure Site Recovery Operating System Support Notes:
// 
// According to https://aka.ms/a2a_supported_linux_os_versions:
// - Ubuntu 20.04 LTS: Supported kernels include 5.4.x, 5.8.x, 5.11.x, 5.13.x series
// - Ubuntu 22.04 LTS: Limited support, newer kernels (6.x series) may not be supported
// - RHEL 7.x, 8.x, 9.x: Various kernel versions supported
// - SUSE Linux Enterprise Server 12 SP3+, 15+: Supported
// - CentOS 7.x, 8.x: Supported with specific kernel versions
//
// For the most current list, always refer to: https://aka.ms/a2a_supported_linux_os_versions
// This deployment uses Ubuntu 20.04 LTS for maximum ASR compatibility

// Get current Azure client configuration
const clientConfig = authorization.getClientConfig();

// Get configuration values
const config = new pulumi.Config();
const azureConfig = new pulumi.Config("azure-native");
const location = azureConfig.require("location");
const targetLocation = config.require("targetLocation");
const resourceGroupNamePrefix = config.require("resourceGroupNamePrefix");
const vmAdminUsername = config.require("vmAdminUsername");
const vmAdminPassword = config.requireSecret("vmAdminPassword");
const sourceVmName = config.require("sourceVmName");
const vmSize = config.require("vmSize");

// VM Image Configuration - Using Ubuntu 20.04 LTS for Azure Site Recovery compatibility
// Note: Azure Site Recovery has specific OS support requirements
// See: https://aka.ms/a2a_supported_linux_os_versions
// Ubuntu 20.04 LTS has better ASR support than 22.04 LTS
const sourceVmImagePublisher = config.get("sourceVmImagePublisher") || "Canonical";
const sourceVmImageOffer = config.get("sourceVmImageOffer") || "0001-com-ubuntu-server-focal";
const sourceVmImageSku = config.get("sourceVmImageSku") || "20_04-lts-gen2";
const sourceVmImageVersion = config.get("sourceVmImageVersion") || "latest";

// Phase 1: Core Infrastructure - Resource Groups & Networking

// 3. Create Resource Groups

// Source Resource Group
const sourceResourceGroup = new resources.ResourceGroup("sourceResourceGroup", {
    resourceGroupName: `${resourceGroupNamePrefix}-source-rg`,
    location: location,
});

// Target Resource Group
const targetResourceGroup = new resources.ResourceGroup("targetResourceGroup", {
    resourceGroupName: `${resourceGroupNamePrefix}-target-rg`,
    location: targetLocation,
});

// Recovery Services Resource Group
const recoveryResourceGroup = new resources.ResourceGroup("recoveryResourceGroup", {
    resourceGroupName: `${resourceGroupNamePrefix}-recovery-rg`,
    location: targetLocation,
});

// 4. Setup Source Region Networking

// Source Virtual Network (VNet)
const sourceVNet = new network.VirtualNetwork("sourceVNet", {
    virtualNetworkName: "source-vnet",
    resourceGroupName: sourceResourceGroup.name,
    location: location,
    addressSpace: {
        addressPrefixes: ["10.0.0.0/16"],
    },
});

// Source Subnet
const sourceSubnet = new network.Subnet("sourceSubnet", {
    subnetName: "source-subnet",
    resourceGroupName: sourceResourceGroup.name,
    virtualNetworkName: sourceVNet.name,
    addressPrefix: "10.0.1.0/24",
});

// 5. Setup Target Region Networking (for Failover)

// Target Virtual Network (VNet)
const targetVNet = new network.VirtualNetwork("targetVNet", {
    virtualNetworkName: "target-vnet",
    resourceGroupName: targetResourceGroup.name,
    location: targetLocation,
    addressSpace: {
        addressPrefixes: ["10.1.0.0/16"],
    },
});

// Target Subnet
const targetSubnet = new network.Subnet("targetSubnet", {
    subnetName: "target-subnet",
    resourceGroupName: targetResourceGroup.name,
    virtualNetworkName: targetVNet.name,
    addressPrefix: "10.1.1.0/24",
});

// Export important resource information for later phases
export const sourceResourceGroupName = sourceResourceGroup.name;
export const sourceResourceGroupId = sourceResourceGroup.id;
export const targetResourceGroupName = targetResourceGroup.name;
export const targetResourceGroupId = targetResourceGroup.id;
export const recoveryResourceGroupName = recoveryResourceGroup.name;
export const recoveryResourceGroupId = recoveryResourceGroup.id;

export const sourceVNetName = sourceVNet.name;
export const sourceVNetId = sourceVNet.id;
export const sourceSubnetName = sourceSubnet.name;
export const sourceSubnetId = sourceSubnet.id;

export const targetVNetName = targetVNet.name;
export const targetVNetId = targetVNet.id;
export const targetSubnetName = targetSubnet.name;
export const targetSubnetId = targetSubnet.id;

// Phase 2: Recovery Services Vault & ASR Primitives

// 6. Create Recovery Services Vault (RSV)
const recoveryServicesVault = new recoveryservices.Vault("recoveryServicesVault", {
    vaultName: `${resourceGroupNamePrefix}-rsv`,
    resourceGroupName: recoveryResourceGroup.name,
    location: recoveryResourceGroup.location,
    sku: {
        name: "Standard",
    },
    properties: {
        publicNetworkAccess: "Enabled",
    },
});

// 7. Create ASR Cache Storage Account
const asrCacheStorageAccount = new storage.StorageAccount("asrCacheStorageAccount", {
    accountName: `asr${resourceGroupNamePrefix.toLowerCase().replace(/-/g, "")}cache`,
    resourceGroupName: sourceResourceGroup.name,
    location: location,
    sku: {
        name: "Standard_LRS",
    },
    kind: "StorageV2",
});

// 8. Define ASR Replication Policy
const asrReplicationPolicy = new recoveryservices.ReplicationPolicy("asrReplicationPolicy", {
    policyName: "asr-pmk-policy",
    resourceGroupName: recoveryResourceGroup.name,
    resourceName: recoveryServicesVault.name,
    properties: {
        providerSpecificInput: {
            instanceType: "A2A",
            multiVmSyncStatus: "Enable",
            appConsistentFrequencyInMinutes: 240, // 4 hours * 60 minutes
            crashConsistentFrequencyInMinutes: 5, // 5 minutes for crash-consistent snapshots
            recoveryPointHistory: 1440, // 24 hours * 60 minutes
        },
    },
});

// Export Phase 2 resources for later phases
export const recoveryServicesVaultName = recoveryServicesVault.name;
export const recoveryServicesVaultId = recoveryServicesVault.id;
export const asrCacheStorageAccountName = asrCacheStorageAccount.name;
export const asrCacheStorageAccountId = asrCacheStorageAccount.id;
export const asrReplicationPolicyName = asrReplicationPolicy.name;
export const asrReplicationPolicyId = asrReplicationPolicy.id;

// Phase 3: Source Virtual Machine

// 9. Create Network Interface (NIC) for Source VM
const sourceVmNic = new network.NetworkInterface("sourceVmNic", {
    networkInterfaceName: `${sourceVmName}-nic`,
    resourceGroupName: sourceResourceGroup.name,
    location: location,
    ipConfigurations: [{
        name: "ipconfig1",
        subnet: {
            id: sourceSubnet.id,
        },
        privateIPAllocationMethod: "Dynamic",
    }],
});

// 10. Create Source Virtual Machine
const sourceVm = new compute.VirtualMachine("sourceVm", {
    vmName: sourceVmName,
    resourceGroupName: sourceResourceGroup.name,
    location: location,
    hardwareProfile: {
        vmSize: vmSize,
    },
    storageProfile: {
        imageReference: {
            publisher: sourceVmImagePublisher,
            offer: sourceVmImageOffer,
            sku: sourceVmImageSku,
            version: sourceVmImageVersion,
        },
        osDisk: {
            name: `${sourceVmName}-osdisk`,
            createOption: "FromImage",
            managedDisk: {
                storageAccountType: "Standard_LRS",
            },
        },
        dataDisks: [{
            name: `${sourceVmName}-datadisk-01`,
            createOption: "Empty",
            diskSizeGB: 32,
            lun: 0,
            managedDisk: {
                storageAccountType: "Standard_LRS",
            },
        }],
    },
    osProfile: {
        computerName: sourceVmName,
        adminUsername: vmAdminUsername,
        adminPassword: vmAdminPassword,
        linuxConfiguration: {
            disablePasswordAuthentication: false,
        },
    },
    networkProfile: {
        networkInterfaces: [{
            id: sourceVmNic.id,
        }],
    },
});

// Export Phase 3 resources for later phases
export const sourceVmNicName = sourceVmNic.name;
export const sourceVmNicId = sourceVmNic.id;
export const sourceVmName_export = sourceVm.name;
export const sourceVmId = sourceVm.id;

// Phase 4: ASR Configuration for VM Replication (Azure-to-Azure)

// 11. Create ASR Fabric (Azure) - Source Fabric
const sourceFabric = new recoveryservices.ReplicationFabric("sourceFabric", {
    fabricName: `azure-${location}`,
    resourceGroupName: recoveryResourceGroup.name,
    resourceName: recoveryServicesVault.name,
    properties: {
        customDetails: {
            instanceType: "Azure",
            location: location,
        },
    },
});

// Create ASR Fabric (Azure) - Target Fabric
const targetFabric = new recoveryservices.ReplicationFabric("targetFabric", {
    fabricName: `azure-${targetLocation}`,
    resourceGroupName: recoveryResourceGroup.name,
    resourceName: recoveryServicesVault.name,
    properties: {
        customDetails: {
            instanceType: "Azure",
            location: targetLocation,
        },
    },
});

// 11.5. Create Protection Containers using Azure CLI (since they're not available in Pulumi Azure Native)
const sourceProtectionContainer = new command.local.Command("sourceProtectionContainer", {
    create: pulumi.interpolate`az site-recovery protection-container create --fabric-name ${sourceFabric.name} --vault-name ${recoveryServicesVault.name} --resource-group ${recoveryResourceGroup.name} --name asr-a2a-default-${location}-container --provider-input '[{instance-type:A2A}]'`,
    delete: pulumi.interpolate`az site-recovery protection-container remove --fabric-name ${sourceFabric.name} --vault-name ${recoveryServicesVault.name} --resource-group ${recoveryResourceGroup.name} --protection-container-name asr-a2a-default-${location}-container || true`,
}, {
    dependsOn: [sourceFabric],
});

const targetProtectionContainer = new command.local.Command("targetProtectionContainer", {
    create: pulumi.interpolate`az site-recovery protection-container create --fabric-name ${targetFabric.name} --vault-name ${recoveryServicesVault.name} --resource-group ${recoveryResourceGroup.name} --name asr-a2a-default-${targetLocation}-container --provider-input '[{instance-type:A2A}]'`,
    delete: pulumi.interpolate`az site-recovery protection-container remove --fabric-name ${targetFabric.name} --vault-name ${recoveryServicesVault.name} --resource-group ${recoveryResourceGroup.name} --protection-container-name asr-a2a-default-${targetLocation}-container || true`,
}, {
    dependsOn: [targetFabric],
});

// 12. Create ASR Protection Container Mapping
// Note: Protection containers are automatically created with fabrics for Azure-to-Azure scenarios
// They typically use the pattern "asr-a2a-default-{region}-container"
// Now using the containers we created via CLI
const protectionContainerMapping = new recoveryservices.ReplicationProtectionContainerMapping("protectionContainerMapping", {
    mappingName: "asr-container-mapping",
    resourceGroupName: recoveryResourceGroup.name,
    resourceName: recoveryServicesVault.name,
    fabricName: sourceFabric.name,
    protectionContainerName: `asr-a2a-default-${location}-container`,
    properties: {
        targetProtectionContainerId: pulumi.interpolate`/subscriptions/${clientConfig.then(config => config.subscriptionId)}/resourceGroups/${recoveryResourceGroup.name}/providers/Microsoft.RecoveryServices/vaults/${recoveryServicesVault.name}/replicationFabrics/${targetFabric.name}/replicationProtectionContainers/asr-a2a-default-${targetLocation}-container`,
        policyId: asrReplicationPolicy.id,
        providerSpecificInput: {
            instanceType: "A2A",
        },
    },
}, {
    dependsOn: [sourceProtectionContainer, targetProtectionContainer],
});

// 13. Enable Replication for the VM (Replication Protected Item)
// Now using the proper container name and depending on the mapping
const replicationProtectedItem = new recoveryservices.ReplicationProtectedItem("replicationProtectedItem", {
    replicatedProtectedItemName: `${sourceVmName}-rpi`,
    resourceGroupName: recoveryResourceGroup.name,
    resourceName: recoveryServicesVault.name,
    fabricName: sourceFabric.name,
    protectionContainerName: `asr-a2a-default-${location}-container`,
    properties: {
        policyId: asrReplicationPolicy.id,
        providerSpecificDetails: {
            instanceType: "A2A",
            fabricObjectId: sourceVm.id,
            multiVmGroupName: `${sourceVmName}-multivm-group`,
            recoveryResourceGroupId: targetResourceGroup.id,
            recoveryAzureNetworkId: targetVNet.id,
            recoveryContainerId: pulumi.interpolate`/subscriptions/${clientConfig.then(config => config.subscriptionId)}/resourceGroups/${recoveryResourceGroup.name}/providers/Microsoft.RecoveryServices/vaults/${recoveryServicesVault.name}/replicationFabrics/${targetFabric.name}/replicationProtectionContainers/asr-a2a-default-${targetLocation}-container`,
            recoverySubnetName: "target-subnet",
            vmManagedDisks: [
                {
                    diskId: pulumi.interpolate`/subscriptions/${clientConfig.then(config => config.subscriptionId)}/resourceGroups/${sourceResourceGroup.name}/providers/Microsoft.Compute/disks/${sourceVmName}-osdisk`,
                    primaryStagingAzureStorageAccountId: asrCacheStorageAccount.id,
                    recoveryResourceGroupId: targetResourceGroup.id,
                    recoveryTargetDiskAccountType: "Standard_LRS",
                    recoveryReplicaDiskAccountType: "Standard_LRS",
                },
                {
                    diskId: pulumi.interpolate`/subscriptions/${clientConfig.then(config => config.subscriptionId)}/resourceGroups/${sourceResourceGroup.name}/providers/Microsoft.Compute/disks/${sourceVmName}-datadisk-01`,
                    primaryStagingAzureStorageAccountId: asrCacheStorageAccount.id,
                    recoveryResourceGroupId: targetResourceGroup.id,
                    recoveryTargetDiskAccountType: "Standard_LRS",
                    recoveryReplicaDiskAccountType: "Standard_LRS",
                }
            ],
        },
    },
}, {
    dependsOn: [protectionContainerMapping],
});

// Export Phase 4 resources
export const sourceFabricName = sourceFabric.name;
export const sourceFabricId = sourceFabric.id;
export const targetFabricName = targetFabric.name;
export const targetFabricId = targetFabric.id;
export const protectionContainerMappingName = protectionContainerMapping.name;
export const protectionContainerMappingId = protectionContainerMapping.id;
export const replicationProtectedItemName = replicationProtectedItem.name;
export const replicationProtectedItemId = replicationProtectedItem.id;
