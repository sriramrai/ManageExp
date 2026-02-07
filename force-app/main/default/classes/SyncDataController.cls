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

    @AuraEnabled
    public static List<Map<String,String>> getAvailableObjects() {
        List<Map<String,String>> objects = new List<Map<String,String>>();
        Map<String, Schema.SObjectType> results = Schema.getGlobalDescribe();
        for(Schema.SObjectType res : results.values()) {
            String name = res.getDescribe().getName();
            if(name.endsWith('__c') && !name.startsWith('Sync_Data')) {
                Map<String,String> obj = new Map<String,String>();
                obj.put('label', res.getDescribe().getLabel());
                obj.put('value', name);
                objects.add(obj);
            }
        }
        return objects;
    }

    @AuraEnabled
    public static List<Map<String,String>> getFieldsForObject(String objectName) {
        List<Map<String,String>> fields = new List<Map<String,String>>();
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
        if(targetType == null) {
            return fields;
        }
        
        Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
        for(Schema.SObjectField field : fieldMap.values()) {
            Schema.DescribeFieldResult describe = field.getDescribe();
            if(describe.isAccessible() && 
               describe.isUpdateable() && 
               describe.isCreateable() &&
               !describe.getName().endsWith('__r')) {
                Map<String,String> fld = new Map<String,String>();
                fld.put('label', describe.getLabel());
                fld.put('value', describe.getName());
                fields.add(fld);
            }
        }
        return fields;
    }

    @AuraEnabled
    public static List<Map<String,String>> getChildObjects(String parentObjectName) {
        List<Map<String,String>> childObjects = new List<Map<String,String>>();
        
        // Validate parent object
        Schema.SObjectType parentType = Schema.getGlobalDescribe().get(parentObjectName);
        if(parentType == null) {
            System.debug('Parent object not found: ' + parentObjectName);
            return childObjects;
        }
        
        // Get all objects in the org to find which ones reference our parent object
        Map<String, Schema.SObjectType> allObjects = Schema.getGlobalDescribe();
        System.debug('Checking all objects for references to parent: ' + parentObjectName);
        Integer totalObjectsChecked = 0;
        Integer childObjectsFound = 0;
        
        // Iterate through all objects in the org
        for(Schema.SObjectType objectType : allObjects.values()) {
            String objectName = objectType.getDescribe().getName();
            totalObjectsChecked++;
            
            // Skip the parent object itself and non-custom objects
            if(objectName == parentObjectName || !objectName.endsWith('__c')) {
                continue;
            }
            
            // Get all fields for this object
            Map<String, Schema.SObjectField> fieldMap = objectType.getDescribe().fields.getMap();
            System.debug('Examining fields for child object: ' + objectName + ' - Total fields: ' + fieldMap.size());
            
            // Look for relationship fields that reference the parent object
            for(Schema.SObjectField field : fieldMap.values()) {
                Schema.DescribeFieldResult describe = field.getDescribe();
                
                // Check if this field references our parent object by examining reference types
                try {
                    List<Schema.SObjectType> referenceTypes = describe.getReferenceTo();
                    System.debug('Checking field ' + describe.getName() + ' for references to ' + parentObjectName);
                    System.debug('Reference types count for ' + describe.getName() + ': ' + (referenceTypes != null ? referenceTypes.size() : 0));
                    
                    if(referenceTypes != null && !referenceTypes.isEmpty()) {
                        for(Schema.SObjectType referenceType : referenceTypes) {
                            String referencedObjectName = referenceType.getDescribe().getName();
                            System.debug('Reference type check: ' + referencedObjectName + ' == ' + parentObjectName + '? ' + (referencedObjectName == parentObjectName));
                                if(referencedObjectName == parentObjectName) {
                                    // This is a child object of our parent
                                    Map<String,String> obj = new Map<String,String>();
                                    // Get the child object's label instead of the relationship field's label
                                    Schema.SObjectType childType = Schema.getGlobalDescribe().get(objectName);
                                    if(childType != null) {
                                        obj.put('label', childType.getDescribe().getLabel());
                                    } else {
                                        obj.put('label', objectName);
                                    }
                                    obj.put('value', objectName);
                                    childObjects.add(obj);
                                    childObjectsFound++;
                                    System.debug('Found child object: ' + objectName + ' referencing parent ' + parentObjectName + ' via field ' + describe.getName());
                                    break; // Found a match, no need to check other reference types
                                }
                        }
                    } else {
                        System.debug('No reference types found for field ' + describe.getName());
                    }
                } catch(Exception e) {
                    System.debug('Error processing reference types for field ' + describe.getName() + ': ' + e.getMessage());
                }
            }
        }
        
        System.debug('Total objects checked: ' + totalObjectsChecked);
        System.debug('Child objects found: ' + childObjectsFound);
        System.debug('Returning child objects count: ' + childObjects.size());
        return childObjects;
    }

    @AuraEnabled
    public static List<Map<String,String>> getReferenceFields(String objectName) {
        // Return reference (lookup/master-detail) fields on the given object.
        // IMPORTANT: We must return the foreign key API name (ends with __c), not the relationship name (__r),
        // because this value is later used directly in SOQL filters like "WHERE <field> IN (...)"
        List<Map<String,String>> fields = new List<Map<String,String>>();
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
        if (targetType == null) {
            return fields;
        }
        Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
        for (Schema.SObjectField fldRef : fieldMap.values()) {
            Schema.DescribeFieldResult dfr = fldRef.getDescribe();
            if (dfr.isAccessible() && dfr.getType() == Schema.DisplayType.Reference) {
                Map<String, String> entry = new Map<String, String>();
                entry.put('label', dfr.getLabel());
                entry.put('value', dfr.getName()); // e.g., Expense__c
                fields.add(entry);
            }
        }
        return fields;
    }

    @AuraEnabled
    public static List<Map<String,String>> getRelationshipFields(String parentObjectName, String childObjectName) {
        // Return only those reference fields (foreign keys, ending with __c) on child that reference the parent object
        List<Map<String,String>> fields = new List<Map<String,String>>();
        Schema.SObjectType childType = Schema.getGlobalDescribe().get(childObjectName);
        if (childType == null) {
            return fields;
        }
        Map<String, Schema.SObjectField> fieldMap = childType.getDescribe().fields.getMap();
        for (Schema.SObjectField fldRef : fieldMap.values()) {
            Schema.DescribeFieldResult dfr = fldRef.getDescribe();
            if (dfr.isAccessible() && dfr.getType() == Schema.DisplayType.Reference) {
                try {
                    List<Schema.SObjectType> refs = dfr.getReferenceTo();
                    if (refs != null) {
                        for (Schema.SObjectType t : refs) {
                            if (t != null && t.getDescribe().getName() == parentObjectName) {
                                Map<String, String> entry = new Map<String, String>();
                                entry.put('label', dfr.getLabel());
                                entry.put('value', dfr.getName()); // e.g., Expense__c
                                fields.add(entry);
                                break;
                            }
                        }
                    }
                } catch (Exception e) {
                    System.debug('Error processing reference types for field ' + dfr.getName() + ': ' + e.getMessage());
                }
            }
        }
        return fields;
    }

    @AuraEnabled
    public static String createSyncDataRecord(
        String l1Object,
        String l2Object,
        String l3Object,
        String l2RefField,
        String l3RefField,
        Date dateFilter
    ) {
        try {
            Sync_Data__c sdata = new Sync_Data__c();
            sdata.L1__c = l1Object;
            sdata.L2__c = l2Object;
            sdata.L3__c = l3Object;
            sdata.L2_REF__c = l2RefField;
            sdata.L3_REF__c = l3RefField;
            if (dateFilter != null) {
                sdata.Date_Filter__c = dateFilter;
            }
            // Set status to Not Started as requested
            if (Schema.sObjectType.Sync_Data__c.fields.Status__c != null) {
                sdata.Status__c = 'Not Started';
            }
            insert sdata;
            return sdata.Id;
        } catch(Exception e) {
            System.debug('Error creating Sync Data record: ' + e.getMessage());
            throw new AuraHandledException('Failed to create Sync Data record: ' + e.getMessage());
        }
    }

    private static String nextStep(String step) {
        // Advance step by one; support up to l3 (returns null after l3)
        if (String.isBlank(step) || !step.startsWith('l')) {
            return null;
        }
        Integer currNum = Integer.valueOf(step.substring(1));
        Integer nextNum = currNum + 1;
        // Allow l1 -> l2, l2 -> l3, and stop after l3
        if (nextNum > 3) {
            return null;
        }
        return 'l' + String.valueOf(nextNum);
    }

    @AuraEnabled
    public static void syncData(String syncDataId) {
        if (syncDataId == null || syncDataId == '') {
            throw new AuraHandledException('Invalid Sync Data ID provided');
        }
        
        // Retrieve the Sync_Data__c record to get all the configuration values
        Sync_Data__c syncData = [SELECT Id, L1__c, L2__c, L3__c, L2_REF__c, L3_REF__c, Date_Filter__c, Status__c 
                                 FROM Sync_Data__c 
                                 WHERE Id = :syncDataId 
                                 LIMIT 1];
        
        if (syncData == null) {
            throw new AuraHandledException('Sync Data record not found');
        }
        
        // Set status to "In Progress" before starting
        syncData.Status__c = 'In Progress';
        update syncData;
        
        // Start the batch process using the retrieved configuration values
        String objectName = syncData.L1__c;
        Integer offset = 0;
        String step = 'l1';
        String filter = null;
        String syncDataItemId = null;
        
        // Execute the batch using the values from the Sync_Data__c record
        Database.executeBatch(new SyncDataQueueable(objectName, offset, step, filter, syncDataId, syncDataItemId), 1);
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
        // Use the actual current wrapper.step (e.g., l1 or l2), not hardcoded
        String currentStep = wrapper.step;
        String syncDataId = wrapper.syncDataId;
        List<Sync_Data_Item__c> sdItems = new List<Sync_Data_Item__c>([
            SELECT Id, RecordId__c
            FROM Sync_Data_Item__c
            WHERE Sync_Data__c = :syncDataId
            AND Level__c = :currentStep
            AND Child_Fetched__c = false
            LIMIT 1
        ]);
        System.debug('sdItems**** : ' + sdItems);
        System.debug('currentStep*** : ' + currentStep);
        System.debug('syncDataId*** : ' + syncDataId);
        if (sdItems.isEmpty()) {
            return checkAndProcessNextObject(wrapper);
        } else {
            String nextStepVal = nextStep(wrapper.step);
            wrapper.syncDataItemId = sdItems[0].Id;
            wrapper.filter = ' WHERE ' + objectRef + ' IN ' + sdItems[0].RecordId__c;
            wrapper.offset = 0;
            wrapper.step = nextStepVal;
            wrapper.objectName = objectName;
        }

        return JSON.serialize(new ProcessedResult(wrapper));
    }

    private static List<Sync_Data_Item__c> getSyncDataItem(){
        return null;
    }

    private static String checkAndProcessNextObject(SyncDataWrapper wrapper) {
        String result;
        Sync_Data__c syncData = [SELECT Id, Name, L1__c, L2__c, L3__c, L2_REF__c, L3_REF__c FROM Sync_Data__c WHERE Id =: wrapper.syncDataId LIMIT 1];
        if(String.isNotBlank(wrapper.syncDataItemId) && wrapper.syncDataItemId != 'null') {
            Sync_Data_Item__c tempsdItem = [SELECT Id, Child_Fetched__c FROM Sync_Data_Item__c WHERE Id =: wrapper.syncDataItemId];
            tempsdItem.Child_Fetched__c = true;
            update tempsdItem;
        }
        //List<Sync_Data_Item__c> syncDataItems = new List<Sync_Data_Item__c>([SELECT Id, Name, RecordId__c FROM Sync_Data_Item__c WHERE Level__c = 'l1' AND Child_Fetched__c = false limit 1]);
        List<Sync_Data_Item__c> syncDataItems = new List<Sync_Data_Item__c>(
            [
                SELECT Id, Name, RecordId__c, Level__c
                FROM Sync_Data_Item__c
                WHERE Child_Fetched__c = false
                AND Sync_Data__c = :wrapper.syncDataId
                ORDER BY Level__c ASC
                LIMIT 1
            ]
        );
        if(!syncDataItems.isEmpty()) {
            wrapper.syncDataItemId = syncDataItems[0].Id;
            wrapper.offset = 0;
            wrapper.step = syncDataItems[0].Level__c;
            // We have a pending parent item at level l1 or l2; fetch its children next
            String parentLevel = syncDataItems[0].Level__c; // e.g., l1 -> next children at l2; l2 -> next children at l3
            String nextObject = getNextObject(parentLevel, syncData);
            String nextObjectRef = getNextObjectReference(parentLevel, syncData);
            wrapper.filter = ' WHERE ' + nextObjectRef + ' IN ' + syncDataItems[0].RecordId__c;
            System.debug('inside checkAndProcessNextObject nextObject **** : ' + nextObject);
            String nextStepVal = nextStep(parentLevel);
            wrapper.objectName = nextObject;
            wrapper.step = nextStepVal;
            if (String.isNotBlank(nextObject) && String.isNotBlank(nextObjectRef)) {
                result = JSON.serialize(new ProcessedResult(wrapper));
            } else {
                result = JSON.serialize(new ProcessedResult(true));
            }
        } else {
            // No pending items found for this syncData; use the current wrapper.step context
            String nextObject = getNextObject(wrapper.step, syncData);
            String nextObjectRef = getNextObjectReference(wrapper.step, syncData);
            if (String.isBlank(nextObject) || String.isBlank(nextObjectRef)) {
                result = JSON.serialize(new ProcessedResult(true));
            } else {
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
