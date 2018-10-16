# @hidden_cell
import os
import uuid
import shutil
import types
import pandas as pd
import ibm_boto3
from watson_developer_cloud import VisualRecognitionV3, WatsonApiException
from dotenv import load_dotenv
load_dotenv()

def __iter__(self): return 0
def pandas_support(csv):
    # add missing __iter__ method, so pandas accepts body as file-like object
    if not hasattr(csv, "__iter__"): csv.__iter__ = types.MethodType( __iter__, csv )
    return csv


################################################################################
# Credentials
################################################################################
credentials_1 = {
  'bucket': os.getenv('BUCKET'),
  'iam_url': 'https://iam.ng.bluemix.net/oidc/token',
  'api_key': os.getenv('API_KEY'),
  'resource_instance_id': os.getenv('RESOURCE_INSTANCE_ID'),
  'url': 'https://s3-api.us-geo.objectstorage.service.networklayer.com'
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

# List available buckets.
for bucket in cos.buckets.all():
    print(bucket.name)


################################################################################
# Prepare dataset
################################################################################
# Get csv of annotations (url, label).
annotations = cos.Object(credentials_1['bucket'], '_annotations.csv').get()['Body']
annotations = pandas_support(annotations)
annotations_df = pd.read_csv(annotations, header=None)
annotations_df = annotations_df.set_index([1])

# Create a training and validation folder.
train_dir = 'train'

# Purge data if directories already exist.
if os.path.exists(train_dir) and os.path.isdir(train_dir):
    shutil.rmtree(train_dir)

os.mkdir(train_dir)

used_labels = annotations_df.index.unique().tolist()
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

    # Create zip files.
    shutil.make_archive(label, 'zip', train_label_dir)
print('done')


################################################################################
# Train model
################################################################################
