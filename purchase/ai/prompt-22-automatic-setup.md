For a gmail user, how to automate the setup of google sheet with google apps script right from the flutter mobile app

Earlier you gave this proposal [ai-docu/automation-proposal.md]

In CommonOverFlowMenu, when user is not logged in, offer a menu option "Setup Google Sheets" as second item below "Login".  This "Setup Google Sheets" should not be visible when user is successfulled logged in

Implemenet a screen SetupGoogleSheet.  
- Implement Google Sign-in workflow.  
- Obtain required access code as required
  - If required google store access code in local_settings SQLite table or another standard secret storage in the mobile device.

Having obtained google account access
- Obtain desired Google Sheet Name as input value from the user
- Obtain desired AppCode as input from the user (appCode)
- Provide generate Google Sheet option.
- generate a new google sheet using respective api
- get hold of Google Apps Script Project of the new Google Sheet (ngs)
  - Create Sheet "config" in the ngs
    - with first row values ["name", "value", "description"]
    - with second row values ["APP_CODE", appCode given above, "the secret"]
  - Use AssetManifest as you used in CsvImportService
    - Get hold of backend-google-app-script-code/*.js files
    - Copy these files to the Google Apps Script project
  - Deploy the Google Apps Script project Web App
    - Execute as Signed-in google suer above
    - Who can Access: Anyone
    - Get hold of the Deployment Web App URL (appUrl)
    - Store the appUrl and appCode into local_settings using await _deltaSyncService.saveCredentials(appUrl, appCode)
      - I am wondering if we have to retain this access code.  If everything goes fine, the access code, refresh codes can be discarded
  - Setup Google Sheet worksheets by calling Google Apps Script Web App URL
    - POST appUrl
    - ContentType: application/json 
    - Body: { secret: appCode, operation: "setupSheets"}
    - If this fails with timeout, provide option to retry instead of giving up
  - If everything is successful, then on pressing back button, it should be treated like successful login scenario