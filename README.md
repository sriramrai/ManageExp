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
SSELECT Id, Bank**c, Amount**c, Account_Number**c, Start_Date**c, Is_Closed**c, Year**c, Month**c, Day**c, Rate**c FROM Investment**c where Account_Number**c != 'TEST' AND Bank**c = 'SBI'

List<Investment**c> ivts = new List<Investment**c>();
for(Investment**c ivt : [SELECT Id, RecordtypeId from Investment**c WHERE BANK\_\_c = 'SBI']) {
ivt.recordTypeId = '012In000000gO83IAE'; // Query recordtyp Id and replace here, same as the AXIS
ivts.add(ivt);
}
update ivts;

SELECT Id, Investment**r.Account_Number**c, Investment**r.Id, Type**c, Amount**c,Tenure_Day**c, Tenure_Mnt**c, Tenure_Yr**c,Rate**c, Principle**c, Investment_Date**c, Maturity_Date**c, IS_TDS**c, TDS_Deducted**c, Comment**c, Incurred_Interest**c FROM Investment_Line_Items**c WHERE Investment**r.Bank**c = 'SBI' AND Investment**r.Name != 'TEST'

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

## Correct these record

HDFC Bank -- 7 bonus record is missing
Tata Motors commercial needs to be created
Nazara Technologies Stocks needs to be corrected its details number of stock is not correct.
field permission for Current Price and Code needs to be given to expense manager
