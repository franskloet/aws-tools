# Ceph RGW IAM Limitations

This document describes the limitations of Ceph RGW's IAM implementation when using these AWS tools.

## Summary

IAM users created via `aws iam create-user` have limited functionality with Ceph RGW's S3 implementation. While the IAM operations themselves work, the created users cannot effectively access S3 resources in most scenarios.

## What Works ✓

- **Creating IAM users** via `aws iam create-user`
- **Creating IAM groups** via `aws iam create-group`
- **Adding users to groups** via `aws iam add-user-to-group`
- **Attaching AWS managed policies** like `AmazonS3FullAccess` to groups
- **S3 access with managed policies** - Users in groups with `AmazonS3FullAccess` CAN access S3

## What Doesn't Work ✗

- **IAM inline group policies** - Do NOT grant S3 access to group members
- **IAM inline user policies** - Do NOT grant S3 access to users
- **Bucket policies with IAM user principals** - Do NOT grant access to IAM users
- **Per-user or per-folder access restrictions** - Cannot be implemented

## Root Cause

When you create an IAM user via `aws iam create-user`, Ceph RGW creates an IAM identity but does NOT create the underlying RGW user structure that's required for S3 operations. This means:

1. The IAM user exists and can authenticate
2. IAM policies appear to be attached correctly
3. But S3 operations fail with `AccessDenied` (with empty error messages)
4. AWS CLI shows: `argument of type 'NoneType' is not iterable`

## Solution: Use radosgw-admin

For full S3 functionality with Ceph RGW, users must be created using `radosgw-admin`:

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

Then configure the AWS CLI profile with these credentials.

## Test Suite Implications

The `test-suite.sh` script tests IAM functionality. On Ceph RGW:

- **Parts 1-4 work**: Create resources and test with managed policies
- **Parts 5-9 are commented out**: These test inline policies and bucket policies which don't work on Ceph

## Workaround

If you must use IAM users with Ceph:

1. Create users via IAM API (`aws iam create-user`)
2. Put them in a group with **AmazonS3FullAccess** managed policy
3. **Do not try to restrict access** via inline policies or bucket policies
4. All users will have full S3 access

This is suitable for development/testing but not for production access control.

## Recommendations

- **For Ceph RGW in production**: Use `radosgw-admin` to create users
- **For AWS compatibility testing**: Use actual AWS, not Ceph RGW
- **For simple Ceph access**: Use `AmazonS3FullAccess` and accept no access control

## More Information

- Ceph RGW IAM Documentation: https://docs.ceph.com/en/latest/radosgw/iam/
- Known limitation: Ceph RGW's IAM is a compatibility layer, not a full implementation
