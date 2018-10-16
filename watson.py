# @hidden_cell
import os
import uuid
import shutil
import types
import time
import pandas as pd
import json
import itertools
import ibm_boto3
from botocore.client import Config
from watson_developer_cloud import VisualRecognitionV3, WatsonApiException
from tqdm import tqdm
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

file_count = 0

used_labels = annotations_df.index.unique().tolist()
for label in used_labels:
    file_list = annotations_df.loc[label].values.flatten()
    file_count = file_count + len(file_list)
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
    shutil.make_archive(os.path.join('zips', label), 'zip', train_label_dir)
print('done')


################################################################################
# Train model
################################################################################
visual_recognition = VisualRecognitionV3(
    '2018-03-19',
    iam_apikey=os.getenv('WATSON_API_KEY')
)

filedata = {filename + '_positive_examples': open(filename, 'rb') for filename in os.listdir('zips')}
model = visual_recognition.create_classifier(credentials_1['bucket'], **filedata).get_result()
print(model['classifier_id'])

estimatedTime = file_count * 10
pbar = tqdm(total=estimatedTime)
for i in itertools.count():
    if i % 20 == 0:
        classifier = visual_recognition.get_classifier(classifier_id=model['classifier_id']).get_result()
        if classifier['status'] == 'ready':
            break
    pbar.update(1)
    time.sleep(1)
pbar.close()

core_ml_model = visual_recognition.get_core_ml_model(classifier_id=model['classifier_id']).get_result()

mlmodel_path = credentials_1['bucket'] + '.mlmodel'
with open(mlmodel_path, 'wb') as fp:
    fp.write(core_ml_model.content)

print('uploading model...')
cos.Bucket(credentials_1['bucket']).upload_file(
    mlmodel_path,
    mlmodel_path
)
print('done')
