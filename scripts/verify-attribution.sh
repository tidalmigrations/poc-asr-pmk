#!/bin/bash

# Provided by Tidal <support@tidalcloud.com>
# Verify Attribution Script
# Verifies that "Provided by Tidal <support@tidalcloud.com>" attribution exists in source files

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

# Temporary files for tracking results
TEMP_DIR=$(mktemp -d)
RESULTS_FILE="$TEMP_DIR/results.txt"
MISSING_FILE="$TEMP_DIR/missing.txt"
FOUND_FILE="$TEMP_DIR/found.txt"

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

# Function to check attribution in a file
check_attribution() {
    local file="$1"
    local file_type="$2"
    local quiet="$3"
    
    if grep -q "$ATTRIBUTION" "$file"; then
        echo "$file" >> "$FOUND_FILE"
        if [ "$quiet" != "true" ]; then
            print_success "✓ $file ($file_type)"
        fi
        return 0
    else
        echo "$file" >> "$MISSING_FILE"
        if [ "$quiet" != "true" ]; then
            print_error "✗ $file ($file_type) - Missing attribution"
        fi
        return 1
    fi
}

# Function to verify files of a specific type
verify_files() {
    local pattern="$1"
    local file_type="$2"
    local quiet="$3"
    
    if [ "$quiet" != "true" ]; then
        print_status "Checking $file_type files..."
    fi
    
    # Use find with explicit exclusions
    find . -type f $pattern \( -path "./node_modules" -o -path "./.git" \) -prune -o -print | grep -v "^\\./node_modules" | grep -v "^\\./\\.git" | while read -r file; do
        if [ -n "$file" ] && [ -f "$file" ]; then
            check_attribution "$file" "$file_type" "$quiet"
        fi
    done
}

# Function to display detailed results
display_detailed_results() {
    echo
    print_status "=== DETAILED VERIFICATION RESULTS ==="
    echo
    
    if [ -f "$FOUND_FILE" ] && [ -s "$FOUND_FILE" ]; then
        local found_count=$(wc -l < "$FOUND_FILE" | tr -d ' ')
        print_success "Files WITH attribution ($found_count):"
        while read -r file; do
            echo "  ✓ $file"
        done < "$FOUND_FILE"
        echo
    fi
    
    if [ -f "$MISSING_FILE" ] && [ -s "$MISSING_FILE" ]; then
        local missing_count=$(wc -l < "$MISSING_FILE" | tr -d ' ')
        print_error "Files MISSING attribution ($missing_count):"
        while read -r file; do
            echo "  ✗ $file"
        done < "$MISSING_FILE"
        echo
    fi
}

# Function to display summary
display_summary() {
    local total_files=0
    local files_with_attribution=0
    local files_without_attribution=0
    
    if [ -f "$FOUND_FILE" ]; then
        files_with_attribution=$(wc -l < "$FOUND_FILE" | tr -d ' ')
    fi
    
    if [ -f "$MISSING_FILE" ]; then
        files_without_attribution=$(wc -l < "$MISSING_FILE" | tr -d ' ')
    fi
    
    total_files=$((files_with_attribution + files_without_attribution))
    
    echo
    print_status "=== VERIFICATION SUMMARY ==="
    echo "Total files checked: $total_files"
    echo "Files with attribution: $files_with_attribution"
    echo "Files missing attribution: $files_without_attribution"
    echo
    
    if [ $files_without_attribution -eq 0 ]; then
        if [ $total_files -gt 0 ]; then
            print_success "🎉 All files have proper attribution!"
        else
            print_warning "No files found to check"
        fi
        return 0
    else
        print_error "❌ $files_without_attribution files are missing attribution"
        echo
        print_status "To add attribution to missing files, run:"
        print_status "  ./scripts/add-attribution.sh"
        return 1
    fi
}

