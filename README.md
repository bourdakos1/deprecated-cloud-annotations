# Cloud Annotations
![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539811142193_schematic.png)

The endless cycle of machine learning is as follows:
- Collect data
- Label data
- Train/retrain a model with the labeled data
- Deploy the model

Everything revolves around an object storage bucket.
### Collect data
Image files added to your bucket automatically show up in the Cloud Annotation tool as unlabeled. As a convenience, an iOS app is provided that automatically uploads photos taken straight to your bucket.
### Label data
The Cloud Annotation tool allows you to quickly and easily label any image data you add. Once images are labeled in the tool, an annotations file is generated. The annotation file is a simple csv with all your image urls and it's label.
### Train/retrain a model with the labeled data
The annotations generated by the Cloud Annotation tool can be used to create a model through any method of your choosing. Two convenience scripts are provided. One to train a Core ML model using Watson Visual Recognition and one to train a MobileNet CoreML model using Keras/TensorFlow.

## Create a Cloud Object Storage instance

Log in or sign up for [IBM Cloud](https://console.bluemix.net/).

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539804040052_Screen+Shot+2018-10-17+at+2.35.53+PM.png)

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539804229570_Screen+Shot+2018-10-17+at+2.36.18+PM.png)

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539804685813_Screen+Shot+2018-10-17+at+2.37.27+PM.png)

Create a new service credential with write permissions.
![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539807399869_Screen+Shot+2018-10-17+at+3.00.09+PM.png)

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539805631823_Screen+Shot+2018-10-17+at+3.00.17+PM.png)

Click the `View credentials` drop down and take note of your `apikey` and your `resource_instance_id`.
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
## Add credentials to the annotation tool
![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539807682825_Screen+Shot+2018-10-17+at+4.21.05+PM.png)
