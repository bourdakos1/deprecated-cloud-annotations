#!/bin/bash
read -p 'Resource Instance ID: ' RESOURCE_ID
read -sp 'API Key: ' API_KEY

DATA_COLLECTOR_APP=data-collector/Data\ Collector/Credentials.plist
INFERENCE_APP=ios-app/Core\ ML\ Vision/Credentials.plist
PYTHON_TRAINER=.Credentials

API_KEY_REGEX="<key>apiKey<\/key>"
RESOURCE_ID_REGEX="<key>resourceId<\/key>"
STRING_REGEX="<string>.*<\/string>"


replacePlistItem () {
  perl -pi -e "s/$1\n/$1/" "$3"
  perl -pi -e "s/$1\s*$STRING_REGEX/$1\n\t<string>$2<\/string>/" "$3"
}

iOSReplace () {
  replacePlistItem "$API_KEY_REGEX" "$API_KEY" "$1"
  replacePlistItem "$RESOURCE_ID_REGEX" "$RESOURCE_ID" "$1"
}

pythonReplace () {
  perl -pi -e "s/API_KEY=.*/API_KEY=$API_KEY/" "$1"
  perl -pi -e "s/RESOURCE_INSTANCE_ID=.*/RESOURCE_INSTANCE_ID=$RESOURCE_ID/" "$1"
}

iOSReplace "$DATA_COLLECTOR_APP"
iOSReplace "$INFERENCE_APP"
pythonReplace "$PYTHON_TRAINER"
