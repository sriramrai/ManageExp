// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents
delete [SELECT Id FROM Sync_Data__c WHERE Name != 'SD-00060'];
SyncDataController.syncData();

List<Sync_Data_Item__c> syncDataItems = [SELECT Id, Name, Data__c, Level__c, Inserted_Records__c, Sync_Data__c FROM Sync_Data_Item__c WHERE Sync_Data__c = 'a09In000002j7GMIAY'];
for(Sync_Data_Item__c syncDataItem : syncDataItems) {
    syncDataItem.Inserted_Records__c = null;
}
update syncDataItems;
String syncDataId = 'a09In000002j8UEIAY';
Database.executeBatch(new SyncDataInsertClone(syncDataId));

delete [select Id FROM Account where Name like 'BT%'];
Database.executeBatch(new SyncDataInsert());

List<Account> accounts = [select Id, Name From Account where Name like 'New Account%'];
List<Contact> cons = new List<Contact>();
for(Account account : accounts) {
    for(Integer i=0; i<10; i++) {
        Contact con = new Contact();
        con.Firstname = account.Name;
        con.lastName = 'Con'+i;
        con.Phone = '0123455';
        con.Email = con.lastName+'@gmail.com';
        con.AccountId = account.Id;
        cons.add(con);
    }
}
insert cons;

String message = 'Error *** : unexpected token: ';
if(message.contains('Error1')) {
    System.debug('Error Occcured...');
}else {
    System.debug('No Error');
}

'001In00000Ap5wtIAB','001In00000Ap5wuIAB','001In00000Ap5wvIAB','001In00000Ap5wwIAB','001In00000Cm5cMIAR'

SyncDataController.SyncDataWrapper sdw = new SyncDataController.SyncDataWrapper();
sdw.step = 'l2';
Sync_Data__c sd = [SELECT Id, L1__c, L2__c from Sync_Data__c WHERE ID = 'a09In000002j7DcIAI' LIMIT 1];
System.debug('nextstep*** : '+SyncDataController.getNextObject(sdw, sd));

String step = 'l1';
String stepSuffix = step.substring(1, step.length()-1);
System.debug('stepSuffix*** : '+stepSuffix);

String str = 'l250';
System.debug(str.substring(1, str.length()));


List<AsyncApexJob> jobs = [SELECT Id, Status, JobType 
                           FROM AsyncApexJob 
                           WHERE Status IN ('Queued','Holding','Processing') 
                           AND JobType IN ('BatchApex','Queueable')];

for(AsyncApexJob job : jobs) {
    System.abortJob(job.Id);
}


List<String> records = new List<String>{'a', 'b', 'c'};
String serilized = JSON.serialize(records);
List<String> recordsD = (List<String>)JSON.deserialize(serilized, List<String>.class);
System.debug('serilized*** : '+ serilized);
System.debug('recordsD**** : '+recordsD);
