public with sharing class SyncDataInsertClone implements DataBase.Batchable <sObject> {
    // Testing switch: org-default Hierarchy Custom Setting Testing_Switch__c.Test_Mode__c
    // Cache within transaction to avoid repeated describe/access
    private static Boolean TEST_MODE_CACHE;
    public Sync_Data_Item__c syncDataItem;
    private String syncDataId;
    
    public SyncDataInsertClone() {
        this.syncDataId = null;
    }
    
    public SyncDataInsertClone(String syncDataId) {
        this.syncDataId = syncDataId;
    }

    public List<sObject> start(Database.BatchableContext BC) {
        if (String.isBlank(syncDataId)) {
            System.debug('Sync_Data__c ID is required');
            return new List<Sync_Data_Item__c>();
        }
        
        String queryStr = 'SELECT Id, Name, Data__c, Level__c, Inserted_Records__c,';
        queryStr += ' Sync_Data__r.L1__c, Sync_Data__r.L2__c, Sync_Data__r.L3__c, Sync_Data__r.L2_REF__c, Sync_Data__r.L3_REF__c,';
        queryStr += ' Child_Record__r.Inserted_Records__c, Child_Record__r.Level__c';
        queryStr += ' FROM Sync_Data_Item__c ';
        queryStr += ' WHERE Sync_Data__c = \'' + String.escapeSingleQuotes(syncDataId) + '\'';
        // Order by Level__c to ensure l1 is processed before l2, l2 before l3
        // Since 'l1' < 'l2' < 'l3' lexicographically, simple ORDER BY works
        queryStr += ' ORDER BY Level__c ASC';
        
        try {
            List<Sync_Data_Item__c> allItems = Database.query(queryStr);
            // Filter in Apex code since LongTextArea fields can't be filtered in SOQL
            return filterUnprocessedItems(allItems);
        } catch (Exception e) {
            System.debug('Error in start method: ' + e.getMessage());
            return new List<Sync_Data_Item__c>();
        }
    }

    public void execute(Database.BatchableContext BC, List<Sync_Data_Item__c> scope) {
        if (scope == null || scope.isEmpty()) {
            System.debug('Scope is empty or null');
            return;
        }
        
        // Process each Sync_Data_Item__c in the scope
        for (Sync_Data_Item__c currentItem : scope) {
            syncDataItem = currentItem;
            
            if (String.isBlank(syncDataItem.Data__c)) {
                System.debug('Data__c is blank for Sync_Data_Item__c: ' + syncDataItem.Id);
                continue;
            }
            
            // Check if this item has already been processed
            if (String.isNotBlank(syncDataItem.Inserted_Records__c)) {
                System.debug('Sync_Data_Item__c already processed: ' + syncDataItem.Id);
                continue;
            }
            
            // For l2 and l3, verify that the parent level has been processed
            if (syncDataItem.Level__c == 'l2' || syncDataItem.Level__c == 'l3') {
                if (!isParentLevelProcessed(syncDataItem)) {
                    System.debug('Parent level not yet processed for Sync_Data_Item__c: ' + syncDataItem.Id + ', Level: ' + syncDataItem.Level__c);
                    continue;
                }
            }
            
            ObjectInfo objInfo = getObjectInfo(syncDataItem); 
            String objectName = objInfo.objectName;
            
            if (String.isBlank(objectName)) {
                System.debug('Object name is blank for Sync_Data_Item__c: ' + syncDataItem.Id);
                continue;
            }
            
            try {
                List<Object> rawList = (List<Object>) JSON.deserializeUntyped(syncDataItem.Data__c);
                
                if (rawList == null || rawList.isEmpty()) {
                    System.debug('No data to process for Sync_Data_Item__c: ' + syncDataItem.Id);
                    continue;
                }
                
                Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
                if (targetType == null) {
                    System.debug('Invalid object name: ' + objectName);
                    continue;
                }
                
                Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
                Map<String, sObject> recordMapToBeInserted = new Map<String, sObject>();
                
                for(Object obj : rawList) {
                    if (obj == null) {
                        continue;
                    }
                    
                    Map<String, Object> row = (Map<String, Object>) obj;
                    SObject newRecord = targetType.newSObject();
                    String recordId;
                    
                    for (String field : row.keySet()) {
                        if(!fieldMap.containsKey(field)) {
                            continue;
                        }
                        
                        Object fieldValue = row.get(field);
                        if (fieldValue == null) {
                            continue;
                        }
                        
                        if (field == 'Name') {
                            newRecord.put('Name', String.valueOf(fieldValue));
                        } else if(field == 'Id') {
                            recordId = (String)fieldValue;
                        } else if(String.isNotBlank(objInfo.parentReference) && field.equalsIgnoreCase(objInfo.parentReference)) {
                            System.debug('objInfo*** : '+objInfo);
                            System.debug('fieldvalue*** : '+(String)fieldValue);
                            String newRecordId = getNewRecordId((String)fieldValue);
                            if (String.isNotBlank(newRecordId)) {
                                newRecord.put(field, newRecordId);
                            }
                        } else {
                            newRecord.put(field, fieldValue);
                        }
                    }
                    
                    if (String.isNotBlank(recordId)) {
                        recordMapToBeInserted.put(recordId, newRecord);
                    }
                }
                
                if (!recordMapToBeInserted.isEmpty()) {
                    insert recordMapToBeInserted.values();
                    System.debug('Map**** : '+JSON.serialize(recordMapToBeInserted));
                    storeInsertedRecord(syncDataItem, recordMapToBeInserted);
                }
            } catch (Exception e) {
                System.debug('Error in execute method for Sync_Data_Item__c ' + syncDataItem.Id + ': ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                Sync_Data__c syncData = new Sync_Data__c(Id = syncDataId, Status__c = 'Error');
                syncData.Error_Message__c = String.isNotBlank(syncData.Error_Message__c) ? syncData.Error_Message__c + '\n' + 'Error while inserting records: ' + e.getMessage() : 'Error while inserting records: ' + e.getMessage();
                update syncData;
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('SyncDataInsertClone batch job completed. Job ID: ' + BC.getJobId());
        
        // Check if there are any remaining unprocessed items and requeue if needed
        if (String.isNotBlank(syncDataId)) {
            List<Sync_Data_Item__c> remainingItems = [
                SELECT Id, Level__c, Data__c, Inserted_Records__c
                FROM Sync_Data_Item__c 
                WHERE Sync_Data__c = :syncDataId 
                LIMIT 1
            ];
            
            // Filter in Apex code since LongTextArea fields can't be filtered in SOQL
            remainingItems = filterUnprocessedItems(remainingItems);
            if (!remainingItems.isEmpty()) {
                // Testing switch check: only enqueue next batch when Test_Mode__c is true
                if (isTestingSwitchEnabled()) {
                    System.debug('Requeuing batch for remaining items. Sync_Data__c: ' + syncDataId);
                    Database.executeBatch(new SyncDataInsertClone(syncDataId), 200);
                } else {
                    System.debug('Testing_Switch__c.Test_Mode__c is false (org-default). Skipping next batch enqueue for Sync_Data__c: ' + syncDataId);
                }
            } else {
                System.debug('All Sync_Data_Item__c records processed for Sync_Data__c: ' + syncDataId);
            }
        }
    }

    private Boolean isParentLevelProcessed(Sync_Data_Item__c currentItem) {
        if (currentItem.Level__c == 'l1') {
            return true; // l1 has no parent
        }
        
        // For l2, check if l1 items are processed
        if (currentItem.Level__c == 'l2') {
            List<Sync_Data_Item__c> l1Items = [
                SELECT Id, Inserted_Records__c, Data__c
                FROM Sync_Data_Item__c 
                WHERE Sync_Data__c = :currentItem.Sync_Data__c 
                AND Level__c = 'l1'
                LIMIT 1
            ];
            
            // Filter in Apex code
            l1Items = filterItemsWithData(l1Items);
            
            if (l1Items.isEmpty()) {
                return true; // No l1 items to process
            }
            
            // Check if at least one l1 item is processed
            for (Sync_Data_Item__c l1Item : l1Items) {
                if (String.isNotBlank(l1Item.Inserted_Records__c)) {
                    return true;
                }
            }
            
            // Check all l1 items
            List<Sync_Data_Item__c> allL1Items = [
                SELECT Id, Data__c, Inserted_Records__c
                FROM Sync_Data_Item__c 
                WHERE Sync_Data__c = :currentItem.Sync_Data__c 
                AND Level__c = 'l1'
            ];
            
            List<Sync_Data_Item__c> l1ItemsWithData = filterItemsWithData(allL1Items);
            Integer totalL1Items = l1ItemsWithData.size();
            
            Integer processedL1Items = 0;
            for (Sync_Data_Item__c item : l1ItemsWithData) {
                if (String.isNotBlank(item.Inserted_Records__c)) {
                    processedL1Items++;
                }
            }
            
            return processedL1Items == totalL1Items && totalL1Items > 0;
        }
        
        // For l3, check if l2 items are processed
        if (currentItem.Level__c == 'l3') {
            List<Sync_Data_Item__c> allL2Items = [
                SELECT Id, Data__c, Inserted_Records__c
                FROM Sync_Data_Item__c 
                WHERE Sync_Data__c = :currentItem.Sync_Data__c 
                AND Level__c = 'l2'
            ];
            
            List<Sync_Data_Item__c> l2ItemsWithData = filterItemsWithData(allL2Items);
            Integer totalL2Items = l2ItemsWithData.size();
            
            Integer processedL2Items = 0;
            for (Sync_Data_Item__c item : l2ItemsWithData) {
                if (String.isNotBlank(item.Inserted_Records__c)) {
                    processedL2Items++;
                }
            }
            
            return processedL2Items == totalL2Items && totalL2Items > 0;
        }
        
        return true;
    }

    private String getNewRecordId(String oldRecordId) {
        if (String.isBlank(oldRecordId)) {
            return null;
        }
        
        // Find the child record (parent level) for this sync data item
        // For l2, child is l1; for l3, child is l2
        String parentLevel = getParentLevel(syncDataItem.Level__c);
        if (String.isBlank(parentLevel)) {
            return null;
        }
        
        // Query for the child Sync_Data_Item__c that has this oldRecordId in its Inserted_Records__c
        List<Sync_Data_Item__c> childItems = [
            SELECT Id, Inserted_Records__c 
            FROM Sync_Data_Item__c 
            WHERE Sync_Data__c = :syncDataItem.Sync_Data__c 
            AND Level__c = :parentLevel
            LIMIT 1
        ];
        
        // Filter in Apex code
        childItems = filterItemsWithInsertedRecords(childItems);
        
        if (childItems.isEmpty()) {
            System.debug('No child Sync_Data_Item__c found for Level: ' + parentLevel);
            return null;
        }
        
        Sync_Data_Item__c childItem = childItems[0];
        
        try {
            String insertedRecordsJson = childItem.Inserted_Records__c;
            if (String.isBlank(insertedRecordsJson)) {
                return null;
            }
            
            Map<String, String> insertedMap = (Map<String, String>) JSON.deserialize(
                insertedRecordsJson, 
                Map<String, String>.class
            );
            
            return insertedMap.get(oldRecordId);
        } catch (Exception e) {
            System.debug('Error in getNewRecordId: ' + e.getMessage());
            return null;
        }
    }
    
    private String getParentLevel(String currentLevel) {
        if (currentLevel == 'l2') {
            return 'l1';
        } else if (currentLevel == 'l3') {
            return 'l2';
        }
        return null;
    }
    
    private List<Sync_Data_Item__c> filterItemsWithData(List<Sync_Data_Item__c> items) {
        List<Sync_Data_Item__c> filtered = new List<Sync_Data_Item__c>();
        for (Sync_Data_Item__c item : items) {
            if (String.isNotBlank(item.Data__c)) {
                filtered.add(item);
            }
        }
        return filtered;
    }
    
    private List<Sync_Data_Item__c> filterItemsWithInsertedRecords(List<Sync_Data_Item__c> items) {
        List<Sync_Data_Item__c> filtered = new List<Sync_Data_Item__c>();
        for (Sync_Data_Item__c item : items) {
            if (String.isNotBlank(item.Inserted_Records__c)) {
                filtered.add(item);
            }
        }
        return filtered;
    }
    
    private List<Sync_Data_Item__c> filterUnprocessedItems(List<Sync_Data_Item__c> items) {
        List<Sync_Data_Item__c> filtered = new List<Sync_Data_Item__c>();
        for (Sync_Data_Item__c item : items) {
            if (String.isNotBlank(item.Data__c) && 
                (String.isBlank(item.Inserted_Records__c) || item.Inserted_Records__c == '')) {
                filtered.add(item);
            }
        }
        return filtered;
    }

    private ObjectInfo getObjectInfo(Sync_Data_Item__c sd) {
        if (sd == null || String.isBlank(sd.Level__c)) {
            return new ObjectInfo(null, null);
        }
        
        SObject parent = sd.getSObject('Sync_Data__r');
        if (parent == null) {
            return new ObjectInfo(null, null);
        }
        
        String objectFieldRef = sd.Level__c + '__c';
        String objectName = (String) parent.get(objectFieldRef);
        String fieldName = sd.Level__c.equalsIgnoreCase('l1') ? null : (String) parent.get(sd.Level__c + '_REF__c');
        
        return new ObjectInfo(objectName, fieldName);
    }

    private String getObjectName(Sync_Data_Item__c sd) {
        if (sd == null || String.isBlank(sd.Level__c)) {
            return null;
        }
        
        SObject parent = sd.getSObject('Sync_Data__r');
        if (parent == null) {
            return null;
        }
        
        String objectFieldRef = sd.Level__c + '__c';
        return (String) parent.get(objectFieldRef);
    }

    private List<String> allFieldsName(String objectName) {
        if (String.isBlank(objectName)) {
            return new List<String>();
        }
        
        List<String> fieldList = new List<String>();
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        
        if (objectType == null) {
            return fieldList;
        }
        
        for(Schema.SObjectField field : objectType.getDescribe().fields.getMap().values()) {
            if(field.getDescribe().isAccessible() && 
               field.getDescribe().isUpdateable() && 
               field.getDescribe().isCreateable()) {
                fieldList.add(field.getDescribe().getName());
            }
        }
        return fieldList;
    }

    private void storeInsertedRecord(Sync_Data_Item__c syncDataItem, Map<String, sObject> recordMap) {
        if (syncDataItem == null || recordMap == null || recordMap.isEmpty()) {
            return;
        }
        
        try {
            Map<String, String> recordVsOldId = new Map<String, String>();
            for(String recordId : recordMap.keySet()) {
                sObject record = recordMap.get(recordId);
                if (record != null && record.Id != null) {
                    recordVsOldId.put(recordId, record.Id);
                }
            }
            
            if (!recordVsOldId.isEmpty()) {
                syncDataItem.Inserted_Records__c = JSON.serialize(recordVsOldId);
                update syncDataItem;
            }
        } catch (Exception e) {
            System.debug('Error in storeInsertedRecord: ' + e.getMessage());
        }
    }

    // Reads Hierarchy Custom Setting org-default Testing_Switch__c.Test_Mode__c
    // Returns true if enabled, false otherwise. Caches result in TEST_MODE_CACHE.
    private static Boolean isTestingSwitchEnabled() {
        if (TEST_MODE_CACHE != null) {
            return TEST_MODE_CACHE;
        }
        try {
            // Get org-default (no user/role override) value
            Testing_Switch__c cs = Testing_Switch__c.getOrgDefaults();
            TEST_MODE_CACHE = (cs != null && cs.Test_Mode__c == true);
            return TEST_MODE_CACHE;
        } catch (Exception e) {
            // Fail safe: if custom setting not accessible or not defined, treat as disabled
            TEST_MODE_CACHE = false;
            return false;
        }
    }

    public class ObjectInfo {
        public String objectName;
        public String parentReference;
        
        public ObjectInfo() {
            this(null, null);
        }
        
        public ObjectInfo(String objectName, String parentReference) {
            this.objectName = objectName;
            this.parentReference = parentReference;
        }
    }
}
