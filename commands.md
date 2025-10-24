
Create a new IAM user

```bash
'''
aws iam create-user --user-name root_frans_test_subuser_1

 {
    "User": {
        "Path": "/",
        "UserName": "root_frans_test_subuser_1",
        "UserId": "sils_mns$41a3ac6d-21e9-46e2-bd1e-3475df9c2974",
        "Arn": "arn:aws:iam::RGW90942811997524512:user/root_frans_test_subuser_1",
        "CreateDate": "2025-10-24T06:20:32.525732+00:00"
    }
}
```

Create access keys for the new IAM user

```bash
aws iam create-access-key --user-name root_frans_test_subuser_1
{
    "AccessKey": {
        "UserName": "root_frans_test_subuser_1",
        "AccessKeyId": "8Q0494ZT65383P646TV9",
        "Status": "Active",
        "SecretAccessKey": "zVggQIPNC2HF1tZgwfdVrQs9odbqQBFCDIQXul5u",
        "CreateDate": "2025-10-24T06:24:45.335050+00:00"
    }
}
```


# Create user
aws-create-user john-doe

# Switch profiles
aws-switch-profile john-doe

# Create bucket policy
aws-bucket-policy bda-test-bucket read-write john-doe

# Attach managed policy
aws-attach-policy john-doe arn:aws:iam::aws:policy/AmazonS3FullAccess

AWS management tools loaded!
Available commands:
  aws-create-user <username> [profile]  - Create IAM user and configure profile
  aws-delete-user <username> [profile]  - Delete IAM user and remove profile
  aws-switch-profile <profile>          - Switch to different AWS profile
  aws-bucket-policy <bucket> <type>     - Create and apply S3 bucket policy
  aws-current                           - Show current AWS profile
  aws-profiles                          - List all configured profiles
  aws-whoami                            - Show current AWS identity
  aws-attach-policy <user> <arn>       - Attach policy to user
  aws-list-user-policies <user>        - List user's policies