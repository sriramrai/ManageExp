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


Date sdate = Date.newInstance(2024, 04, 01);
Date edate = Date.newInstance(2025, 03, 31);
ExpenseManagerUtil.getInterestWrapper('test');
System.debug('daat*** : '+JSON.serialize(DataProvider.getAllLines(sdate, edate)));

396 => 4528+509 = 5037; /day = 12.71

applicable date => 127 => 1452 RS. 1615 Rs.

395 => 5328+52 = 5380 /day 13.62

applicable date = 237 => 3196 => 3228 Rs.


According to SBI => 4853 and 486
According to me => 4648


UtilityClass.debug('Account', [SELECT id, Name From Account]);

4528+509

Date sdate = Date.newInstance(2025, 04, 01);
Date edate = Date.newInstance(2026, 03, 31);
System.debug('result*** : '+DataProvider.getExpenseByMonth(sdate, edate));
Investment_Line_Items__c lineItem = [SELECT Id, Investment__r.Account_Number__c, Investment__r.Bank__c, Investment__r.Id, Type__c, Amount__c,Tenure_Day__c, Tenure_Mnt__c, Tenure_Yr__c,Rate__c, Principle__c, Investment_Date__c, Maturity_Date__c, IS_TDS__c, TDS_Deducted__c, Comment__c, Incurred_Interest__c FROM Investment_Line_Items__c WHERE Id = 'a04In000005fzqeIAA' LIMIT 1];
System.debug('interest*** : '+ExpenseManagerUtilHelper.calculateInterest(lineItem, sdate, edate));

2719 => Accumulated 0 Paid => 6677.33 TDS => 818.14
2719 => Accumulated 5595 Paid => 1832 TDS => 744 (According to bank)


7366 => 