# Function to show file type statistics
show_file_type_stats() {
    echo
    print_status "=== FILE TYPE STATISTICS ==="
    
    local ts_count=$(find . -name "*.ts" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l | tr -d ' ')
    local js_count=$(find . -name "*.js" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l | tr -d ' ')
    local sh_count=$(find . -name "*.sh" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l | tr -d ' ')
    local md_count=$(find . -name "*.md" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l | tr -d ' ')
    local yaml_count=$(find . \( -name "*.yaml" -o -name "*.yml" \) -not -path "./node_modules/*" -not -path "./.git/*" | wc -l | tr -d ' ')
    local json_count=$(find . -name "*.json" -not -name "package-lock.json" -not -path "./node_modules/*" -not -path "./.git/*" | wc -l | tr -d ' ')
    local config_count=$(find . \( -name ".env" -o -name ".gitignore" \) -not -path "./node_modules/*" -not -path "./.git/*" | wc -l | tr -d ' ')
    
    echo "TypeScript files: $ts_count"
    echo "JavaScript files: $js_count"
    echo "Shell scripts: $sh_count"
    echo "Markdown files: $md_count"
    echo "YAML files: $yaml_count"
    echo "JSON files: $json_count"
    echo "Configuration files: $config_count"
}

# Function to display help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Verify attribution in project files"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -v, --verbose   Show detailed results"
    echo "  -s, --stats     Show file type statistics"
    echo "  -q, --quiet     Quiet mode (only show summary)"
    echo ""
    echo "Supported file types:"
    echo "  - TypeScript (.ts)"
    echo "  - JavaScript (.js)"
    echo "  - Shell scripts (.sh)"
    echo "  - Markdown (.md)"
    echo "  - YAML (.yaml, .yml)"
    echo "  - JSON (.json, excluding package-lock.json)"
    echo "  - Configuration files (.env, .gitignore)"
    echo ""
    echo "Expected attribution: $ATTRIBUTION"
}

# Parse command line arguments
VERBOSE=false
SHOW_STATS=false
QUIET=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -s|--stats)
            SHOW_STATS=true
            shift
            ;;
        -q|--quiet)
            QUIET=true
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
if [ "$QUIET" != true ]; then
    print_status "Starting attribution verification..."
    print_status "Looking for: $ATTRIBUTION"
    echo
fi

# Initialize result files
touch "$FOUND_FILE" "$MISSING_FILE"

# Run verification for each file type
if [ "$QUIET" != true ]; then
    print_status "Checking TypeScript files..."
fi
find . -name "*.ts" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
    check_attribution "$file" "TypeScript" "$QUIET"
done

if [ "$QUIET" != true ]; then
    print_status "Checking JavaScript files..."
fi
find . -name "*.js" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
    check_attribution "$file" "JavaScript" "$QUIET"
done

if [ "$QUIET" != true ]; then
    print_status "Checking Shell Script files..."
fi
find . -name "*.sh" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
    check_attribution "$file" "Shell Script" "$QUIET"
done

if [ "$QUIET" != true ]; then
    print_status "Checking Markdown files..."
fi
find . -name "*.md" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
    check_attribution "$file" "Markdown" "$QUIET"
done

if [ "$QUIET" != true ]; then
    print_status "Checking YAML files..."
fi
find . \( -name "*.yaml" -o -name "*.yml" \) -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
    check_attribution "$file" "YAML" "$QUIET"
done

if [ "$QUIET" != true ]; then
    print_status "Checking JSON files..."
fi
find . -name "*.json" -not -name "package-lock.json" -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
    check_attribution "$file" "JSON" "$QUIET"
done

if [ "$QUIET" != true ]; then
    print_status "Checking configuration files..."
fi
find . \( -name ".env" -o -name ".gitignore" \) -not -path "./node_modules/*" -not -path "./.git/*" -type f | while read -r file; do
    check_attribution "$file" "Config" "$QUIET"
done

# Display results
if [ "$VERBOSE" = true ]; then
    display_detailed_results
fi

if [ "$SHOW_STATS" = true ]; then
    show_file_type_stats
fi

# Always show summary
display_summary
exit_code=$?

exit $exit_code 