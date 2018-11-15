from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

import os
import uuid
import shutil
import types
import pandas as pd
import argparse
import ibm_boto3
from botocore.client import Config
from dotenv import load_dotenv
load_dotenv('.Credentials')

parser = argparse.ArgumentParser()
parser.add_argument('--bucket', type=str)
args = parser.parse_args()

def __iter__(self): return 0
def pandas_support(csv):
    # add missing __iter__ method, so pandas accepts body as file-like object
    if not hasattr(csv, "__iter__"): csv.__iter__ = types.MethodType( __iter__, csv )
    return csv


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


################################################################################
# Prepare dataset
################################################################################
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

train_dir = os.path.join('.tmp', 'training_data')

# Get csv of annotations (url, label).
annotations = cos.Object(credentials_1['bucket'], '_annotations.csv').get()['Body']
annotations = pandas_support(annotations)
annotations_df = pd.read_csv(annotations, header=None)
annotations_df = annotations_df.set_index([1])

used_labels = annotations_df.index.unique().tolist()

# Purge data if directories already exist.
if os.path.exists(train_dir) and os.path.isdir(train_dir):
    shutil.rmtree(train_dir)

os.makedirs(train_dir)

for label in used_labels:
    file_list = annotations_df.loc[label].values.flatten()

    # Make directory for labels, if they don't exist.
    train_label_dir = os.path.join(train_dir, label)
    if not os.path.exists(train_label_dir):
        os.makedirs(train_label_dir)

    # Download training files.
    for file in file_list:
        _, file_extension = os.path.splitext(file)
        filename = os.path.join(train_label_dir, uuid.uuid4().hex + file_extension)
        print('saving: {}'.format(file))
        print('to: {}'.format(filename))
        cos.Object(credentials_1['bucket'], file).download_file(filename)
print('done')
