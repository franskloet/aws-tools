#!/bin/bash
# Wrapper for aws s3 ls
# Simplified S3 listing without needing to type s3://

# Function to show usage
show_usage() {
    echo "Usage: $0 [bucket-name[/prefix]] [options]"
    echo ""
    echo "Arguments:"
    echo "  bucket-name  - Optional: Name of the bucket to list"
    echo "  prefix       - Optional: Prefix/path within the bucket"
    echo "  options      - Optional: Additional aws s3 ls options"
    echo ""
    echo "If no bucket is specified, lists all buckets."
    echo ""
    echo "Common options:"
    echo "  --recursive  - List recursively"
    echo "  --human-readable - Display file sizes in human readable format"
    echo "  --summarize  - Display summary information (number of objects, total size)"
    echo ""
    echo "Examples:"
    echo "  $0                           # List all buckets"
    echo "  $0 my-bucket                 # List contents of bucket"
    echo "  $0 my-bucket/users/          # List contents of prefix"
    echo "  $0 my-bucket --recursive     # List all objects recursively"
    echo "  $0 my-bucket --human-readable --recursive"
    exit 1
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_usage
fi

# If no arguments, list all buckets
if [ -z "$1" ]; then
    OUTPUT=$(aws s3 ls 2>&1)
    EXIT_CODE=$?
    if [[ "$OUTPUT" == *"argument of type 'NoneType' is not iterable"* ]]; then
        echo "✗ Access denied: You do not have permission to list buckets"
        exit 1
    fi
    echo "$OUTPUT"
    exit $EXIT_CODE
fi

# First argument is bucket or bucket/prefix
BUCKET_PATH="$1"
shift

# Build the s3:// URI
if [[ "$BUCKET_PATH" == s3://* ]]; then
    # Already has s3:// prefix
    S3_URI="$BUCKET_PATH"
else
    # Add s3:// prefix
    S3_URI="s3://$BUCKET_PATH"
fi

# Execute aws s3 ls with the remaining arguments
OUTPUT=$(aws s3 ls "$S3_URI" "$@" 2>&1)
EXIT_CODE=$?
if [[ "$OUTPUT" == *"argument of type 'NoneType' is not iterable"* ]]; then
    echo "✗ Access denied: You do not have permission to access '$S3_URI'"
    exit 1
fi
echo "$OUTPUT"
exit $EXIT_CODE
