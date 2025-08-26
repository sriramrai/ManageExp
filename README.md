# Salesforce DX Project: Next Steps

Now that you’ve created a Salesforce DX project, what’s next? Here are some documentation resources to get you started.

## How Do You Plan to Deploy Your Changes?

Do you want to deploy a set of changes, or create a self-contained application? Choose a [development model](https://developer.salesforce.com/tools/vscode/en/user-guide/development-models).

## Configure Your Salesforce DX Project

The `sfdx-project.json` file contains useful configuration information for your project. See [Salesforce DX Project Configuration](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_ws_config.htm) in the _Salesforce DX Developer Guide_ for details about this file.

## Read All About It

- [Salesforce Extensions Documentation](https://developer.salesforce.com/tools/vscode/)
- [Salesforce CLI Setup Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/sfdx_setup_intro.htm)
- [Salesforce DX Developer Guide](https://developer.salesforce.com/docs/atlas.en-us.sfdx_dev.meta/sfdx_dev/sfdx_dev_intro.htm)
- [Salesforce CLI Command Reference](https://developer.salesforce.com/docs/atlas.en-us.sfdx_cli_reference.meta/sfdx_cli_reference/cli_reference.htm)


https://www.pantherschools.com/setup-ci-cd-using-github-actions/

sf org create scratch --definition-file config/project-scratch-def.json --alias MyHub --set-default --target-dev-hub ExpenseApp --duration-days 30 (Make Sure that ExpenseApp should have same name as the hub name which you want to connect to , you can find out that using sf org list)

sf project deploy start -a 58.0
sf project retrieve start -o ExpenseApp -x ./package.xml
sf project retrieve start --ignore-conflicts -o ExpenseApp -x ./package.xml

sf org assign permset --name ExpenseManager

// Data export
SSELECT Id, Bank__c, Amount__c, Account_Number__c, Start_Date__c, Is_Closed__c, Year__c, Month__c, Day__c, Rate__c FROM Investment__c where Account_Number__c != 'TEST' AND Bank__c = 'SBI'

List<Investment__c> ivts = new List<Investment__c>();
for(Investment__c ivt : [SELECT Id, RecordtypeId from Investment__c WHERE BANK__c = 'SBI']) {
    ivt.recordTypeId = '012In000000gO83IAE'; // Query recordtyp Id and replace here, same as the AXIS
    ivts.add(ivt);
}
update ivts;

SELECT Id, Investment__r.Account_Number__c, Investment__r.Id, Type__c, Amount__c,Tenure_Day__c, Tenure_Mnt__c, Tenure_Yr__c,Rate__c, Principle__c, Investment_Date__c, Maturity_Date__c, IS_TDS__c, TDS_Deducted__c, Comment__c, Incurred_Interest__c FROM Investment_Line_Items__c WHERE Investment__r.Bank__c = 'SBI' AND Investment__r.Name != 'TEST'




System@1992!1994

Record mandatory to create
Need to create Salary Structure record.
Create record under Declaration

Mkdir data

Mkdir mdapioutput
sfdx force:source:convert -d mdapioutput -x manifest/package.xml

Source
sfdx force:source:convert -d deploy
sfdx force:source:convert --manifest=manifest/package.xml -d deploy ///// Need to explore this will help to deploy only merged changes
sf project deploy start --metadata-dir deploy -o ExpenseApp


key=DE3B4F6346E0CFA95CA695168A0FD8DA4D06AE808A0AFA9A4DBD2502D5DD6FE7
iv =AC767FEDCF2105140E84B62495C3F43A

openssl enc -nosalt -aes-256-cbc -in server.key -out server.key.enc -base64 -K DE3B4F6346E0CFA95CA695168A0FD8DA4D06AE808A0AFA9A4DBD2502D5DD6FE7 -iv AC767FEDCF2105140E84B62495C3F43A

8.13 69%

sf org login web --client-id 3MVG9d8..z.hDcPIPF8.sGvQITMSwmTy5SAtW6n3QReT8QvfKwa01IBEknP3V28Ivfnu5u8R5yysrDpdSxtYa --set-default-dev-hub --alias my-hub-org

3MVG9d8..z.hDcPIPF8.sGvQITMSwmTy5SAtW6n3QReT8QvfKwa01IBEknP3V28Ivfnu5u8R5yysrDpdSxtYa

CSec
08F0F888027E286503F782981AB605D43F98ED17CC418E858604483055CB9A93