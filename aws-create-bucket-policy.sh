#!/bin/bash
# S3 Bucket Policy Generator and Applier
# Usage: ./aws-create-bucket-policy.sh <bucket-name> <policy-type> [username]

set -e

BUCKET_NAME="$1"
POLICY_TYPE="$2"
USERNAME="$3"

show_usage() {
    cat << EOF
Usage: $0 <bucket-name> <policy-type> [username]

Policy Types:
  read-only        - Allow read-only access to bucket
  read-write       - Allow read and write access to bucket
  full-access      - Allow full access including delete
  public-read      - Make bucket publicly readable
  ceph-read-only   - Ceph/RGW compatible read-only (wildcard principal)
  ceph-read-write  - Ceph/RGW compatible read-write (wildcard principal)
  custom           - Generate a template for custom editing

Options:
  bucket-name: Name of the S3 bucket
  username: IAM username (required for user-specific policies)

Examples:
  $0 my-bucket read-only john-doe
  $0 my-bucket public-read
  $0 my-bucket ceph-read-write
  $0 my-bucket custom
EOF
}

if [ -z "$BUCKET_NAME" ] || [ -z "$POLICY_TYPE" ]; then
    show_usage
    exit 1
fi

# Save current profile and use default for operations
ORIG_AWS_PROFILE="${AWS_PROFILE:-}"
export AWS_PROFILE=default

# Get AWS account ID (skip for Ceph/S3-compatible endpoints)
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "*")
if [ "$ACCOUNT_ID" = "*" ]; then
    echo "Note: Using wildcard for account ID (STS not available on this endpoint)"
fi

generate_policy() {
    case "$POLICY_TYPE" in
        read-only)
            if [ -z "$USERNAME" ]; then
                echo "Error: username required for read-only policy"
                exit 1
            fi
            cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadOnlyAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:user/${USERNAME}"
      },
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
            ;;
        
        read-write)
            if [ -z "$USERNAME" ]; then
                echo "Error: username required for read-write policy"
                exit 1
            fi
            cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadWriteAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:user/${USERNAME}"
      },
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
            ;;
        
        full-access)
            if [ -z "$USERNAME" ]; then
                echo "Error: username required for full-access policy"
                exit 1
            fi
            cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "FullAccess",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:user/${USERNAME}"
      },
      "Action": "s3:*",
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
            ;;
        
        public-read)
            cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
EOF
            ;;
        
        ceph-read-only)
            cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CephReadOnlyAccess",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
            ;;
        
        ceph-read-write)
            cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CephReadWriteAccess",
      "Effect": "Allow",
      "Principal": "*",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
            ;;
        
        custom)
            cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "CustomPolicy",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${ACCOUNT_ID}:user/USERNAME_HERE"
      },
      "Action": [
        "s3:ACTION_HERE"
      ],
      "Resource": [
        "arn:aws:s3:::${BUCKET_NAME}",
        "arn:aws:s3:::${BUCKET_NAME}/*"
      ]
    }
  ]
}
EOF
            ;;
        
        *)
            echo "Error: Unknown policy type '$POLICY_TYPE'"
            show_usage
            exit 1
            ;;
    esac
}

POLICY_FILE="/tmp/bucket-policy-${BUCKET_NAME}-${POLICY_TYPE}.json"

echo "Generating $POLICY_TYPE policy for bucket: $BUCKET_NAME"
generate_policy > "$POLICY_FILE"

echo ""
echo "Policy generated and saved to: $POLICY_FILE"
echo ""
cat "$POLICY_FILE"
echo ""

read -p "Apply this policy to bucket '$BUCKET_NAME'? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Applying policy to bucket..."
    aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "file://$POLICY_FILE"
    echo "✓ Policy applied successfully!"
else
    echo "Policy not applied. You can manually apply it later with:"
    echo "  aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://$POLICY_FILE"
fi

# Restore original profile
if [ -n "$ORIG_AWS_PROFILE" ]; then
    export AWS_PROFILE="$ORIG_AWS_PROFILE"
else
    unset AWS_PROFILE
fi


# Create a group
aws-create-group s3-users

# Create a group with a policy attached
aws-create-group developers arn:aws:iam::aws:policy/AmazonS3FullAccess

# Add users to the group
aws-add-user-to-group john-doe s3-users
aws-add-user-to-group alice s3-users

# List all groups
aws-list-groups

# Show group details and members
aws-list-groups s3-users


aws-attach-group-bucket-policy data-scientists my-bucket
aws-attach-group-bucket-policy analysts my-bucket read-only