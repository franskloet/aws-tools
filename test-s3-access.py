import boto3,botocore,os
sess=boto3.Session(profile_name=os.environ.get('AWS_PROFILE','default'))
s3=sess.client('s3')
try:
    resp=s3.list_objects_v2(Bucket='bda-test-bucket', MaxKeys=5)
    print('OK', resp.get('KeyCount',0))
    if 'Contents' in resp:
        for o in resp['Contents']:
            print(o['Key'])
    else:
        print('No Contents, response keys:', list(resp.keys()))
except botocore.exceptions.ClientError as e:
    err=e.response.get('Error',{})
    print('ERROR', err.get('Code'), repr(err.get('Message')))
    print('Full metadata', e.response.get('ResponseMetadata'))

