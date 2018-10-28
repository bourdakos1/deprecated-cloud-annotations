# Cloud Annotations
![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539811142193_schematic.png)

## The Cycle of Machine Learning
### Collect data
Everything revolves around an object storage bucket.

Image files added to your bucket automatically show up in the Cloud Annotation tool as unlabeled. As a convenience, an iOS app is provided that automatically uploads photos taken straight to your bucket.

### Label data
The Cloud Annotation tool allows you to quickly and easily label any image data you add. Once images are labeled in the tool, an annotations file is generated. The annotation file is a simple csv with all your image urls and it's label.

### Train/retrain a model with the labeled data
The annotations generated by the Cloud Annotation tool can be used to create a model through any method of your choosing. Two convenience scripts are provided. One to train a Core ML model using Watson Visual Recognition and one to train a MobileNet CoreML model using Keras/TensorFlow.

### Model Deployment
The two scripts provided automatically upload your fully trained model to your object storage bucket. As a convenience, another iOS app is provided that checks your bucket for any updates to the model. If updates are available they are automatically downloaded and compiled inside the users app.

To allow for developement and testing of models without interfering with your production apps, you can set branch flags for your model.

## Creating a Cloud Object Storage Instance
Log in or sign up for [IBM Cloud](https://console.bluemix.net/).

This is your IBM Cloud dashboard where you can create and manage IBM Cloud resources. We need to create an Object Storage instance to hold our images, annotations and trained models.

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539804040052_Screen+Shot+2018-10-17+at+2.35.53+PM.png)

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539804229570_Screen+Shot+2018-10-17+at+2.36.18+PM.png)

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539804685813_Screen+Shot+2018-10-17+at+2.37.27+PM.png)

## Getting Credentials
In order for us to access our Object Storage instance, we need to create credentials for it. 

Create a new service credential with the role of **Writer**.
![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539807399869_Screen+Shot+2018-10-17+at+3.00.09+PM.png)

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539805631823_Screen+Shot+2018-10-17+at+3.00.17+PM.png)

Click the **View credentials ▾** dropdown and take note of your **apikey** and your **resource_instance_id**.
![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539805788894_Screen+Shot+2018-10-17+at+2.41.53+PM.png)
```diff
{
+ "apikey": "...",
  "cos_hmac_keys": {
    "access_key_id": "...",
    "secret_access_key": "..."
},
  "endpoints": "...",
  "iam_apikey_description": "...",
  "iam_apikey_name": "...",
  "iam_role_crn": "...",
  "iam_serviceid_crn": "...",
+ "resource_instance_id": "..."
}
```
## Using the Cloud Annotations Tool
https://testannotations.us-east.containers.appdomain.cloud

Just add your object storage credentials and ideally the rest should be pretty self explanatory 🤞.
![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539807682825_Screen+Shot+2018-10-17+at+4.21.05+PM.png)

> [Sample Training Data](https://github.com/bourdakos1/Cloud-Annotations/releases/download/v1.0/workshop-training-data.zip)

## Training a Model
> **Requirements:** python 3.5 or 3.6 (NOT 3.7)
> 
> Run `python3 --version` to check
> 
> If you installed python with brew and have python 3.7, run:
> 
> `brew unlink python`
>
> followed by:
> 
> `brew install https://raw.githubusercontent.com/Homebrew/homebrew-core/f2a764ef944b1080be64bd88dca9a1d80130c558/Formula/python.rb`

Clone the repo:
```bash
git clone https://github.com/bourdakos1/Cloud-Annotations.git && cd Cloud-Annotations
```

Install the requirements:
```bash
pip install -r keras_requirements.txt
```

Add your Object Storage credentials to the `.Credentials` file:
```
API_KEY=
RESOURCE_INSTANCE_ID=
```

Run the script:
```
python keras_mobilenet.py
```

## Setting up the iOS Apps
Two iOS apps are provided. One to collect data, and the other pulls the most recent version of your model and allows you to run inferences with it.

If you haven't done so already, clone the repo and cd into the root directory:
```bash
git clone https://github.com/bourdakos1/Cloud-Annotations.git && cd Cloud-Annotations
```

An easy way to open the project folder is to run:
```bash
open .
```

Then double click the <ProjectName>.xcodeproj file to open the project in Xcode.

For both, your will need to add your Object Storage credentials to the `Credentials.plist` file found in your project after opening it in Xcode.
