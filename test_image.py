import keras
import pickle
from keras.models import load_model
from keras.preprocessing import image
from keras.utils.generic_utils import CustomObjectScope
from keras import optimizers
import argparse
import numpy as np

parser = argparse.ArgumentParser()
parser.add_argument(
    '--image'
)
parser.add_argument(
    '--model'
)
args = parser.parse_args()

labels = []
with open('{}.labels'.format(args.model), 'rb') as fp:
    labels = pickle.load(fp)

# dimensions of our images
img_width, img_height = 224, 224

# load the model we saved
with CustomObjectScope({
    'relu6': keras.applications.mobilenet.relu6,
    'DepthwiseConv2D': keras.applications.mobilenet.DepthwiseConv2D
}):
    model = load_model(args.model)
    adm = optimizers.Adam(lr=0.001)
    model.compile(
        optimizer=adm,
        loss='categorical_crossentropy',
        metrics=['accuracy']
    )

    # predicting images
    img = image.load_img(args.image, target_size=(img_width, img_height))
    x = image.img_to_array(img)
    x = np.expand_dims(x, axis=0)

    classes = model.predict(x)
    for i, label in enumerate(labels):
        print('{}: {}'.format(label, classes[0][i]))
