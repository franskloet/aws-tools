#!/bin/bash
# Create an empty prefix (directory) in S3
# Creates a zero-byte object with trailing slash to represent a directory

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <bucket-name> <prefix-path>"
    echo ""
    echo "Arguments:"
    echo "  bucket-name  - Name of the S3 bucket"
    echo "  prefix-path  - Path/prefix to create (directory-like structure)"
    echo ""
    echo "This creates an empty object with a trailing slash to represent a directory."
    echo "The object acts as a placeholder and should not be deleted to preserve the directory structure."
    echo ""
    echo "Examples:"
    echo "  $0 my-bucket users/"
    echo "  $0 data-bucket projects/alpha/"
    echo "  $0 shared-data team1/docs/"
    exit 1
fi

BUCKET_NAME="$1"
PREFIX="$2"

# Ensure prefix ends with /
if [[ ! "$PREFIX" =~ /$ ]]; then
    PREFIX="${PREFIX}/"
fi

echo "Creating empty prefix in bucket: $BUCKET_NAME"
echo "Prefix: $PREFIX"
echo ""

# Create empty object using aws s3api put-object
OUTPUT=$(aws s3api put-object --bucket "$BUCKET_NAME" --key "$PREFIX" --content-length 0 2>&1)
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✓ Empty prefix '$PREFIX' created in bucket '$BUCKET_NAME'"
    echo "  Note: This placeholder should not be deleted to preserve directory structure"
else
    echo ""
    if [[ "$OUTPUT" == *"argument of type 'NoneType' is not iterable"* ]]; then
        echo "✗ Access denied: You do not have permission to write to bucket '$BUCKET_NAME'"
    else
        echo "✗ Failed to create prefix '$PREFIX'"
        echo "$OUTPUT"
    fi
    exit 1
fi
