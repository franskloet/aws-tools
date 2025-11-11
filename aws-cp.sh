#!/bin/bash
# Wrapper for aws s3 cp
# Simplified S3 copy without needing to type s3:// for S3 paths

# Function to show usage
show_usage() {
    echo "Usage: $0 <source> <destination> [options]"
    echo ""
    echo "Arguments:"
    echo "  source       - Source path (local file or bucket/prefix)"
    echo "  destination  - Destination path (local path or bucket/prefix)"
    echo "  options      - Optional: Additional aws s3 cp options"
    echo ""
    echo "For S3 paths, you can omit the 's3://' prefix - it will be added automatically."
    echo "Local paths starting with / . or ~ are treated as local files."
    echo ""
    echo "Common options:"
    echo "  --recursive  - Copy directories/prefixes recursively"
    echo "  --exclude    - Exclude files matching pattern"
    echo "  --include    - Include files matching pattern"
    echo "  --acl        - Set ACL (private, public-read, etc.)"
    echo "  --dryrun     - Show what would be copied without actually copying"
    echo ""
    echo "Examples:"
    echo "  # Upload local file to S3"
    echo "  $0 myfile.txt my-bucket/uploads/"
    echo ""
    echo "  # Download from S3 to local"
    echo "  $0 my-bucket/data.csv ./data/"
    echo ""
    echo "  # Copy between S3 locations"
    echo "  $0 bucket1/files/ bucket2/backup/"
    echo ""
    echo "  # Upload directory recursively"
    echo "  $0 ./local-dir/ my-bucket/remote-dir/ --recursive"
    echo ""
    echo "  # Download with wildcard (requires --recursive)"
    echo "  $0 my-bucket/logs/ ./logs/ --recursive --exclude '*' --include '*.log'"
    echo ""
    echo "  # Copy with public-read ACL"
    echo "  $0 index.html my-bucket/public/ --acl public-read"
    exit 1
}

# Function to determine if a path is local or S3
is_local_path() {
    local path="$1"
    # Check if path starts with /, ./, ../, ~, or is a relative path without /
    if [[ "$path" == /* ]] || [[ "$path" == ./* ]] || [[ "$path" == ../* ]] || [[ "$path" == ~* ]] || [[ "$path" != */* ]]; then
        return 0  # Is local
    else
        return 1  # Assume S3
    fi
}

# Function to convert path to S3 URI if needed
convert_to_s3_if_needed() {
    local path="$1"
    
    # Already has s3:// prefix
    if [[ "$path" == s3://* ]]; then
        echo "$path"
        return
    fi
    
    # Is a local path
    if is_local_path "$path"; then
        echo "$path"
        return
    fi
    
    # Must be S3 path without prefix
    echo "s3://$path"
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
fi

# Check minimum arguments
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Both source and destination are required"
    echo ""
    show_usage
fi

SOURCE="$1"
DESTINATION="$2"
shift 2

# Convert paths to S3 URIs if needed
SOURCE_URI=$(convert_to_s3_if_needed "$SOURCE")
DEST_URI=$(convert_to_s3_if_needed "$DESTINATION")

# Execute aws s3 cp with the remaining arguments
OUTPUT=$(aws s3 cp "$SOURCE_URI" "$DEST_URI" "$@" 2>&1)
EXIT_CODE=$?
if [[ "$OUTPUT" == *"argument of type 'NoneType' is not iterable"* ]]; then
    echo "✗ Access denied: You do not have permission to copy from/to S3"
    echo "  Source: $SOURCE_URI"
    echo "  Destination: $DEST_URI"
    exit 1
fi
echo "$OUTPUT"
exit $EXIT_CODE
