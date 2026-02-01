public with sharing class SyncDataController {
    private static Integer OFFSET_SIZE = 30;
    private static String syncDataRef;
    public static void syncData() {
        Sync_Data__c sdata = new Sync_Data__c();
        sdata.Object_Name__c = 'Expense__c';
        sdata.L1__c = 'Expense__c';
        sdata.L2__c = 'Expense_Line_Item__c';
        sdata.L3__c = 'Payment__c';
        sdata.L2_REF__c = 'Expense__c';
        sdata.L3_REF__c = 'Expense_Line_Item__c';
        Date filteredDate = Date.newInstance(2026, 01, 18);
        sdata.Date_Filter__c = filteredDate;
        insert sdata;
        syncDataRef = sdata.Id;
        System.debug('sdata*** : '+sdata.Id);
        String objectName = 'Expense__c';
        Integer offset = 0;
        String step = 'l1';
        String syncDataId = sdata.Id;
        String filter = null;
        String syncDataItemId = null;
        Database.executeBatch(new SyncDataQueueable(objectName, offset, step, filter, syncDataId, syncDataItemId), 1);
    }

    private static String nextStep(String step) {
        String stepSuffix = step.substring(1, step.length());
        Integer stepNum = Integer.valueOf(stepSuffix)+1;
        if(stepNum > 2) {
            return null;
        }
        return 'l'+String.valueOf(stepNum);
    }

    public static string getNextObjectReference(String step, Sync_Data__c syncData) {
        String nextStep = nextStep(step);
        if(nextStep == null) {
            return null;
        }
        String fieldApiName = nextStep+'_REF__c';
        String fieldValue = String.valueOf(syncData.get(fieldApiName));
        if(String.isNotBlank(fieldValue)) {
            return fieldValue;
        }
        return null;
    }

    public static String getNextObject(String step, Sync_Data__c syncData) {
        String nextStep = nextStep(step);
        if(nextStep == null) {
            return null;
        }
        String fieldApiName = nextStep+'__c';
        String fieldValue = String.valueOf(syncData.get(fieldApiName));
        if(String.isNotBlank(fieldValue)) {
            return fieldValue;
        }
        return null;
    }

    private static Boolean isPendingSyncDateItem(String syncDataId, String level) {
        List<Sync_Data_Item__c> sdItems = new List<Sync_Data_Item__c>([
            SELECT Id, Name FROM Sync_Data_Item__c
            WHERE Sync_Data__c =: syncDataId AND Level__c =: level
            AND Child_Fetched__c = false
            LIMIT 1
        ]);
        Boolean found = sdItems.size() > 0 ? true : false;
        return found;
    }

    private static string requestMore(String objectName, SyncDataWrapper wrapper, String objectRef) {
        String currentStep = 'l1';
        String syncDataId = wrapper.syncDataId;
        List<Sync_Data_Item__c> sdItems = new List<Sync_Data_Item__c>([
            SELECT Id, recordId__c FROM Sync_Data_Item__c WHERE Sync_Data__c =: syncDataId AND Level__c =:currentStep
            AND Child_Fetched__c = false LIMIT 1
        ]);
        System.debug('sdItems**** : '+sdItems);
        System.debug('currentStep*** : '+currentStep);
        System.debug('syncDataId*** : '+syncDataId);
        if(sdItems.isEmpty()) {
            return checkAndProcessNextObject(wrapper);
        }else {
            String nextStep = nextStep(wrapper.step);
            wrapper.syncDataItemId = sdItems[0].Id;
            wrapper.filter = ' WHERE ' + objectRef + ' IN ' +sdItems[0].RecordId__c;
            wrapper.offset = 0;
            wrapper.step = nextStep;
            wrapper.objectName = objectName;
        }

        return JSON.serialize(new ProcessedResult(wrapper));
    }

    private static List<Sync_Data_Item__c> getSyncDataItem(){
        return null;
    }

    private static String checkAndProcessNextObject(SyncDataWrapper wrapper) {
        String result;
        Sync_Data__c syncData = [SELECT Id, Name, L1__c, L2__c, L2_REF__c, L3_REF__c FROM Sync_Data__c WHERE Id =: wrapper.syncDataId LIMIT 1];
        if(String.isNotBlank(wrapper.syncDataItemId) && wrapper.syncDataItemId != 'null') {
            Sync_Data_Item__c tempsdItem = [SELECT Id, Child_Fetched__c FROM Sync_Data_Item__c WHERE Id =: wrapper.syncDataItemId];
            tempsdItem.Child_Fetched__c = true;
            update tempsdItem;
        }
        //List<Sync_Data_Item__c> syncDataItems = new List<Sync_Data_Item__c>([SELECT Id, Name, RecordId__c FROM Sync_Data_Item__c WHERE Level__c = 'l1' AND Child_Fetched__c = false limit 1]);
        List<Sync_Data_Item__c> syncDataItems = new List<Sync_Data_Item__c>(
            [SELECT Id, Name, RecordId__c, Level__c FROM Sync_Data_Item__c WHERE Child_Fetched__c = false ORDER BY Level__c ASC LIMIT 1]
        );
        if(!syncDataItems.isEmpty()) {
            wrapper.syncDataItemId = syncDataItems[0].Id;
            wrapper.offset = 0;
            wrapper.step = syncDataItems[0].Level__c;
            String nextObject = getNextObject(wrapper.step, syncData);
            String nextObjectRef = getNextObjectReference(wrapper.step, syncData);
            wrapper.filter = ' WHERE ' + nextObjectRef + ' IN ' +syncDataItems[0].RecordId__c;
            System.debug('inside checkAndProcessNextObject nextObject **** : '+nextObject);
            //String nextStep = nextStep('l1');
            String nextStep = nextStep(syncDataItems[0].Level__c);
            //wrapper.objectName = 'Contact';
            wrapper.objectName = nextObject;
            wrapper.step = nextStep;
            if(String.isNotBlank(nextObject) && String.isNotBlank(nextObjectRef)) {
                result = JSON.serialize(new ProcessedResult(wrapper));
            }else {
                result = JSON.serialize(new ProcessedResult(true));
            }
        }else {
            String nextObject = getNextObject(wrapper.step, syncData);
            String nextObjectRef = getNextObjectReference(wrapper.step, syncData);
            if(String.isBlank(nextObject) || String.isBlank(nextObjectRef)) {
                result = JSON.serialize(new ProcessedResult(true));
            }else {
                result = requestMore(nextObject, wrapper, nextObjectRef);
            }
        }
        return result;
    }

    private static void createSyncDataItem(SyncDataWrapper wrapper, String data) {
        Sync_Data_Item__c sdItem = new Sync_Data_Item__c(
            Sync_Data__c = wrapper.syncDataId,
            Level__c = wrapper.step,
            RecordId__c = storeRecordId(data),
            Data__c = JSON.serialize(wrapper.data)
        );
        if(String.isNotBlank(wrapper.syncDataItemId) && wrapper.syncDataItemId != 'null') {
            sdItem.Child_Record__c = wrapper.syncDataItemId;
        }
        insert sdItem;
    }

    private static List<Sync_Data_Item__c> getSyncDataItems(SyncDataWrapper wrapper) {
        List<Sync_Data_Item__c> sdItems = new List<Sync_Data_Item__c>();
        String query = 'SELECT Id, Name, RecordId__c FROM Sync_Data_Item__c ';
        if(String.isNotBlank(wrapper.syncDataItemId) && wrapper.syncDataItemId != 'null') {
            query += ' WHERE Id = \''+ wrapper.syncDataItemId+'\'';
            query += ' AND Child_Fetched__c = false LIMIT 1 ';
        }else {
            query += ' WHERE Sync_Data__c = \''+ wrapper.syncDataId+'\'';
        }
        return (List<Sync_Data_Item__c>) Database.query(query);
    }

    private static string fetchMoreRecord(SyncDataWrapper wrapper) {
        String syncDataId = wrapper.syncDataId;
        String step = wrapper.step;
        List<Sync_Data_Item__c> noOfLineItems = new List<Sync_Data_Item__c>();
        if(String.isNotBlank(wrapper.syncDataItemId) && wrapper.syncDataItemId != 'null') {
            noOfLineItems = [SELECT Id FROM Sync_Data_Item__c WHERE Child_Record__c =:  wrapper.syncDataItemId];
        }else {
            noOfLineItems = new List<Sync_Data_Item__c>([
                SELECT Id FROM Sync_Data_Item__c WHERE Sync_Data__c =: syncDataId AND Level__c =: step
            ]);
        }
        
        Integer offsetSize =  OFFSET_SIZE * noOfLineItems.size();
        wrapper.offset = offsetSize;
        ProcessedResult pr = new ProcessedResult(wrapper);
        return JSON.serialize(pr);
    }

    public static String processResponse(String data) {
        System.debug('data**** : '+JSON.serialize(data));
        if(data.contains('Error')) {
            return JSON.serialize(new ProcessedResult(true, data));
        }
        String result;
        SyncDataWrapper wrapper = (SyncDataWrapper)JSON.deserialize(data, SyncDataWrapper.class);
        syncDataRef = wrapper.syncDataId;
        System.debug('wrapper***** : '+JSON.serialize(wrapper));
        if(wrapper.data.isEmpty()) {
            result = checkAndProcessNextObject(wrapper);
        }else {
            createSyncDataItem(wrapper, data);
            result = fetchMoreRecord(wrapper);
        }
        
        return result;
    }

    private static String storeRecordId(String data) {
        Map<String, Object> payload =
            (Map<String, Object>) JSON.deserializeUntyped(data);
        List<Object> records = (List<Object>) payload.get('data');
        List<String> recordIds = new List<String>();
        for(Object o : records) {
            Map<String, Object> rec = (Map<String, Object>) o;
            String recordId = (String) rec.get('Id');
            recordIds.add(recordId);
        }

        return JSON.serialize(recordIds);
    }

    private static void createRecords(String data) {
        Map<String, Object> payload =
            (Map<String, Object>) JSON.deserializeUntyped(data);

        List<Object> records = (List<Object>) payload.get('data');
        List<Account> accounts = new List<Account>();
        for(Object o : records) {
            Map<String, Object> rec = (Map<String, Object>) o;
            Account a = new Account();
            a.Name = (String) rec.get('Name');
            a.Rating = (String) rec.get('Rating');
            a.Industry = (String) rec.get('Industry');
            accounts.add(a);
        }
        insert accounts;
    }

    public class SyncDataWrapper {
        public String objectName;
        public List<sObject> data;
        public String step;
        public String syncDataId;
        public String syncDataItemId;
        public Integer offset;
        public String filter;
        public boolean stop;
        public SyncDataWrapper() {}
    }

    public class ProcessedResult {
        public String objectName;
        public Integer offset;
        public String step;
        public String filter;
        public boolean stop;
        public String syncDataId;
        public String syncDataItemId;
        public String errorMessage;
        public ProcessedResult() { }
        public ProcessedResult(Boolean stop) {
            this.stop = stop;
            this.syncDataId = syncDataRef;
        }
        public ProcessedResult(Boolean stop, String errorMessage) {
            this.stop = stop;
            this.syncDataId = syncDataRef;
            this.errorMessage = errorMessage;
        }

        public ProcessedResult(String objectName, Integer offset, String step, String filter, String syncDataId, String syncDataItemId) {
            this.objectName = objectName;
            this.offset = offset;
            this.step = step;
            this.filter = filter;
            this.syncDataId = syncDataId;
            this.syncDataItemId = syncDataItemId;
            this.stop = false;
        }

        public ProcessedResult(SyncDataWrapper wrapper) {
            this.objectName = wrapper.objectName;
            this.offset = wrapper.offset;
            this.step = wrapper.step;
            this.filter = wrapper.filter;
            this.stop = wrapper.stop == null ? false : wrapper.stop;
            this.syncDataId = wrapper.syncDataId;
            this.syncDataItemId = wrapper.syncDataItemId;
        }
    }
}