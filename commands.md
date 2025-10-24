
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


