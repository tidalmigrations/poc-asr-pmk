#!/bin/bash

# Provided by Tidal <support@tidalcloud.com>
# Add Attribution Script
# Adds "Provided by Tidal <support@tidalcloud.com>" attribution to various file types in the project

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

# Attribution text
ATTRIBUTION="Provided by Tidal <support@tidalcloud.com>"

# Function to add attribution to TypeScript/JavaScript files
add_attribution_ts_js() {
    local file="$1"
    local attribution_comment="// $ATTRIBUTION"
    
    # Check if attribution already exists
    if grep -q "$ATTRIBUTION" "$file"; then
        print_warning "Attribution already exists in $file"
        return 0
    fi
    
    # Always add attribution at the very beginning for TypeScript/JavaScript files
    sed -i.bak "1i\\
$attribution_comment\\
" "$file"
    
    rm -f "$file.bak"
    print_success "Added attribution to $file"
}

# Function to add attribution to shell scripts
add_attribution_shell() {
    local file="$1"
    local attribution_comment="# $ATTRIBUTION"
    
    # Check if attribution already exists
    if grep -q "$ATTRIBUTION" "$file"; then
        print_warning "Attribution already exists in $file"
        return 0
    fi
    
    # Add attribution after shebang line
    if head -n1 "$file" | grep -q "^#!"; then
        sed -i.bak "1a\\
\\
$attribution_comment" "$file"
    else
        # Add attribution at the beginning
        sed -i.bak "1i\\
$attribution_comment\\
" "$file"
    fi
    
    rm -f "$file.bak"
    print_success "Added attribution to $file"
}

# Function to add attribution to Markdown files
add_attribution_markdown() {
    local file="$1"
    
    # Check if attribution already exists
    if grep -q "$ATTRIBUTION" "$file"; then
        print_warning "Attribution already exists in $file"
        return 0
    fi
    
    # Add attribution at the end of the file in Markdown format
    echo "" >> "$file"
    echo "---" >> "$file"
    echo "" >> "$file"
    echo "*$ATTRIBUTION*" >> "$file"
    
    print_success "Added attribution to $file"
}

# Function to add attribution to YAML files
add_attribution_yaml() {
    local file="$1"
    local attribution_comment="# $ATTRIBUTION"
    
    # Check if attribution already exists
    if grep -q "$ATTRIBUTION" "$file"; then
        print_warning "Attribution already exists in $file"
        return 0
    fi
    
    # Add attribution at the beginning
    sed -i.bak "1i\\
$attribution_comment\\
" "$file"
    
    rm -f "$file.bak"
    print_success "Added attribution to $file"
}

# Function to add attribution to JSON files
add_attribution_json() {
    local file="$1"
    
    # Check if attribution already exists
    if grep -q "$ATTRIBUTION" "$file"; then
        print_warning "Attribution already exists in $file"
        return 0
    fi
    
    # JSON doesn't support comments, so we add a special field
    # Check if it's a valid JSON file first
    if ! python3 -m json.tool "$file" > /dev/null 2>&1; then
        print_warning "Skipping $file - not valid JSON"
        return 0
    fi
    
    # Add attribution field to JSON
    python3 -c "
import json
import sys

with open('$file', 'r') as f:
    data = json.load(f)

if isinstance(data, dict):
    data['_attribution'] = '$ATTRIBUTION'
    with open('$file', 'w') as f:
        json.dump(data, f, indent=2)
    print('Added attribution to $file')
else:
    print('Skipping $file - not a JSON object')
"
    
    if [ $? -eq 0 ]; then
        print_success "Added attribution to $file"
    else
        print_warning "Could not add attribution to $file"
    fi
}

# Function to add attribution to configuration files (.env, .gitignore, etc.)
add_attribution_config() {
    local file="$1"
    local attribution_comment="# $ATTRIBUTION"
    
    # Check if attribution already exists
    if grep -q "$ATTRIBUTION" "$file"; then
        print_warning "Attribution already exists in $file"
        return 0
    fi
    
    # Add attribution at the beginning
    sed -i.bak "1i\\
$attribution_comment\\
" "$file"
    
    rm -f "$file.bak"
    print_success "Added attribution to $file"
}

# Main function to process files
process_files() {
    print_status "Adding attribution to project files..."
    
    # Process TypeScript files
    find . -name "*.ts" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
        add_attribution_ts_js "$file"
    done
    
    # Process JavaScript files
    find . -name "*.js" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
        add_attribution_ts_js "$file"
    done
    
    # Process shell scripts
    find . -name "*.sh" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
        add_attribution_shell "$file"
    done
    
    # Process Markdown files
    find . -name "*.md" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
        add_attribution_markdown "$file"
    done
    
    # Process YAML files
    find . \( -name "*.yaml" -o -name "*.yml" \) -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
        add_attribution_yaml "$file"
    done
    
    # Process JSON files (excluding package-lock.json and node_modules)
    find . -name "*.json" -not -name "package-lock.json" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
        add_attribution_json "$file"
    done
    
    # Process configuration files (.env, .gitignore, etc.)
    find . \( -name ".env" -o -name ".gitignore" \) -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
        add_attribution_config "$file"
    done
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Add attribution to project files"
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -v, --verify   Verify attributions after adding"
    echo ""
    echo "Supported file types:"
    echo "  - TypeScript (.ts)"
    echo "  - JavaScript (.js)"
    echo "  - Shell scripts (.sh)"
    echo "  - Markdown (.md)"
    echo "  - YAML (.yaml, .yml)"
    echo "  - JSON (.json, excluding package-lock.json)"
    echo "  - Configuration files (.env, .gitignore)"
}

# Parse command line arguments
VERIFY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verify)
            VERIFY=true
            shift
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Main execution
print_status "Starting attribution process..."
process_files

if [ "$VERIFY" = true ]; then
    print_status "Running verification..."
    if [ -f "./scripts/verify-attribution.sh" ]; then
        ./scripts/verify-attribution.sh
    else
        print_warning "Verification script not found"
    fi
fi

print_success "Attribution process completed!" 