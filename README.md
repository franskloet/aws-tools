# AWS/CEPH S3 Management Scripts

A collection of wrapper scripts to simplify IAM user management, profile switching, and policy creation for CEPH S3 storage systems.

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

## Configuration

### Environment Variables

- `AWS_PROFILE`: Standard AWS CLI variable to set the active profile
- `AWS_DEFAULT_TENANT`: Default CEPH tenant for policy ARNs (default: `sils_mns`)
- `AWS_SCRIPTS_DIR`: Directory where scripts are installed (set automatically by install script)

Example `~/.bashrc` configuration:
```bash
# AWS tools
export AWS_DEFAULT_TENANT=my_tenant
source ~/s3/AWS/aws-aliases.sh
```

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

### Manage User Policies

```bash
# Attach AWS managed policy to user
aws-attach-policy john-doe arn:aws:iam::aws:policy/AmazonS3FullAccess

# List user's attached policies
aws-list-user-policies john-doe
```

### Manage IAM Groups

```bash
# Create a group
aws-create-group developers

# Delete a group (removes users, policies, then deletes)
aws-delete-group developers

# Create default S3 access policy for group (with tenant)
aws-create-group-policy developers            # Uses default tenant: $AWS_DEFAULT_TENANT or sils_mns
aws-create-group-policy developers project_x  # Custom tenant

# Add bucket/prefix policy to group
aws-add-group-bucket-policy developers project-data                    # Full access to bucket
aws-add-group-bucket-policy researchers shared-data experiments/      # Access to prefix
aws-add-group-bucket-policy mns_pi groups "" "" read                   # Read-only access to entire bucket
aws-add-group-bucket-policy analysts data-bucket reports/ project_x read  # Read-only with custom tenant

# Add user to group
aws-add-user-to-group john-doe developers

# List all groups
aws-list-groups

# List group details and members
aws-list-groups developers
```

### Manage User Policies (CEPH S3)

```bash
# Grant user full access to a bucket
aws-create-user-policy alice users

# Grant user access to specific prefixes in a bucket
aws-create-user-policy john data project1/ shared/

# With custom tenant
aws-create-user-policy bob research experiment1/ tenant=project_alpha

# Examples:
# - Full bucket access: aws-create-user-policy alice mydata
# - Prefix access: aws-create-user-policy bob files home/bob/ shared/
```

### S3 Bucket and Object Management

```bash
# Create a bucket
aws-mb my-bucket                    # Create private bucket
aws-mb public-data public-read      # Create public-read bucket

# Create empty prefix/directory placeholder
aws-md my-bucket users/             # Create users/ directory
aws-md data-bucket projects/alpha/  # Create nested directory

# List buckets and contents
aws-ls                              # List all buckets
aws-ls my-bucket                    # List bucket contents
aws-ls my-bucket/users/             # List prefix contents
aws-ls my-bucket --recursive        # List all objects recursively
aws-ls my-bucket --human-readable --recursive  # With human-readable sizes

# Copy files to/from S3
aws-cp myfile.txt my-bucket/uploads/           # Upload file
aws-cp my-bucket/data.csv ./data/              # Download file
aws-cp bucket1/files/ bucket2/backup/          # Copy between S3 locations
aws-cp ./local-dir/ my-bucket/remote/ --recursive  # Upload directory
aws-cp my-bucket/logs/ ./logs/ --recursive --exclude '*' --include '*.log'  # Download with wildcard
```

**Note**: These S3 wrapper commands automatically handle the `s3://` prefix and provide user-friendly error messages for CEPH access denied errors.

### Utility Commands

```bash
# Show current profile
aws-current

# Show current AWS identity
aws-whoami

# List all profiles
aws-profiles
```

## CEPH S3 Considerations

### Tenant Support

CEPH S3 uses tenants in the resource ARN format:
```
arn:aws:s3::<tenant>:<bucket>
arn:aws:s3::<tenant>:<bucket>/<prefix>/*
```

#### Default Tenant Configuration

You can set a default tenant using the `AWS_DEFAULT_TENANT` environment variable:
```bash
# Add to your ~/.bashrc
export AWS_DEFAULT_TENANT=my_tenant
```

If not set, the scripts will default to `sils_mns`.

#### Overriding the Default Tenant

You can override the default tenant per-command:
- Group policies: `aws-create-group-policy <group> <tenant>`
- Group bucket policies: `aws-add-group-bucket-policy <group> <bucket> [prefix] <tenant> [access-level]`
- User policies: `aws-create-user-policy <user> <bucket> [prefixes...] tenant=<tenant>`

Examples:
```bash
# Use default tenant
aws-create-group-policy developers
aws-add-group-bucket-policy researchers data

# Override with custom tenant
aws-create-group-policy developers project_alpha
aws-add-group-bucket-policy researchers data experiments/ project_alpha
aws-create-user-policy bob research exp1/ tenant=project_alpha
```

### CEPH Limitations

Key points about CEPH RGW IAM:
- Inline policies with wildcard resources work (`"Resource": "*"`)
- Inline policies with specific bucket ARNs may have issues on older CEPH versions
- Bucket policies with IAM principals may not work as expected
- For resource-level access control, use inline user/group policies with tenant-aware ARNs

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

### Example Workflow (CEPH S3)

```bash
# Set default tenant (optional)
export AWS_DEFAULT_TENANT=my_tenant

# Create a group for developers
aws-create-group developers

# Apply default S3 list policy to group
aws-create-group-policy developers

# Give the group read-only access to a shared bucket (using default tenant)
aws-add-group-bucket-policy developers shared-data "" "" read

# Add users to the group
aws-add-user-to-group alice developers
aws-add-user-to-group bob developers

# Give alice full access to specific bucket
aws-create-user-policy alice project-data

# Give bob access to specific prefixes
aws-create-user-policy bob shared-data team1/ common/

# Result:
# - Both alice and bob: Can list all buckets (group policy)
# - Both alice and bob: Read access to shared-data bucket (group policy)
# - Alice: Full access to project-data bucket (user policy)
# - Bob: Full access to team1/ and common/ prefixes in shared-data bucket (user policy)
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

### Complete Workflow: Create User with CEPH S3 Access

```bash
# 1. Create user
aws-create-user alice

# 2. Create group and add user
aws-create-group data-users
aws-create-group-policy data-users
aws-add-user-to-group alice data-users

# 3. Grant user access to specific bucket/prefixes
aws-create-user-policy alice project-data analysis/ results/

# 4. Switch to new profile and test
aws-switch-profile alice
aws s3 ls
aws s3 ls s3://project-data/analysis/
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
