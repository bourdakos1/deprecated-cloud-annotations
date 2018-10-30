# @hidden_cell
import os
import uuid
import shutil
import types
import pandas as pd
import pickle
import keras
import argparse
import ibm_boto3
from botocore.client import Config
from keras.applications.mobilenet import MobileNet, preprocess_input
from keras.preprocessing.image import ImageDataGenerator
from keras import optimizers
from keras.models import Model
from keras.layers import Conv2D, Reshape, Activation, GlobalAveragePooling2D, Dense, Dropout
from keras.callbacks import Callback
from keras.callbacks import ModelCheckpoint
from keras.utils.generic_utils import CustomObjectScope
from dotenv import load_dotenv
load_dotenv('.Credentials')

parser = argparse.ArgumentParser()
parser.add_argument(
    '--cache',
    help='Use the existing train folder, if one exists.',
    action='store_true'
)
parser.add_argument(
    '--bucket',
    help='Object Storage bucket to pull from.'
)
args = parser.parse_args()

def __iter__(self): return 0
def pandas_support(csv):
    # add missing __iter__ method, so pandas accepts body as file-like object
    if not hasattr(csv, "__iter__"): csv.__iter__ = types.MethodType( __iter__, csv )
    return csv

# def upload_as_coreml(cos, bucket, class_labels):
#     keras_path = bucket + '.h5'
#     mlmodel_path = bucket + '.mlmodel'
#     with CustomObjectScope({
#         'relu6': keras.applications.mobilenet.relu6,
#         'DepthwiseConv2D': keras.applications.mobilenet.DepthwiseConv2D
#     }):
#         with open('{}.labels'.format(keras_path), 'wb') as fp:
#             pickle.dump(class_labels, fp)
#
#         coreml_model = convert(
#             keras_path,
#             input_names='image',
#             image_input_names='image',
#             red_bias=-123,
#             green_bias=-117,
#             blue_bias=-104,
#             class_labels=sorted(class_labels)
#         )
#
#         coreml_model.save(mlmodel_path)
#
#         print('uploading model...')
#         cos.Bucket(bucket).upload_file(
#             mlmodel_path,
#             mlmodel_path
#         )
#         print('done')

class COSCheckpoint(Callback):
    def __init__(self, cos_resource, bucket, class_labels):
        self.cos_resource = cos_resource
        self.bucket = bucket
        self.class_labels = class_labels
        self.last_change = None

    def on_epoch_end(self, *args):
        epoch_nr, logs = args

        if os.path.getmtime(self.path_local) != self.last_change:
            upload_as_coreml(self.cos_resource, self.bucket, self.class_labels)
            self.last_change = os.path.getmtime(self.path_local)
        else:
            print('model didn\'t improve - no upload')


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
# Hyperparameters
################################################################################
IMG_WIDTH, IMG_HEIGHT = 224, 224
EPOCHS = 20
BATCH_SIZE = 50
TRAINABLE_LAYERS = 6
LEARNING_RATE = 0.001


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
train_dir = 'train'

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
           if bucket_id_name < len(bucket_list):
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


# Get csv of annotations (url, label).
annotations = cos.Object(credentials_1['bucket'], '_annotations.csv').get()['Body']
annotations = pandas_support(annotations)
annotations_df = pd.read_csv(annotations, header=None)
annotations_df = annotations_df.set_index([1])

used_labels = annotations_df.index.unique().tolist()

if not args.cache or not os.path.exists(train_dir) or not os.path.isdir(train_dir):
    # Purge data if directories already exist.
    if os.path.exists(train_dir) and os.path.isdir(train_dir):
        shutil.rmtree(train_dir)
        if args.cache:
            print('No {} directory found.\ndownloading bucket...'.format(train_dir))
        else:
            print('Note: Try using the `--cache` flag to avoid redownloading the bucket.')

    os.mkdir(train_dir)

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
else:
    print('Using cached data...')

def subtract_mean(x):
    x[:,:,0] -= 123
    x[:,:,1] -= 117
    x[:,:,2] -= 104
    return preprocess_input(x)

datagen = ImageDataGenerator(
    horizontal_flip=True,
    preprocessing_function=subtract_mean
)

train_generator = datagen.flow_from_directory(
    train_dir,
    target_size=(IMG_WIDTH, IMG_HEIGHT),
    batch_size=BATCH_SIZE
)


################################################################################
# Build model
################################################################################
mobile = MobileNet(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
mobile.summary()

# Freeze the layers except the last layers
if TRAINABLE_LAYERS == 0:
    for layer in mobile.layers:
        layer.trainable = False
else:
    for layer in mobile.layers[:-TRAINABLE_LAYERS]:
        layer.trainable = False

x = mobile.output
x = GlobalAveragePooling2D()(x)
x = Reshape((1, 1, 1024))(x)
x = Dropout(0.01)(x)
x = Conv2D(len(used_labels), (1, 1), activation='softmax', padding='same')(x)
predictions = Reshape((len(used_labels),))(x)

model = Model(inputs=mobile.input, outputs=predictions)
model.summary()

adm = optimizers.Adam(lr=LEARNING_RATE)

# Compile the model
model.compile(
    optimizer=adm,
    loss='categorical_crossentropy',
    metrics=['accuracy']
)


################################################################################
# Train model
################################################################################
model_path = credentials_1['bucket'] + '.h5'

cos_persist = COSCheckpoint(
    cos_resource=cos,
    bucket=credentials_1['bucket'],
    class_labels=used_labels
)

checkpoint = ModelCheckpoint(
    model_path,
    monitor='loss',
    verbose=1,
    save_best_only=True,
    mode='min'
)

all_callbacks = [checkpoint, cos_persist]
train_steps = train_generator.samples / train_generator.batch_size

# Train the model
history = model.fit_generator(
    train_generator,
    steps_per_epoch=train_steps,
    epochs=EPOCHS,
    callbacks=None,
    verbose=1
)

model.save(model_path)

keras_path = credentials_1['bucket'] + '.h5'
with open('{}.labels'.format(keras_path), 'wb') as fp:
    pickle.dump(used_labels, fp)

# upload_as_coreml(cos, credentials_1['bucket'], used_labels)
