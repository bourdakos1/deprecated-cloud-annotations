import os
import argparse
import ibm_boto3
from botocore.client import Config
from dotenv import load_dotenv
load_dotenv('.Credentials')

parser = argparse.ArgumentParser()
parser.add_argument('--bucket', type=str)
parser.add_argument('--mlmodel_path', type=str, default='.tmp/model.mlmodel')
parser.add_argument('--tflite_path', type=str, default='.tmp/model.tflite')
parser.add_argument('--class_labels', type=str, default='.tmp/model.labels')
args = parser.parse_args()


################################################################################
# Credentials
################################################################################
credentials_1 = {
  'bucket': args.bucket,
  'iam_url': 'https://iam.ng.bluemix.net/oidc/token',
  'api_key': os.getenv('API_KEY'),
  'resource_instance_id': os.getenv('RESOURCE_INSTANCE_ID'),
  'url': 'https://s3-api.us-geo.objectstorage.softlayer.net'
}


################################################################################
# Initialize Cloud Object Storage
################################################################################
cos = ibm_boto3.resource('s3',
    ibm_api_key_id=credentials_1['api_key'],
    ibm_service_instance_id=credentials_1['resource_instance_id'],
    ibm_auth_endpoint=credentials_1['iam_url'],
    config=Config(signature_version='oauth'),
    endpoint_url=credentials_1['url']
)

def askForBucket():
    bucket_list = []
    for i, bucket in enumerate(cos.buckets.all()):
        bucket_list.append(bucket.name)
        print('  {}) {}'.format(i + 1, bucket.name))

    bucket_id_name = input("Bucket: ")

    if bucket_id_name in bucket_list:
        credentials_1['bucket'] = bucket_id_name
    else:
        try:
           bucket_id_name = int(bucket_id_name)
           if bucket_id_name <= len(bucket_list):
               credentials_1['bucket'] = bucket_list[bucket_id_name - 1]
           else:
               print('\nPlease choose a valid bucket:')
               askForBucket()
        except ValueError:
            print('\nPlease choose a valid bucket:')
            askForBucket()

if credentials_1['bucket'] == None:
    print('\nPlease choose a bucket:')
    askForBucket()


################################################################################
# Upload Model
################################################################################
coreml = credentials_1['bucket'] + '.mlmodel'
tflite = credentials_1['bucket'] + '.lite'
labels = credentials_1['bucket'] + '.labels'

if os.path.exists(args.mlmodel_path):
    print('Uploading Core ML model...')
    cos.Bucket(credentials_1['bucket']).upload_file(
        args.mlmodel_path,
        coreml
    )

if os.path.exists(args.tflite_path):
    print('Uploading TensorFlow Lite model...')
    cos.Bucket(credentials_1['bucket']).upload_file(
        args.tflite_path,
        tflite
    )

if os.path.exists(args.class_labels):
    print('Uploading TensorFlow Lite labels...')
    cos.Bucket(credentials_1['bucket']).upload_file(
        args.class_labels,
        labels
    )

print('done')
