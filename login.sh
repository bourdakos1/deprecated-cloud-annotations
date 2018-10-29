#!/bin/bash
read -p 'Resource Instance ID: ' resourceId
read -sp 'API Key: ' apiKey

perl -pi -e "s/<key>apiKey<\/key>\n/<key>apiKey<\/key>/" ios-app/Core\ ML\ Vision/Credentials.plist
perl -pi -e "s/<key>apiKey<\/key>\s*<string>.*<\/string>/<key>apiKey<\/key>\n\t<string>$apiKey<\/string>/" ios-app/Core\ ML\ Vision/Credentials.plist
perl -pi -e "s/<key>resourceId<\/key>\n/<key>resourceId<\/key>/" ios-app/Core\ ML\ Vision/Credentials.plist
perl -pi -e "s/<key>resourceId<\/key>\s*<string>.*<\/string>/<key>resourceId<\/key>\n\t<string>$resourceId<\/string>/" ios-app/Core\ ML\ Vision/Credentials.plist

perl -pi -e "s/<key>apiKey<\/key>\n/<key>apiKey<\/key>/" data-collector/Data\ Collector/Credentials.plist
perl -pi -e "s/<key>apiKey<\/key>\s*<string>.*<\/string>/<key>apiKey<\/key>\n\t<string>$apiKey<\/string>/" data-collector/Data\ Collector/Credentials.plist
perl -pi -e "s/<key>resourceId<\/key>\n/<key>resourceId<\/key>/" data-collector/Data\ Collector/Credentials.plist
perl -pi -e "s/<key>resourceId<\/key>\s*<string>.*<\/string>/<key>resourceId<\/key>\n\t<string>$resourceId<\/string>/" data-collector/Data\ Collector/Credentials.plist

perl -pi -e "s/API_KEY=.*/API_KEY=$apiKey/" .Credentials
perl -pi -e "s/RESOURCE_INSTANCE_ID=.*/RESOURCE_INSTANCE_ID=$resourceId/" .Credentials
