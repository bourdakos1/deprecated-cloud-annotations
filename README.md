# Think of A Title

## Create a Cloud Object Storage instance

Log in or sign up for [IBM Cloud](https://console.bluemix.net/).

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539804040052_Screen+Shot+2018-10-17+at+2.35.53+PM.png)

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539804229570_Screen+Shot+2018-10-17+at+2.36.18+PM.png)

![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539804685813_Screen+Shot+2018-10-17+at+2.37.27+PM.png)

Create a new service credential with write permissions.
![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539805441230_Screen+Shot+2018-10-17+at+3.00.09+PM.png)

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
![](https://d2mxuefqeaa7sj.cloudfront.net/s_E7D1C1E8D801F89315B72C10AD83AE795982C7EB84F7BA48CECD8A576B02D6CC_1539803159653_Screen+Shot+2018-10-17+at+2.57.36+PM.png)
