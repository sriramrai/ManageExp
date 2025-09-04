// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

string tempvar = 'Enter_your_name_here';
System.debug('Hello World!');
System.debug('My name is ' + tempvar);

System.debug(DataProvider.getAllInvestments());
System.debug(InvestmentController.getFYIntrest('2025-2026'));

System.debug('Data*** : '+JSON.serialize(DataProvider.getAllFutureInvestments()));

System.debug('Data*** : '+Schema.SobjectType.Investment__c.getRecordTypeInfosByName().get('Stock').getRecordTypeId());

ExpenseManagerUtil.getInterestWrapper('fy');

System.debug('test*** '+ JSON.serialize(ExpenseController.getCCStatements(9, 2025)));

Integer year = 2025;
Integer month = 9;
Date sDate = Date.newInstance(year, month, 01);
Date sDate = Date.newInstance(year, month, 01); //01/09/2025 lastMonthSDate = 01/08/2025
Integer noOfDays = Date.daysInMonth(year, month);
Date eDate = Date.newInstance(year, month, noOfDays); //30/09/2025 nextMonthEDate = 31/10/2025
System.debug('List*** : '+JSON.serialize(DataProvider.getPayments(sDate, eDate)));

