import coremltools
import numpy
from keras.datasets import mnist
from keras.models import Sequential
from keras.layers import Dense
from keras.layers import Dropout
from keras.utils import np_utils
from keras.models import load_model


def convert_model(model):
	print('converting...')
	coreml_model = coremltools.converters.keras.convert(model,input_names=['image'],image_input_names='image')
	coreml_model.author = 'Tim LeMaster'
	coreml_model.license = 'MIT'
	coreml_model.short_description = 'Reads a handwritten digit. The model is based on keras mnist examples here. https://github.com/fchollet/keras/blob/master/examples/mnist_cnn.py.'
	coreml_model.input_description['image'] = 'A 28x28 pixel Image'
	coreml_model.output_description['output1'] = 'A one-hot Multiarray were the index with the biggest float value (0-1) is the recognized digit. '
	coreml_model.save('mnist_cnn.mlmodel')
	print('model converted')


import os.path
if os.path.isfile('mnist_cnn.h5'): 
	model = load_model('mnist_cnn.h5')
	convert_model(model)
else:
	print('no model found')