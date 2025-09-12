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

Date sdate = Date.newInstance(2023, 04, 01);
Date edate = Date.newInstance(2024, 06, 01);
Integer daysBetween = edate.daysBetween(sdate);
Decimal intr = 7366;
Decimal perDay = intr / daysBetween;
Integer appDay = edate.daysBetween(Date.newInstance(2024, 04, 01));
Decimal intr1 = appDay*perDay;
//System.debug('Interest : '+intr1);

sdate = Date.newInstance(2024, 06, 01);
edate = Date.newInstance(2025, 08, 02);
daysBetween = Math.abs(edate.daysBetween(sdate));
intr = 7927;
perDay = intr / daysBetween;
appDay = Math.abs(sDate.daysBetween(Date.newInstance(2025, 03, 31)));
System.debug('2nd*** : '+appDay);
System.debug('2nd**Pd : '+perDay);
Decimal intr2 = appDay*perDay;
System.debug('Interest2 : '+intr2);
Decimal res = intr1+intr2;
System.debug('Total paided*** : '+res);


Date sdate = Date.newInstance(2025, 08, 02);
Date edate = Date.newInstance(2026, 10, 03);
Date fEnd = Date.newInstance(2025, 03, 02);
Integer daysBetween = edate.daysBetween(sdate);
Decimal intr = 123965-115293;
Decimal perDay = intr / daysBetween;
Integer appDay = edate.daysBetween(Date.newInstance(2024, 04, 01));
Decimal intr1 = appDay*perDay;
System.debug('Interest : '+intr1);



