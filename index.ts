import * as pulumi from "@pulumi/pulumi";
import * as resources from "@pulumi/azure-native/resources";
import * as network from "@pulumi/azure-native/network";
import * as recoveryservices from "@pulumi/azure-native/recoveryservices";
import * as storage from "@pulumi/azure-native/storage";

// Get configuration values
const config = new pulumi.Config();
const azureConfig = new pulumi.Config("azure-native");
const location = azureConfig.require("location");
const targetLocation = config.require("targetLocation");
const resourceGroupNamePrefix = config.require("resourceGroupNamePrefix");

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
