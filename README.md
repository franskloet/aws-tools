# AWS Management Scripts

A collection of wrapper scripts to simplify AWS IAM user management, profile switching, and S3 bucket policy creation.

## Installation

1. Make scripts executable:
```bash
chmod +x aws-create-user.sh aws-switch-profile.sh aws-create-bucket-policy.sh
```

2. Add to your `~/.bashrc`:
```bash
source ~/s3/AWS/aws-aliases.sh
```

3. Reload your shell:
```bash
source ~/.bashrc
```

## Requirements

- AWS CLI installed and configured
- `jq` for JSON parsing: `sudo dnf install jq` (AlmaLinux)

## Usage

### Create New IAM User

Create a new IAM user and automatically configure AWS CLI profile:

```bash
aws-create-user john-doe
# or with custom profile name
aws-create-user john-doe my-profile
```

This will:
- Create IAM user in AWS
- Generate access keys
- Add credentials to `~/.aws/credentials`
- Add profile to `~/.aws/config`

### Delete IAM User

Delete an IAM user and remove from AWS CLI configuration:

```bash
aws-delete-user john-doe
# or with custom profile name
aws-delete-user john-doe my-profile
```

This will:
- Delete all access keys
- Detach all policies
- Delete inline policies
- Remove from all groups
- Delete the IAM user
- Remove profile from `~/.aws/config` and `~/.aws/credentials`

### Switch Between Profiles

```bash
# Switch to a profile
aws-switch-profile john-doe

# List available profiles
aws-switch-profile

# Or use standard AWS environment variable
export AWS_PROFILE=john-doe
```

### Create S3 Bucket Policies

Generate and optionally apply bucket policies:

```bash
# Read-only access for specific user
aws-bucket-policy my-bucket read-only john-doe

# Read-write access
aws-bucket-policy my-bucket read-write john-doe

# Full access (including delete)
aws-bucket-policy my-bucket full-access john-doe

# Public read access
aws-bucket-policy my-bucket public-read

# Generate custom template
aws-bucket-policy my-bucket custom
```

### Manage User Policies

```bash
# Attach AWS managed policy to user
aws-attach-policy john-doe arn:aws:iam::aws:policy/AmazonS3FullAccess

# List user's attached policies
aws-list-user-policies john-doe
```

### Utility Commands

```bash
# Show current profile
aws-current

# Show current AWS identity
aws-whoami

# List all profiles
aws-profiles
```

## Common Policy ARNs

- S3 Full Access: `arn:aws:iam::aws:policy/AmazonS3FullAccess`
- S3 Read Only: `arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess`
- IAM Full Access: `arn:aws:iam::aws:policy/IAMFullAccess`
- IAM Read Only: `arn:aws:iam::aws:policy/IAMReadOnlyAccess`

## File Locations

- AWS Config: `~/.aws/config`
- AWS Credentials: `~/.aws/credentials`
- Generated Policies: `/tmp/bucket-policy-*.json`

## Examples

### Complete Workflow: Create User with S3 Access

```bash
# 1. Create user
aws-create-user alice

# 2. Attach S3 policy
aws-attach-policy alice arn:aws:iam::aws:policy/AmazonS3FullAccess

# 3. Switch to new profile
aws-switch-profile alice

# 4. Test access
aws s3 ls

# 5. Create bucket policy
aws-bucket-policy my-data-bucket read-write alice
```

### Switch Between Multiple Projects

```bash
# Project 1
aws-switch-profile project1-user
aws s3 sync ./data s3://project1-bucket/

# Project 2
aws-switch-profile project2-user
aws s3 sync ./data s3://project2-bucket/
```

## Troubleshooting

### Profile not found
Ensure the profile exists in `~/.aws/config` or `~/.aws/credentials`

### Permission denied
Ensure your current AWS profile has permissions to create IAM users and manage policies

### jq command not found
Install jq: `sudo dnf install jq`

## Security Notes

- Access keys are stored in `~/.aws/credentials` - protect this file
- Use `chmod 600 ~/.aws/credentials` to restrict access
- Consider using AWS IAM roles instead of access keys when possible
- Rotate access keys regularly
