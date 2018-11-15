from __future__ import absolute_import
from __future__ import division
from __future__ import print_function

from builtins import input

import fileinput
import getpass
import re

RESOURCE_ID = input('Resource Instance ID: ')
API_KEY = getpass.getpass(prompt='API Key: ')

DATA_COLLECTOR_APP = 'app-ios/data-collector/Data Collector/Credentials.plist'
INFERENCE_APP = 'app-ios/ios-app/Core ML Vision/Credentials.plist'
PYTHON_TRAINER = '.Credentials'

API_KEY_REGEX = "<key>apiKey</key>"
RESOURCE_ID_REGEX = "<key>resourceId</key>"
STRING_REGEX = "<string>.*</string>"

def replacePlistItem(filepath, regex, key):
    with fileinput.FileInput(filepath, inplace=True) as file:
        for line in file:
            line = re.sub(r'{}[\n\r]*'.format(regex), '{}'.format(regex), line)
            print(line, end='')
    with fileinput.FileInput(filepath, inplace=True) as file:
        for line in file:
            line = re.sub(r'{}\s*{}'.format(regex, STRING_REGEX), '{}\n\t<string>{}</string>'.format(regex, key), line)
            print(line, end='')

def iOSReplace(filepath):
  replacePlistItem(filepath, API_KEY_REGEX, API_KEY)
  replacePlistItem(filepath, RESOURCE_ID_REGEX, RESOURCE_ID)

def pythonReplace(filepath):
    with fileinput.FileInput(filepath, inplace=True) as file:
        for line in file:
            line = re.sub(r'API_KEY=.*[\n\r]*', 'API_KEY={}\n'.format(API_KEY), line)
            print(line, end='')
    with fileinput.FileInput(filepath, inplace=True) as file:
        for line in file:
            line = re.sub(r'RESOURCE_INSTANCE_ID=.*[\n\r]*', 'RESOURCE_INSTANCE_ID={}\n'.format(RESOURCE_ID), line)
            print(line, end='')

iOSReplace(DATA_COLLECTOR_APP)
iOSReplace(INFERENCE_APP)
pythonReplace(PYTHON_TRAINER)

print("\033[92mSuccessfully set credentials!\033[0m")
