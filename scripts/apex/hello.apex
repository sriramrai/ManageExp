String data = '[{"attributes":{"type":"Expense__c","url":"/services/data/v65.0/sobjects/Expense__c/a0TGA00000k5c8o2AA"},"OwnerId":"0057F000002MzEsQAK","Id":"a0TGA00000k5c8o2AA","End_Date__c":"2025-12-31","Name":"Dec 25","Start_Date__c":"2025-12-01"}]';
String objectName = 'Expense__c';
Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
Set<String> creatableFields = new Set<String>();
Map<String, String> fieldTypeMap = new Map<String, String>();
for (Schema.SObjectField sf : fieldMap.values()) {
    Schema.DescribeFieldResult dfr = sf.getDescribe();
    if (dfr.isCreateable()) {
        creatableFields.add(dfr.getName());
        fieldTypeMap.put(dfr.getName(), String.valueOf(dfr.getSoapType()));
    }
}
List<Object> rawList = (List<Object>) JSON.deserializeUntyped(data);
for(Object obj : rawList) {
    Map<String, Object> row = (Map<String, Object>) obj;
    SObject newRecord = targetType.newSObject();
    String recordId;
    for (String field : row.keySet()) {
        if(!fieldMap.containsKey(field)) {
            continue;
        }
        if (!creatableFields.contains(field)) {
            continue;
        }
        Object fieldValue = row.get(field);
        String fieldType = fieldTypeMap.get(field);
        System.debug('field*** : '+field);
        System.debug('field type**** : '+fieldType);
        if(fieldType == 'STRING' || fieldType == 'ID') {
            newRecord.put(field, (String)fieldValue);
        }else if(fieldType == 'BOOLEAN') {
            newRecord.put(field, (Boolean)fieldValue);
        }else if(fieldType == 'DATE') {
            System.debug('fieldValue***** : '+(String)fieldValue);
            String fieldValueStr = String.valueOf(fieldValue);
            //String dateValue = String.valueOf(fieldValue).trim();
            newRecord.put(field, Date.valueOf(fieldValueStr));
        }
    }
    System.debug('newRecord **** : '+newRecord);
}

String str = '2025-12-31';
Date dt = Date.valueOf(str);
System.debug('dt** : '+dt);



Sync_Data_Item__c syncDataItem = [SELECT Id, Data__c FROM Sync_Data_Item__c WHERE ID = 'a08Hy000006C15sIAC' LIMIT 1];
syncDataItem = SyncDataController.formatAndFillData(syncDataItem, 'Investment__c');
System.debug('recordType Map *** : '+SyncDataController.getRecordTypeMap('Investment__c'));
update syncDataItem;
System.debug('JSON.serialize(syncDataItem)*** : '+JSON.serialize(syncDataItem.Data__c));

System.debug('2024-2025** : '+JSON.serialize(ExpenseManagerUtil.getExpenseByMonth('2024-2025')));
System.debug('2025-2026** : '+JSON.serialize(ExpenseManagerUtil.getExpenseByMonth('2025-2026')));

Date todayDate = Date.today();
Integer lastDay = Date.daysInMonth(todayDate.year(), todayDate.month());
Date lastDateOfMonth = Date.newInstance(todayDate.year(), todayDate.month(), lastDay);
System.debug('lastDateOfMonth*** : '+lastDateOfMonth);

Date endDate = lastDateOfMonth.addMonths(-5);
endDate = Date.newInstance(endDate.year(), endDate.month(), 1);
System.debug('endDate*** : '+JSON.serialize(SyncDataController.getAvailableObjects()));

System.debug


delete [select id, name, Bank__c, RecordType.Name, Account_Number__c from Investment__c order by Account_Number__c desc];
List<Sync_Data_Item__c> syncDs = [select id, name, Completed__c, Level__c,Record_Count__c, Error_Message__c,  Child_Record__c, Data__c, Inserted_Records__c from Sync_Data_Item__c where Sync_Data__c = 'a09Hy00000kkfD5IAI'];
for(Sync_Data_Item__c sd : syncDs) {
    sd.Completed__c = false;
    sd.Error_Message__c = '';
    sd.Inserted_Records__c = '';
}
update syncDs;

String syncDataId = 'a09Hy00000kkfD5IAI';
Database.executeBatch(new SyncDataInsertClone(syncDataId), 1);

SyncDataHandler.syncData();
// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

Sync_Data_Configuration__mdt config = Sync_Data_Configuration__mdt.getAll().get('Sync_Data_Config');
System.debug('config*** : '+config);

System.debug(SyncDataHandler.analyzeData());

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

// Processing the whatsapp messages manually from execute anonymous
List<String> records = new List<String>{'a', 'b', 'c'};
String serilized = JSON.serialize(records);
List<String> recordsD = (List<String>)JSON.deserialize(serilized, List<String>.class);
System.debug('serilized*** : '+ serilized);
System.debug('recordsD**** : '+recordsD);


String input = '600 purchased rice icici cc  emi 12m';

Pattern p = Pattern.compile('\\b(\\d{1,2}m)\\b');
Matcher m = p.matcher(input);

String emiTenure = null;

if (m.find()) {
    emiTenure = m.group(1);
}

System.debug(emiTenure); // Output: 3m


// One-time script: Populate Closed_Date__c from Investment_Line_Item__c records
List<Investment__c> investmentsToUpdate = new List<Investment__c>();

// Query all closed investments that don't have a Closed_Date__c yet
List<Investment__c> closedInvestments = [
    SELECT Id, Is_Closed__c, Closed_Date__c
    FROM Investment__c
    WHERE Is_Closed__c = true 
    AND Closed_Date__c = null
];

System.debug('Found ' + closedInvestments.size() + ' investments to process');

for(Investment__c inv : closedInvestments) {
    // Find the related Investment_Line_Item__c with Type = 'closed'
    List<Investment_Line_Items__c> closedLineItems = [
        SELECT Id, Date__c, Type__c
        FROM Investment_Line_Items__c
        WHERE Investment__c = :inv.Id
        AND Type__c = 'closed'
        ORDER BY Date__c DESC
        LIMIT 1
    ];
    
    // If a closed line item exists, use its date to populate Closed_Date__c
    if(!closedLineItems.isEmpty()) {
        inv.Closed_Date__c = closedLineItems[0].Date__c;
        investmentsToUpdate.add(inv);
        System.debug('Investment ' + inv.Id + ' will be updated with Closed_Date: ' + closedLineItems[0].Date__c);
    } else {
        System.debug('Warning: No closed line item found for Investment ' + inv.Id);
    }
}

// Update all investments
if(!investmentsToUpdate.isEmpty()) {
    try {
        update investmentsToUpdate;
        System.debug('Successfully updated ' + investmentsToUpdate.size() + ' investments');
    } catch(Exception e) {
        System.debug('Error updating investments: ' + e.getMessage());
    }
} else {
    System.debug('No investments needed updating');
}

System.debug('result**** : '+WhatsAppWebhook.parseLine('panir roll shopping 29/03'));