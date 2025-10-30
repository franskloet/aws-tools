# Ceph RGW IAM Limitations (Squid Release)

This document describes the limitations and capabilities of Ceph RGW's IAM implementation in the Squid release when using these AWS tools.

## Summary

Ceph Squid introduced proper IAM account support, making most IAM operations functional. However, there are still some limitations around resource-specific access control.

## Prerequisites

- Ceph Squid or later
- IAM accounts feature enabled
- Using an IAM Root Account (your default profile should have ARN ending in `:root`)

## What Works ✓

- **Creating IAM users** via `aws iam create-user` - Fully functional
- **Creating IAM groups** via `aws iam create-group` - Fully functional
- **Adding users to groups** via `aws iam add-user-to-group` - Fully functional
- **Attaching AWS managed policies** like `AmazonS3FullAccess` to groups - Fully functional
- **S3 access with managed policies** - Works perfectly
- **IAM inline user policies with wildcard resources** - Works (e.g., `"Resource": "*"`)
- **IAM inline group policies with wildcard resources** - Works (e.g., `"Resource": "*"`)

## What Doesn't Work ✗

- **IAM inline policies with specific bucket ARNs** - Policies like `"Resource": "arn:aws:s3:::bucket-name/*"` fail
- **Bucket policies with IAM user principals** - Bucket policies specifying IAM users don't grant access
- **Resource-specific access restrictions** - Cannot restrict access to specific buckets/paths via inline policies
- **Per-user folder access** - Cannot implement user-specific path restrictions

## Root Cause

The limitations stem from incomplete implementation of resource-level access control in Ceph RGW's IAM:

1. IAM users are properly created and can authenticate
2. Policies with wildcard resources (`"Resource": "*"`) work correctly
3. Policies with specific ARNs (`"Resource": "arn:aws:s3:::bucket/*"`) fail with `AccessDenied`
4. The error message is empty, causing AWS CLI to show: `argument of type 'NoneType' is not iterable`

## Solutions and Workarounds

### For Full Access Control

If you need resource-specific access control, the options are limited:

1. **Use managed policies only** - Stick to AWS managed policies like `AmazonS3FullAccess` or `AmazonS3ReadOnlyAccess`
2. **Use wildcard inline policies** - Create inline policies with `"Resource": "*"` (all-or-nothing access)
3. **Wait for Ceph updates** - Resource-level IAM support may be improved in future releases
4. **Use radosgw-admin** - For complete control, create users via radosgw-admin:

```bash
# Create RGW user (not IAM user)
radosgw-admin user create \
  --uid=username \
  --display-name="Display Name" \
  --access-key=ACCESS_KEY \
  --secret=SECRET_KEY

# Grant capabilities
radosgw-admin caps add \
  --uid=username \
  --caps="users=read,write;buckets=read,write"
```

## Test Suite Implications

The `test-suite.sh` script tests IAM functionality. On Ceph RGW Squid:

- **Parts 1-4 work**: Create resources, test with managed policies and wildcard inline policies
- **Part 5 works**: Test inline policies with wildcard resources
- **Parts 6-9 commented out**: These test resource-specific access control which doesn't work

## Practical Usage

### What You Can Do with IAM on Ceph Squid:

```bash
# Create user and group
./aws-create-user.sh alice
./aws-create-group.sh developers arn:aws:iam::aws:policy/AmazonS3FullAccess
./aws-add-user-to-group.sh alice developers

# OR use wildcard inline policy
./aws-generate-user-policy.sh s3-full-access alice | \
  ./aws-attach-user-policy.sh alice s3-access -

# Alice can now access all S3 buckets
```

### What You Cannot Do:

```bash
# This will NOT work - bucket-specific inline policies fail
./aws-generate-user-policy.sh s3-bucket-full bob my-bucket | \
  ./aws-attach-user-policy.sh bob bucket-access -

# This will NOT work - bucket policies with IAM principals fail  
./ceph-grant-group-bucket-access.sh developers my-bucket full
```

## Recommendations

- **For simple multitenancy**: Use IAM with managed policies or wildcard inline policies
- **For resource-level access control**: Use `radosgw-admin` users or wait for future Ceph releases
- **For AWS compatibility testing**: Use actual AWS, not Ceph RGW
- **For production with granular control**: Consider using separate RGW instances or radosgw-admin users

## More Information

- Ceph RGW IAM Documentation: https://docs.ceph.com/en/latest/radosgw/iam/
- Known limitation: Ceph RGW's IAM is a compatibility layer, not a full implementation
