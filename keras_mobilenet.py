# @hidden_cell
import os
import uuid
import shutil
import types
import pandas as pd
import ibm_boto3
import keras
from botocore.client import Config
from keras.applications.mobilenet import MobileNet, preprocess_input
from keras.preprocessing.image import ImageDataGenerator
from keras import optimizers
from keras.models import Model
from keras.layers import Conv2D, Reshape, Activation, GlobalAveragePooling2D, Dense, Dropout
from keras.callbacks import Callback
from keras.callbacks import ModelCheckpoint
from keras.utils.generic_utils import CustomObjectScope
from coremltools.converters.keras import convert
from dotenv import load_dotenv
load_dotenv()

def __iter__(self): return 0
def pandas_support(csv):
    # add missing __iter__ method, so pandas accepts body as file-like object
    if not hasattr(csv, "__iter__"): csv.__iter__ = types.MethodType( __iter__, csv )
    return csv

def upload_as_coreml(cos, bucket, class_labels):
    keras_path = bucket + '.h5'
    mlmodel_path = bucket + '.mlmodel'
    with CustomObjectScope({
        'relu6': keras.applications.mobilenet.relu6,
        'DepthwiseConv2D': keras.applications.mobilenet.DepthwiseConv2D
    }):
        coreml_model = convert(
            keras_path,
            input_names='image',
            image_input_names='image',
            red_bias=-123,
            green_bias=-117,
            blue_bias=-104,
            class_labels=sorted(class_labels)
        )

        coreml_model.save(mlmodel_path)

        print('uploading model...')
        cos.Bucket(bucket).upload_file(
            mlmodel_path,
            mlmodel_path
        )
        print('done')

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
  'bucket': os.getenv('BUCKET'),
  'iam_url': 'https://iam.ng.bluemix.net/oidc/token',
  'api_key': os.getenv('API_KEY'),
  'resource_instance_id': os.getenv('RESOURCE_INSTANCE_ID'),
  'url': 'https://s3-api.us-geo.objectstorage.service.networklayer.com'
}


################################################################################
# Hyperparameters
################################################################################
IMG_WIDTH, IMG_HEIGHT = 224, 224
EPOCHS = 20
BATCH_SIZE = 50
TRAINABLE_LAYERS = 0
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

# Create a training folder.
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
print('done')

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
for layer in mobile.layers[:-TRAINABLE_LAYERS]:
    layer.trainable = False

x = mobile.output
x = GlobalAveragePooling2D()(x)
x = Reshape((1, 1, 1024))(x)
x = Dropout(0.01)(x)
x = Conv2D(1024, (1, 1), activation='relu', padding='same')(x)
x = Dense(len(used_labels), activation='softmax')(x)
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
train_steps = train_generator.samples // train_generator.batch_size

# Train the model
history = model.fit_generator(
    train_generator,
    steps_per_epoch=train_steps,
    epochs=EPOCHS,
    callbacks=None,
    verbose=1
)

model.save(model_path)

upload_as_coreml(cos, credentials_1['bucket'], used_labels)
