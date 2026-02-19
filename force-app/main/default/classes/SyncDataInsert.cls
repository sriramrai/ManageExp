public with sharing class SyncDataInsert implements DataBase.Batchable <sObject> {
    public Sync_Data_Item__c syncDataItem;
    private String syncDataItemId;
    
    public SyncDataInsert() {
        this.syncDataItemId = null;
    }
    
    public SyncDataInsert(String syncDataItemId) {
        this.syncDataItemId = syncDataItemId;
    }

    public List<sObject> start(Database.BatchableContext BC) {
        String queryStr = 'SELECT Id, Name, Data__c, Level__c, Inserted_Records__c,';
        queryStr += ' Sync_Data__r.L1__c, Sync_Data__r.L2__c, Sync_Data__r.L3__c, Sync_Data__r.L2_REF__c, Sync_Data__r.L3_REF__c,';
        queryStr += ' Child_Record__r.Inserted_Records__c';
        queryStr += ' FROM Sync_Data_Item__c ';
        
        if (String.isNotBlank(syncDataItemId)) {
            queryStr += ' WHERE Id = \'' + String.escapeSingleQuotes(syncDataItemId) + '\'';
        } else {
            // Query for records that have data but haven't been processed yet
            queryStr += ' WHERE Data__c != null AND (Inserted_Records__c = null OR Inserted_Records__c = \'\')';
        }
        
        try {
            return Database.query(queryStr);
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
        
        syncDataItem = scope[0];
        
        if (String.isBlank(syncDataItem.Data__c)) {
            System.debug('Data__c is blank for Sync_Data_Item__c: ' + syncDataItem.Id);
            return;
        }
        
        ObjectInfo objInfo = getObjectInfo(syncDataItem); 
        String objectName = objInfo.objectName;
        
        if (String.isBlank(objectName)) {
            System.debug('Object name is blank for Sync_Data_Item__c: ' + syncDataItem.Id);
            return;
        }
        
        try {
            List<Object> rawList = (List<Object>) JSON.deserializeUntyped(syncDataItem.Data__c);
            
            if (rawList == null || rawList.isEmpty()) {
                System.debug('No data to process for Sync_Data_Item__c: ' + syncDataItem.Id);
                return;
            }
            
            Schema.SObjectType targetType = Schema.getGlobalDescribe().get(objectName);
            if (targetType == null) {
                System.debug('Invalid object name: ' + objectName);
                return;
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
                        newRecord.put('Name', 'BT' + String.valueOf(fieldValue));
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
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('SyncDataInsert batch job completed. Job ID: ' + BC.getJobId());
    }

    private String getNewRecordId(String oldRecordId) {
        if (String.isBlank(oldRecordId)) {
            return null;
        }
        
        sObject parent = syncDataItem.getSObject('Child_Record__r');
        if (parent == null || parent.get('Inserted_Records__c') == null) {
            System.debug('Child_Record__r or Inserted_Records__c is null');
            return null;
        }
        
        try {
            String insertedRecordsJson = (String)parent.get('Inserted_Records__c');
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
        String fieldName = (String) parent.get(sd.Level__c + '_REF__c');
        
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
