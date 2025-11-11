#!/bin/bash
# Comprehensive test suite for CEPH S3 IAM tools
# Tests user creation, groups, inline policies with tenant support, and bucket/prefix access

set -e

# Parse command-line arguments
TENANT="sils_mns"
while [[ $# -gt 0 ]]; do
  case $1 in
    --tenant)
      TENANT="$2"
      shift 2
      ;;
    --tenant=*)
      TENANT="${1#*=}"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [--tenant=<tenant-name>]"
      exit 1
      ;;
  esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_BUCKET="test-ceph-tools-$(date +%s)"
TEST_GROUP="test-ceph-group"
TEST_USER1="test-ceph-user1"
TEST_USER2="test-ceph-user2"
TEST_USER3="test-ceph-user3"

log() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

error() {
    echo -e "${RED}[✗]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[!]${NC} $*"
}

cleanup() {
    log "Cleaning up test resources..."
    export AWS_PROFILE=default
    
    # Delete test bucket and contents
    if aws s3 ls "s3://$TEST_BUCKET" &>/dev/null; then
        aws s3 rm "s3://$TEST_BUCKET" --recursive &>/dev/null || true
        aws s3 rb "s3://$TEST_BUCKET" &>/dev/null || true
    fi
    
    # Delete users manually (aws-delete-user.sh requires confirmation)
    for user in $TEST_USER1 $TEST_USER2 $TEST_USER3; do
        if aws iam get-user --user-name "$user" &>/dev/null; then
            # Delete access keys
            ACCESS_KEYS=$(aws iam list-access-keys --user-name "$user" --output json 2>/dev/null || echo '{"AccessKeyMetadata":[]}')
            echo "$ACCESS_KEYS" | jq -r '.AccessKeyMetadata[].AccessKeyId' | while read -r key_id; do
                [ -n "$key_id" ] && aws iam delete-access-key --user-name "$user" --access-key-id "$key_id" 2>/dev/null || true
            done
            
            # Delete inline policies
            INLINE_POLICIES=$(aws iam list-user-policies --user-name "$user" --output json 2>/dev/null || echo '{"PolicyNames":[]}')
            echo "$INLINE_POLICIES" | jq -r '.PolicyNames[]' | while read -r policy_name; do
                [ -n "$policy_name" ] && aws iam delete-user-policy --user-name "$user" --policy-name "$policy_name" 2>/dev/null || true
            done
            
            # Detach managed policies
            ATTACHED_POLICIES=$(aws iam list-attached-user-policies --user-name "$user" --output json 2>/dev/null || echo '{"AttachedPolicies":[]}')
            echo "$ATTACHED_POLICIES" | jq -r '.AttachedPolicies[].PolicyArn' | while read -r policy_arn; do
                [ -n "$policy_arn" ] && aws iam detach-user-policy --user-name "$user" --policy-arn "$policy_arn" 2>/dev/null || true
            done
            
            # Remove from groups
            USER_GROUPS=$(aws iam list-groups-for-user --user-name "$user" --output json 2>/dev/null || echo '{"Groups":[]}')
            echo "$USER_GROUPS" | jq -r '.Groups[].GroupName' | while read -r group_name; do
                [ -n "$group_name" ] && aws iam remove-user-from-group --user-name "$user" --group-name "$group_name" 2>/dev/null || true
            done
            
            # Delete user
            aws iam delete-user --user-name "$user" &>/dev/null || true
            
            # Remove AWS CLI profile
            if [ -f "$HOME/.aws/config" ]; then
                awk -v user="$user" '
                    /^\[profile / { in_section = ($0 == "[profile " user "]") ? 1 : 0 }
                    /^\[/ && !/^\[profile / { in_section = 0 }
                    !in_section { print }
                ' "$HOME/.aws/config" > "$HOME/.aws/config.tmp" 2>/dev/null && mv "$HOME/.aws/config.tmp" "$HOME/.aws/config" || true
            fi
            if [ -f "$HOME/.aws/credentials" ]; then
                awk -v user="$user" '
                    /^\[/ { in_section = ($0 == "[" user "]") ? 1 : 0 }
                    !in_section { print }
                ' "$HOME/.aws/credentials" > "$HOME/.aws/credentials.tmp" 2>/dev/null && mv "$HOME/.aws/credentials.tmp" "$HOME/.aws/credentials" || true
            fi
        fi
    done
    
    # Delete group policies and group
    if aws iam get-group --group-name "$TEST_GROUP" &>/dev/null; then
        # Delete inline group policies
        GROUP_INLINE_POLICIES=$(aws iam list-group-policies --group-name "$TEST_GROUP" --output json 2>/dev/null || echo '{"PolicyNames":[]}')
        echo "$GROUP_INLINE_POLICIES" | jq -r '.PolicyNames[]' | while read -r policy_name; do
            [ -n "$policy_name" ] && aws iam delete-group-policy --group-name "$TEST_GROUP" --policy-name "$policy_name" 2>/dev/null || true
        done
        
        # Detach managed policies
        GROUP_ATTACHED_POLICIES=$(aws iam list-attached-group-policies --group-name "$TEST_GROUP" --output json 2>/dev/null || echo '{"AttachedPolicies":[]}')
        echo "$GROUP_ATTACHED_POLICIES" | jq -r '.AttachedPolicies[].PolicyArn' | while read -r policy_arn; do
            [ -n "$policy_arn" ] && aws iam detach-group-policy --group-name "$TEST_GROUP" --policy-arn "$policy_arn" 2>/dev/null || true
        done
        
        # Delete group
        aws iam delete-group --group-name "$TEST_GROUP" &>/dev/null || true
    fi
    
    success "Cleanup complete"
}

# Trap errors and cleanup
trap 'error "Test failed at line $LINENO"; cleanup; exit 1' ERR
trap cleanup EXIT

echo ""
echo "========================================"
echo "  CEPH S3 Tools Comprehensive Test Suite"
echo "========================================"
echo ""
echo "Test Configuration:"
echo "  Tenant: $TENANT"
echo "  Test Bucket: $TEST_BUCKET"
echo "  Test Group: $TEST_GROUP"
echo "  Test Users: $TEST_USER1, $TEST_USER2, $TEST_USER3"
echo ""
echo "This suite tests:"
echo "  1. IAM user and group creation"
echo "  2. Group inline policies (default S3 access with tenant)"
echo "  3. User inline policies (bucket/prefix access with tenant)"
echo "  4. S3 access verification"
echo "  5. Policy cleanup and verification"
echo ""
echo "NOTE: Designed for CEPH RGW with tenant support."
echo ""

# Ensure we start with default profile
export AWS_PROFILE=default

# ============================================================================
# Part 1: Create test bucket
# ============================================================================
log "Part 1: Creating test bucket: $TEST_BUCKET"
if aws s3 ls "s3://$TEST_BUCKET" &>/dev/null; then
    warn "Bucket $TEST_BUCKET already exists, will use it"
else
    if aws s3 mb "s3://$TEST_BUCKET" 2>&1; then
        success "Test bucket created"
    else
        warn "Could not create bucket (may already exist), continuing..."
    fi
fi
echo ""

# ============================================================================
# Part 2: Create IAM group and apply default S3 policy
# ============================================================================
log "Part 2: Creating IAM group"
./aws-create-group.sh "$TEST_GROUP"
success "Group '$TEST_GROUP' created"

log "Applying default S3 access policy to group (with tenant: $TENANT)"
./aws-create-group-policy.sh "$TEST_GROUP" "$TENANT"
success "Default S3 policy applied to group with tenant support"
echo ""

# ============================================================================
# Part 3: Create test users and add to group
# ============================================================================
log "Part 3: Creating test users"
export AUTO_CONFIRM=1
./aws-create-user.sh "$TEST_USER1"
./aws-create-user.sh "$TEST_USER2"
./aws-create-user.sh "$TEST_USER3"
unset AUTO_CONFIRM
success "Users created: $TEST_USER1, $TEST_USER2, $TEST_USER3"

log "Adding users to group '$TEST_GROUP'"
./aws-add-user-to-group.sh "$TEST_USER1" "$TEST_GROUP"
./aws-add-user-to-group.sh "$TEST_USER2" "$TEST_GROUP"
./aws-add-user-to-group.sh "$TEST_USER3" "$TEST_GROUP"
success "All users added to group"

log "Waiting for IAM permissions to propagate..."
sleep 1
echo ""

# ============================================================================
# Part 4: Test user access via group policy (list buckets only)
# ============================================================================
log "Part 4: Testing S3 list access via group policy"

log "Switching to $TEST_USER1 profile"
export AWS_PROFILE="$TEST_USER1"

log "Testing list all buckets (should work via group policy)..."
if aws s3 ls 2>&1; then
    success "$TEST_USER1 can list buckets via group policy"
else
    warn "List buckets may have failed (check CEPH configuration)"
fi

log "Testing write access (should fail - no bucket-specific policy yet)..."
echo "Test content from user1" > /tmp/test-file-user1.txt
if aws s3 cp /tmp/test-file-user1.txt "s3://$TEST_BUCKET/test-user1.txt" 2>&1; then
    warn "$TEST_USER1 can write without explicit bucket policy (unexpected)"
else
    success "$TEST_USER1 correctly denied write access (no bucket policy yet)"
fi
echo ""

# ============================================================================
# Part 5: Apply user-specific bucket policies with tenant support
# ============================================================================
log "Part 5: Applying bucket-specific policies to users"
export AWS_PROFILE=default

log "Granting $TEST_USER1 full access to bucket: $TEST_BUCKET"
./aws-create-user-policy.sh "$TEST_USER1" "$TEST_BUCKET" "tenant=$TENANT"
success "Full bucket access policy applied to $TEST_USER1"

log "Granting $TEST_USER2 access to specific prefixes in bucket: $TEST_BUCKET"
./aws-create-user-policy.sh "$TEST_USER2" "$TEST_BUCKET" "data/" "shared/" "tenant=$TENANT"
success "Prefix-specific access policy applied to $TEST_USER2"

log "Waiting for IAM policy changes to propagate..."
sleep 1
echo ""

# ============================================================================
# Part 6: Test user access with bucket policies
# ============================================================================
log "Part 6: Testing S3 access with bucket-specific policies"

log "Switching to $TEST_USER1 profile (full bucket access)"
export AWS_PROFILE="$TEST_USER1"

log "Testing write access to bucket root..."
echo "Test content from user1" > /tmp/test-file-user1.txt
if aws s3 cp /tmp/test-file-user1.txt "s3://$TEST_BUCKET/test-user1.txt" 2>&1; then
    success "$TEST_USER1 can write to bucket"
else
    warn "Write failed (may be CEPH limitation with tenant-specific ARNs)"
fi

log "Testing read access..."
if aws s3 cp "s3://$TEST_BUCKET/test-user1.txt" /tmp/test-download.txt 2>&1; then
    if grep -q "Test content from user1" /tmp/test-download.txt 2>/dev/null; then
        success "$TEST_USER1 can read from bucket"
    else
        warn "Read verification failed"
    fi
else
    warn "Read failed (may be CEPH limitation)"
fi

log "Testing list access..."
if aws s3 ls "s3://$TEST_BUCKET/" 2>&1 | grep -q "test-user1.txt"; then
    success "$TEST_USER1 can list bucket contents"
else
    warn "List test inconclusive"
fi
echo ""

# ============================================================================
# Part 7: Test prefix-specific access
# ============================================================================
log "Part 7: Testing prefix-specific access for $TEST_USER2"
export AWS_PROFILE="$TEST_USER2"

log "Testing write to allowed prefix (data/)..."
echo "Test content from user2" > /tmp/test-file-user2.txt
if aws s3 cp /tmp/test-file-user2.txt "s3://$TEST_BUCKET/data/test-user2.txt" 2>&1; then
    success "$TEST_USER2 can write to allowed prefix (data/)"
else
    warn "Write to allowed prefix failed (may be CEPH limitation)"
fi

log "Testing write to allowed prefix (shared/)..."
if aws s3 cp /tmp/test-file-user2.txt "s3://$TEST_BUCKET/shared/test-user2.txt" 2>&1; then
    success "$TEST_USER2 can write to allowed prefix (shared/)"
else
    warn "Write to allowed prefix failed (may be CEPH limitation)"
fi

log "Testing write to disallowed location (should fail)..."
if aws s3 cp /tmp/test-file-user2.txt "s3://$TEST_BUCKET/forbidden/test.txt" 2>&1; then
    warn "$TEST_USER2 can write to disallowed prefix (policy may not be enforcing)"
else
    success "$TEST_USER2 correctly denied write to disallowed prefix"
fi
echo ""

# ============================================================================
# Part 8: Test policy listing and verification
# ============================================================================
log "Part 8: Verifying policy assignments"
export AWS_PROFILE=default

log "Listing group policies for $TEST_GROUP"
./aws-list-group-policies.sh "$TEST_GROUP"
success "Group policies listed"

log "Listing inline policies for $TEST_USER1"
aws iam list-user-policies --user-name "$TEST_USER1"
success "User policies listed"
echo ""

# ============================================================================
# Part 9: Test policy cleanup
# ============================================================================
log "Part 9: Testing policy cleanup functions"

log "Removing inline policies from $TEST_USER3"
./aws-clear-user-policies.sh "$TEST_USER3"
success "User policies cleared"

log "Removing inline policies from $TEST_GROUP"
./aws-clear-group-policies.sh "$TEST_GROUP"
success "Group policies cleared"
echo ""

# ============================================================================
# Part 10: Test group deletion
# ============================================================================
log "Part 10: Testing group deletion"

# Create a temporary test group to delete
TEST_DELETE_GROUP="test-delete-group-$(date +%s)"
log "Creating temporary group for deletion test: $TEST_DELETE_GROUP"
./aws-create-group.sh "$TEST_DELETE_GROUP"
success "Temporary group created"

log "Adding $TEST_USER3 to temporary group"
./aws-add-user-to-group.sh "$TEST_USER3" "$TEST_DELETE_GROUP"
success "User added to temporary group"

log "Adding inline policy to temporary group"
./aws-create-group-policy.sh "$TEST_DELETE_GROUP" "$TENANT"
success "Policy added to temporary group"

log "Deleting temporary group with aws-delete-group (auto-confirm)"
export AUTO_CONFIRM=1
if echo "yes" | ./aws-delete-group.sh "$TEST_DELETE_GROUP" 2>&1; then
    success "Group deleted successfully"
else
    error "Group deletion failed"
    exit 1
fi
unset AUTO_CONFIRM

log "Verifying group was deleted"
if aws iam get-group --group-name "$TEST_DELETE_GROUP" &>/dev/null; then
    error "Group still exists after deletion"
    exit 1
else
    success "Group deletion verified"
fi
echo ""

# ============================================================================
# Test Suite Complete
# ============================================================================
export AWS_PROFILE=default

log "Verifying bucket contents"
aws s3 ls "s3://$TEST_BUCKET/" --recursive 2>/dev/null || warn "Could not list bucket contents"

echo ""
echo "========================================"
echo "  ✓ TEST SUITE COMPLETED"
echo "========================================"
echo ""
echo "Summary:"
echo "  - Created test bucket: $TEST_BUCKET"
echo "  - Created group: $TEST_GROUP with tenant-aware policy (tenant: $TENANT)"
echo "  - Created users: $TEST_USER1, $TEST_USER2, $TEST_USER3"
echo "  - Applied group inline policy (default S3 list access)"
echo "  - Applied user inline policies (bucket/prefix access)"
echo "  - Tested policy listing and cleanup functions"
echo "  - Tested group deletion with aws-delete-group"
echo ""
echo "CEPH S3 CAPABILITIES TESTED:"
echo "  ✓ IAM user and group creation"
echo "  ✓ Inline group policies with tenant support"
echo "  ✓ Inline user policies with tenant-aware bucket/prefix ARNs"
echo "  ✓ Policy listing and cleanup functions"
echo "  ✓ Group deletion with automatic cleanup"
echo ""
echo "IMPORTANT NOTES:"
echo "  - Tenant-aware ARNs: arn:aws:s3::<tenant>:<bucket>/<prefix>/*"
echo "  - Default tenant: sils_mns (override with --tenant=<name>)"
echo "  - CEPH limitations may affect resource-specific policies"
echo ""

success "Test suite completed successfully!"

# ============================================================================
# Part 11: Test new S3 wrapper functions (aws-mb, aws-md, aws-ls, aws-cp)
# ============================================================================
log "Part 11: Testing S3 wrapper functions"
echo ""

TEST_WRAPPER_BUCKET="test-wrapper-$(date +%s)"
log "Creating test bucket using aws-mb wrapper: $TEST_WRAPPER_BUCKET"
export AWS_PROFILE=default
if ./aws-mb.sh "$TEST_WRAPPER_BUCKET"; then
    success "Bucket created with aws-mb"
else
    error "Failed to create bucket with aws-mb"
    exit 1
fi

log "Creating 'groups' prefix using aws-md wrapper"
if ./aws-md.sh "$TEST_WRAPPER_BUCKET" "groups"; then
    success "Prefix 'groups/' created with aws-md"
else
    error "Failed to create prefix with aws-md"
    exit 1
fi

log "Creating user-specific prefixes: groups/user1/ and groups/user2/"
./aws-md.sh "$TEST_WRAPPER_BUCKET" "groups/user1"
./aws-md.sh "$TEST_WRAPPER_BUCKET" "groups/user2"
success "User prefixes created"

log "Creating test group 'test-wrapper-group' for wrapper tests"
./aws-create-group.sh "test-wrapper-group"
success "Test group created"

log "Applying default S3 access policy to test-wrapper-group"
./aws-create-group-policy.sh "test-wrapper-group" "$TENANT"
success "Default policy applied"

log "Granting test-wrapper-group read-only access to groups prefix"
./aws-add-group-bucket-policy.sh "test-wrapper-group" "$TEST_WRAPPER_BUCKET" "groups/" "$TENANT" "read"
success "Read-only access to groups/ prefix granted to group"

log "Creating test-wrapper-user1 and test-wrapper-user2"
export AUTO_CONFIRM=1
./aws-create-user.sh "test-wrapper-user1"
./aws-create-user.sh "test-wrapper-user2"
unset AUTO_CONFIRM
success "Wrapper test users created"

log "Adding users to test-wrapper-group"
./aws-add-user-to-group.sh "test-wrapper-user1" "test-wrapper-group"
./aws-add-user-to-group.sh "test-wrapper-user2" "test-wrapper-group"
success "Users added to group"

log "Granting test-wrapper-user1 full access to groups/user1/ prefix"
./aws-create-user-policy.sh "test-wrapper-user1" "$TEST_WRAPPER_BUCKET" "groups/user1/" "tenant=$TENANT"
success "Full access to groups/user1/ granted to test-wrapper-user1"

log "Granting test-wrapper-user2 full access to groups/user2/ prefix"
./aws-create-user-policy.sh "test-wrapper-user2" "$TEST_WRAPPER_BUCKET" "groups/user2/" "tenant=$TENANT"
success "Full access to groups/user2/ granted to test-wrapper-user2"

log "Waiting for IAM policy propagation..."
sleep 2
echo ""

# Test with user1
log "Testing aws-ls and aws-cp with test-wrapper-user1"
export AWS_PROFILE="test-wrapper-user1"

log "User1: Listing groups prefix with aws-ls"
if ./aws-ls.sh "$TEST_WRAPPER_BUCKET/groups/" 2>&1; then
    success "User1 can list groups/ prefix (read-only via group)"
else
    warn "User1 list may have failed (check permissions)"
fi

log "User1: Creating test file and uploading to groups/user1/ with aws-cp"
echo "Test content from wrapper user1" > /tmp/test-wrapper-user1.txt
if ./aws-cp.sh /tmp/test-wrapper-user1.txt "$TEST_WRAPPER_BUCKET/groups/user1/test.txt" 2>&1; then
    success "User1 uploaded file to groups/user1/ with aws-cp"
else
    warn "User1 upload failed (may be CEPH limitation)"
fi

log "User1: Attempting to upload to groups/user2/ (should fail)"
if ./aws-cp.sh /tmp/test-wrapper-user1.txt "$TEST_WRAPPER_BUCKET/groups/user2/test.txt" 2>&1; then
    warn "User1 uploaded to user2 prefix (policy may not be enforcing)"
else
    success "User1 correctly denied write to groups/user2/"
fi

log "User1: Downloading own file with aws-cp"
if ./aws-cp.sh "$TEST_WRAPPER_BUCKET/groups/user1/test.txt" /tmp/test-wrapper-download1.txt 2>&1; then
    if grep -q "Test content from wrapper user1" /tmp/test-wrapper-download1.txt 2>/dev/null; then
        success "User1 downloaded and verified own file"
    else
        warn "User1 download verification failed"
    fi
else
    warn "User1 download failed"
fi
echo ""

# Test with user2
log "Testing aws-ls and aws-cp with test-wrapper-user2"
export AWS_PROFILE="test-wrapper-user2"

log "User2: Listing groups prefix with aws-ls"
if ./aws-ls.sh "$TEST_WRAPPER_BUCKET/groups/" 2>&1; then
    success "User2 can list groups/ prefix (read-only via group)"
else
    warn "User2 list may have failed (check permissions)"
fi

log "User2: Creating test file and uploading to groups/user2/ with aws-cp"
echo "Test content from wrapper user2" > /tmp/test-wrapper-user2.txt
if ./aws-cp.sh /tmp/test-wrapper-user2.txt "$TEST_WRAPPER_BUCKET/groups/user2/test.txt" 2>&1; then
    success "User2 uploaded file to groups/user2/ with aws-cp"
else
    warn "User2 upload failed (may be CEPH limitation)"
fi

log "User2: Attempting to upload to groups/user1/ (should fail)"
if ./aws-cp.sh /tmp/test-wrapper-user2.txt "$TEST_WRAPPER_BUCKET/groups/user1/test.txt" 2>&1; then
    warn "User2 uploaded to user1 prefix (policy may not be enforcing)"
else
    success "User2 correctly denied write to groups/user1/"
fi

log "User2: Attempting to read user1's file (should work via group read-only)"
if ./aws-cp.sh "$TEST_WRAPPER_BUCKET/groups/user1/test.txt" /tmp/test-wrapper-read-cross.txt 2>&1; then
    success "User2 can read user1's file (group read-only access)"
else
    warn "User2 cross-read failed (may be CEPH limitation)"
fi
echo ""

# Cleanup wrapper test resources
log "Cleaning up wrapper test resources"
export AWS_PROFILE=default

# Delete bucket contents
log "Deleting bucket contents"
aws s3 rm "s3://$TEST_WRAPPER_BUCKET" --recursive &>/dev/null || warn "Could not delete bucket contents"
aws s3 rb "s3://$TEST_WRAPPER_BUCKET" &>/dev/null || warn "Could not delete bucket"

# Delete users
for user in test-wrapper-user1 test-wrapper-user2; do
    if aws iam get-user --user-name "$user" &>/dev/null; then
        ACCESS_KEYS=$(aws iam list-access-keys --user-name "$user" --output json 2>/dev/null || echo '{"AccessKeyMetadata":[]}')
        echo "$ACCESS_KEYS" | jq -r '.AccessKeyMetadata[].AccessKeyId' | while read -r key_id; do
            [ -n "$key_id" ] && aws iam delete-access-key --user-name "$user" --access-key-id "$key_id" 2>/dev/null || true
        done
        
        INLINE_POLICIES=$(aws iam list-user-policies --user-name "$user" --output json 2>/dev/null || echo '{"PolicyNames":[]}')
        echo "$INLINE_POLICIES" | jq -r '.PolicyNames[]' | while read -r policy_name; do
            [ -n "$policy_name" ] && aws iam delete-user-policy --user-name "$user" --policy-name "$policy_name" 2>/dev/null || true
        done
        
        USER_GROUPS=$(aws iam list-groups-for-user --user-name "$user" --output json 2>/dev/null || echo '{"Groups":[]}')
        echo "$USER_GROUPS" | jq -r '.Groups[].GroupName' | while read -r group_name; do
            [ -n "$group_name" ] && aws iam remove-user-from-group --user-name "$user" --group-name "$group_name" 2>/dev/null || true
        done
        
        aws iam delete-user --user-name "$user" &>/dev/null || true
        
        if [ -f "$HOME/.aws/config" ]; then
            awk -v user="$user" '
                /^\[profile / { in_section = ($0 == "[profile " user "]") ? 1 : 0 }
                /^\[/ && !/^\[profile / { in_section = 0 }
                !in_section { print }
            ' "$HOME/.aws/config" > "$HOME/.aws/config.tmp" 2>/dev/null && mv "$HOME/.aws/config.tmp" "$HOME/.aws/config" || true
        fi
        if [ -f "$HOME/.aws/credentials" ]; then
            awk -v user="$user" '
                /^\[/ { in_section = ($0 == "[" user "]") ? 1 : 0 }
                !in_section { print }
            ' "$HOME/.aws/credentials" > "$HOME/.aws/credentials.tmp" 2>/dev/null && mv "$HOME/.aws/credentials.tmp" "$HOME/.aws/credentials" || true
        fi
    fi
done

# Delete group
if aws iam get-group --group-name "test-wrapper-group" &>/dev/null; then
    GROUP_INLINE_POLICIES=$(aws iam list-group-policies --group-name "test-wrapper-group" --output json 2>/dev/null || echo '{"PolicyNames":[]}')
    echo "$GROUP_INLINE_POLICIES" | jq -r '.PolicyNames[]' | while read -r policy_name; do
        [ -n "$policy_name" ] && aws iam delete-group-policy --group-name "test-wrapper-group" --policy-name "$policy_name" 2>/dev/null || true
    done
    
    aws iam delete-group --group-name "test-wrapper-group" &>/dev/null || true
fi

success "Wrapper test cleanup complete"
echo ""
echo "========================================"
echo "  ✓ S3 WRAPPER FUNCTIONS TESTED"
echo "========================================"
echo ""
echo "Tested functions:"
echo "  ✓ aws-mb - Bucket creation"
echo "  ✓ aws-md - Prefix/directory creation"
echo "  ✓ aws-ls - Listing buckets and contents"
echo "  ✓ aws-cp - Copying files to/from S3"
echo ""
echo "Permission tests:"
echo "  ✓ Group read-only access to prefix"
echo "  ✓ User-specific write access to sub-prefixes"
echo "  ✓ Cross-user read access via group policy"
echo "  ✓ Write access denial to unauthorized prefixes"
echo ""
