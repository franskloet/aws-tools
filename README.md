# AWS Management Scripts

A collection of wrapper scripts to simplify AWS IAM user management, profile switching, and S3 bucket policy creation.

## Installation

### Quick Install

Use the install script to automatically copy all tools to your desired location:

```bash
./install.sh <target-directory>
```

Example:
```bash
./install.sh ~/s3/AWS
```

This will:
- Copy all scripts to the target directory
- Update the `aws-aliases.sh` file with the correct path
- Make all scripts executable
- Provide instructions for adding to your `~/.bashrc`

Then add to your `~/.bashrc`:
```bash
source ~/s3/AWS/aws-aliases.sh
```

And reload your shell:
```bash
source ~/.bashrc
```

### Manual Installation

1. Make scripts executable:
```bash
chmod +x *.sh
```

2. Edit `aws-aliases.sh` and update the `AWS_SCRIPTS_DIR` variable to point to your installation directory

3. Add to your `~/.bashrc`:
```bash
source /path/to/aws-aliases.sh
```

4. Reload your shell:
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

# Ceph/RGW compatible policies
aws-bucket-policy my-bucket ceph-read-write
aws-bucket-policy my-bucket ceph-read-only

# Generate custom template
aws-bucket-policy my-bucket custom
```

### Get Bucket Policy

View the current bucket policy:

```bash
aws-get-bucket-policy my-bucket
```

### Manage User Policies

```bash
# Attach AWS managed policy to user
aws-attach-policy john-doe arn:aws:iam::aws:policy/AmazonS3FullAccess

# List user's attached policies
aws-list-user-policies john-doe
```

### Manage IAM Groups

```bash
# Create a group without a policy
aws-create-group developers

# Attach policy to existing group
aws-attach-group-policy developers arn:aws:iam::aws:policy/AmazonS3FullAccess

# Create a group with a policy
aws-create-group s3-users arn:aws:iam::aws:policy/AmazonS3FullAccess

# Add user to group
aws-add-user-to-group john-doe developers

# List all groups
aws-list-groups

# List group details and members
aws-list-groups developers
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

## Understanding IAM Policies

### Policy Types

AWS IAM uses three main types of policies to control access:

#### 1. AWS Managed Policies
- Pre-built policies created and maintained by AWS
- Identified by ARN: `arn:aws:iam::aws:policy/<PolicyName>`
- Cannot be modified
- Examples: `AmazonS3FullAccess`, `IAMReadOnlyAccess`
- **Use case**: Standard permissions that AWS maintains and updates

#### 2. Customer Managed Policies
- Custom policies you create and manage
- Can be attached to multiple users, groups, or roles
- Reusable across your AWS account
- Can be versioned and modified
- **Use case**: Custom permissions that multiple users/groups need

#### 3. Inline Policies
- Policies embedded directly into a single user, group, or role
- Have a strict 1:1 relationship with the identity
- Deleted when the identity is deleted
- **Use case**: Unique permissions for a specific user/group that shouldn't be reused

#### 4. Bucket Policies
- Resource-based policies attached to S3 buckets (not IAM identities)
- Define who can access the bucket and what actions they can perform
- Can grant access to users from other AWS accounts or make buckets public
- **Use case**: Control access at the bucket level, especially for cross-account access

### How Policies Interact

#### Policy Evaluation
When a user tries to access a resource, AWS evaluates permissions in this order:

1. **Explicit Deny**: If any policy explicitly denies the action, access is denied (overrides all allows)
2. **Explicit Allow**: If any policy explicitly allows the action, access is granted
3. **Default Deny**: If no policy allows the action, access is denied by default

#### User, Group, and Role Permissions
A user's effective permissions are the **union** of:
- Policies attached directly to the user (managed or inline)
- Policies attached to groups the user belongs to
- Policies from assumed roles (if applicable)

**Example:**
```bash
# User "alice" belongs to group "developers"
# Group has: AmazonS3ReadOnlyAccess (read all buckets)
# User has: Inline policy (write to bucket "project-x")
# Result: Alice can read all buckets AND write to "project-x"
```

#### Bucket Policies vs IAM Policies
For S3 access, both bucket policies and IAM policies are evaluated:
- **IAM policies** grant permissions to identities (users/groups/roles)
- **Bucket policies** grant permissions at the bucket level
- Both must allow the action for access to be granted
- Either can deny the action to block access

**Example:**
```bash
# User has IAM policy: AmazonS3FullAccess (all S3 actions)
# Bucket has bucket policy: Deny all access except user "bob"
# Result: User cannot access the bucket (bucket policy denies)
```

### Best Practices

1. **Use Groups for Common Permissions**: Attach managed policies to groups, then add users to groups
2. **Use Inline Policies Sparingly**: Only for exceptions unique to one user/group
3. **Prefer Managed Policies**: Easier to manage and audit than inline policies
4. **Bucket Policies for Bucket-Specific Access**: Use when access should be tied to the bucket, not the user
5. **Principle of Least Privilege**: Grant only the permissions needed for the task

### Example Workflow

```bash
# Create a group for developers with S3 read access
aws-create-group developers arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess

# Add users to the group
aws-add-user-to-group alice developers
aws-add-user-to-group bob developers

# Give alice write access to a specific bucket using bucket policy
aws-attach-group-bucket-policy developers project-x-bucket write

# Give bob additional IAM admin access (inline)
aws-attach-policy bob arn:aws:iam::aws:policy/IAMFullAccess

# Result:
# - Both alice and bob: Read all S3 buckets (group policy)
# - Both alice and bob: Read/write project-x-bucket (bucket policy via group)
# - Only bob: Manage IAM (user policy)
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

# 2. Switch to new profile
aws-switch-profile alice

# 3. Test access
aws s3 ls

# 4. Create bucket policy
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

-github-test