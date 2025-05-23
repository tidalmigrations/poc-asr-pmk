#!/bin/bash

# Pulumi Backend Validation Script
# Validates that the Azure Blob Storage backend for Pulumi is properly configured

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
RESOURCE_GROUP_NAME="pulumi-state-rg"
CONTAINER_NAME="pulumi-backend"

# Function to check Azure CLI and login status
check_azure_cli() {
    print_status "Checking Azure CLI status..."
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed."
        return 1
    fi
    
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI."
        return 1
    fi
    
    local subscription_name=$(az account show --query name -o tsv)
    local subscription_id=$(az account show --query id -o tsv)
    print_success "Logged in to Azure CLI"
    print_status "Subscription: $subscription_name ($subscription_id)"
    return 0
}

# Function to check if resource group exists
check_resource_group() {
    print_status "Checking resource group '$RESOURCE_GROUP_NAME'..."
    
    if az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
        local location=$(az group show --name "$RESOURCE_GROUP_NAME" --query location -o tsv)
        print_success "Resource group '$RESOURCE_GROUP_NAME' exists in '$location'"
        return 0
    else
        print_error "Resource group '$RESOURCE_GROUP_NAME' not found"
        return 1
    fi
}

# Function to check storage account
check_storage_account() {
    print_status "Checking storage account..."
    
    local storage_accounts=$(az storage account list --resource-group "$RESOURCE_GROUP_NAME" --query "[?starts_with(name, 'pulumistate')].name" -o tsv)
    
    if [[ -z "$storage_accounts" ]]; then
        print_error "No storage account with prefix 'pulumistate' found in resource group '$RESOURCE_GROUP_NAME'"
        return 1
    fi
    
    local storage_account_name=$(echo "$storage_accounts" | head -n1)
    print_success "Storage account '$storage_account_name' found"
    
    # Check storage account properties
    local sku=$(az storage account show --name "$storage_account_name" --resource-group "$RESOURCE_GROUP_NAME" --query sku.name -o tsv)
    local kind=$(az storage account show --name "$storage_account_name" --resource-group "$RESOURCE_GROUP_NAME" --query kind -o tsv)
    
    print_status "Storage account SKU: $sku"
    print_status "Storage account kind: $kind"
    
    # Export for use in other functions
    export STORAGE_ACCOUNT_NAME="$storage_account_name"
    return 0
}

# Function to check blob container
check_blob_container() {
    print_status "Checking blob container '$CONTAINER_NAME'..."
    
    if az storage container show --name "$CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --auth-mode login &> /dev/null; then
        print_success "Blob container '$CONTAINER_NAME' exists"
        
        # Check container properties
        local public_access=$(az storage container show --name "$CONTAINER_NAME" --account-name "$STORAGE_ACCOUNT_NAME" --auth-mode login --query properties.publicAccess -o tsv)
        if [[ "$public_access" == "null" || "$public_access" == "" ]]; then
            print_success "Container has private access (no public access)"
        else
            print_warning "Container has public access level: $public_access"
        fi
        
        return 0
    else
        print_error "Blob container '$CONTAINER_NAME' not found or no access"
        return 1
    fi
}

# Function to check RBAC permissions
check_rbac_permissions() {
    print_status "Checking RBAC permissions..."
    
    local user_object_id=$(az ad signed-in-user show --query id -o tsv 2>/dev/null || echo "")
    
    if [[ -z "$user_object_id" ]]; then
        print_warning "Could not retrieve current user's object ID"
        return 0
    fi
    
    local storage_account_id=$(az storage account show --name "$STORAGE_ACCOUNT_NAME" --resource-group "$RESOURCE_GROUP_NAME" --query id -o tsv)
    
    # Check for Storage Blob Data Contributor role
    local role_assignments=$(az role assignment list --assignee "$user_object_id" --scope "$storage_account_id" --query "[?roleDefinitionName=='Storage Blob Data Contributor'].roleDefinitionName" -o tsv)
    
    if [[ -n "$role_assignments" ]]; then
        print_success "User has 'Storage Blob Data Contributor' role on storage account"
    else
        print_warning "User may not have 'Storage Blob Data Contributor' role on storage account"
        print_status "This might cause issues with Pulumi backend access"
    fi
    
    return 0
}

# Function to check Pulumi CLI and backend configuration
check_pulumi_backend() {
    print_status "Checking Pulumi CLI and backend configuration..."
    
    if ! command -v pulumi &> /dev/null; then
        print_warning "Pulumi CLI is not installed"
        print_status "Install from: https://www.pulumi.com/docs/get-started/install/"
        return 0
    fi
    
    print_success "Pulumi CLI is installed"
    
    # Check current backend
    local current_backend=$(pulumi whoami -v 2>/dev/null | grep "Backend URL" | awk '{print $3}' || echo "")
    
    if [[ "$current_backend" == "azblob://$CONTAINER_NAME" ]]; then
        print_success "Pulumi is configured to use the correct Azure Blob backend"
        print_status "Backend URL: $current_backend"
    else
        print_warning "Pulumi backend may not be configured correctly"
        print_status "Current backend: $current_backend"
        print_status "Expected: azblob://$CONTAINER_NAME"
        print_status "Run: pulumi login azblob://$CONTAINER_NAME"
    fi
    
    return 0
}

# Function to test backend connectivity
test_backend_connectivity() {
    print_status "Testing backend connectivity..."
    
    if ! command -v pulumi &> /dev/null; then
        print_warning "Pulumi CLI not available, skipping connectivity test"
        return 0
    fi
    
    # Set environment variable for storage account
    export AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT_NAME"
    
    # Try to list stacks (this will test connectivity)
    if pulumi stack ls &> /dev/null; then
        print_success "Backend connectivity test passed"
    else
        print_warning "Backend connectivity test failed"
        print_status "This might be normal if no stacks exist yet"
    fi
    
    return 0
}

# Function to display summary
display_summary() {
    echo
    print_status "=== Validation Summary ==="
    echo "Resource Group: $RESOURCE_GROUP_NAME"
    echo "Storage Account: $STORAGE_ACCOUNT_NAME"
    echo "Container: $CONTAINER_NAME"
    echo "Backend URL: azblob://$CONTAINER_NAME"
    echo
    print_status "Environment variables:"
    echo "  AZURE_STORAGE_ACCOUNT=$STORAGE_ACCOUNT_NAME"
    echo
}

# Main validation function
main() {
    echo "=================================================="
    echo "  Pulumi Backend Validation Script"
    echo "  Validating Azure Blob Storage Backend Setup"
    echo "=================================================="
    echo
    
    local validation_passed=true
    
    # Run all validation checks
    check_azure_cli || validation_passed=false
    echo
    
    check_resource_group || validation_passed=false
    echo
    
    check_storage_account || validation_passed=false
    echo
    
    check_blob_container || validation_passed=false
    echo
    
    check_rbac_permissions
    echo
    
    check_pulumi_backend
    echo
    
    test_backend_connectivity
    echo
    
    display_summary
    
    if [[ "$validation_passed" == "true" ]]; then
        print_success "All critical validations passed! Backend setup appears to be correct."
        echo
        print_status "Next steps:"
        echo "  1. Create your Pulumi project: pulumi new azure-python"
        echo "  2. Start deploying your infrastructure"
    else
        print_error "Some validations failed. Please check the errors above."
        echo
        print_status "You may need to run the setup script again:"
        echo "  ./setup-pulumi-backend.sh"
        exit 1
    fi
}

# Run main function
main "$@" 