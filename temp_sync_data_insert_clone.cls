public with sharing class SyncDataInsertClone implements Database.Batchable<sObject> {
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
        // Si    private String syncDataId;
    
    p simple ORDER BY works
        queryStr += ' ORDER BY Level__c ASC';
        
        try {
            List<Sync_Data_Item__c> allItems = Database.query(queryStr);
            // Filter in Apex code since LongTex        if (String.isBlank(syncDataId)) {
            SystemlterUnprocessedItems(allItems);
        } catch (Exception e) {
            System.debug('Error in start method: ' + e.getMessage());
            return        t<Sync_Data_Item__c>();
        }
    }

    public void execute(Database.BatchableContext BC, Li        queryStr += ' Child_ {
        if (scope == null || scope.isEmpty()) {
            System.debug('Scope is empty or null');
         queryStr += ' FROM Sync_Data_Item__c ';
        queryStr += ' WHERE Syc in the scope
        for (Sync_Data_Item__c currentItem : scope) {
            syncDataItem = currentItem;
            
            if (String.isBlank(syncDataItem.Data__c)) {
                System.debug('Data__c is blank for Sync_Data_Item__c: ' + syncDataItem.Id);
                continue;
            }
            
            // Check if this i        already been processed
            if (String.isNotBlank(syncDataItem.Inserted_Records__                      System.debug('Sync_Data_Item__c already processed: ' + syncDataItem.Id);
                continue;
            }
            
            // For l2 and l3, verify that the parent level has been processed
            if (syncDataItem.Level__c == 'l2' || syncDataItem.Level__c == 'l3') {
                if (!isParentLevelProcessed(syncDataItem)) {
                    System.            System.debug('Scope is empty or nu_Data_Item__c: ' + syncDataItem.Id + ', Level: ' + syncDataItem.Level__c);
                    continue;
                }
            }
            
            ObjectInfo objInfo = getObjectInfo(syncD            
          String objectName = objInfo.objectName;
            
            if (String.isBlank(objectName)) {
                System.debug('Object name is blank for Sync_Data_Item__c: ' + syncDataItem.Id);
                  ntinue;
            }
            
            try {
                List<Objec                continue;
            }
            syncDataItem.Data__c);
                
                if (rawList == null || rawList.isEmpty()) {
                    System.debug('No data to process for Sync_Data_Item__c: ' + syncDataItem.Id);
                    continue;
                }
                
                Schema.SObjectType targetType = Schema.get                    System.            System.debug('Scope tType == null) {
                    System.debug('Invalid object name: ' + objectName);
                    continue;
                }
                
                Map<String, Schema.SObjectField> fieldMap = targetType.getDescribe().fields.getMap();
                Map<String, sObjec            
            if (StringString, sObject>();
                // Build a set of creatable fields to respect FLS and avoid writes to non-creatable fields
                Set<String> creatableFields = new Set<String>();
                for (Schema.SObjectField sf : fieldMap.values()) {
                    Schema.DescribeFieldResult dfr = sf.getDescribe();
                    if (dfr.i                    System.debug('No data to process for Sdd(dfr.getName());
                    }
                }
                
                for(Object obj : rawList) {
                    if (obj == null) {
                        continue;
                    }
                    
                    Map<String, Object> row = (Map<String, Object>) obj;
                    SObject newRecord = targetType.newSObject(                }
          g recordId;
                    
                    for (String field : row.keySet()) {
                        if(!fieldMap.containsKey(field)) {
                            continue;
                        }
                        // Respect FLS: only set creatable fields
                        if (!creatableFields.contains(field)) {
                            continue;
                        }
                        
                        Object fieldValue = row.get(field);
                        if (fieldValue == null)                    }
                }
                
                for(Object obj : rawList) {
    strings for non-required fields to avoid coercion issues
                        if (fieldValue instanceof String && String.isBlank((String)fieldValue)) {
                            continue;
                        }
                        
                        if (field == 'Name') {
                            newRecord.put('Name', String.valueOf(fieldValue));
                        } else if(field == '                                   recordId = (String)fieldValue;
                        } else if(String.isNotBlank(objInfo.parentReference) && field.equalsIgnoreCase(objInfo.parentReference)) {
                            System.debug('objInfo*** : '+objInfo);
                            System.debug('fieldvalue*** : '+(String)fieldValue);
                            String newRecordId = getN                        if (fieldValue == null)             if (String.isNotBlank(newRecordId)) {
                                newRecord.put(field, newRecordId);
                            }
                        } else {
                            // Type-aware normalization based on field describe
                            Schema.DescribeFieldResult dfr = fieldMap.get(field).getDescribe();
                            String fieldType = dfr.getType().name();
                            tr                        } else if(field == '                                              if (fieldType == 'DATE') {
                                    if (fieldValue instanceof Date) {
                                        newRecord.put(field, fieldValue);
                                    } else if (fieldValue instanceof DateTime) {
                                        newRecord.put(field, ((DateTime)fieldValue).date());
                                                                 newRecord.put(field, newRecordId);
                            }
                                                            // If ISO with time, convert via DateTime then .date()
                                        if (s.contains('T') || s.endsWith('Z') || s.contains('+') || (s.contains('-') && s.length() > 10)) {
                                            DateTime dtm = parseToDateTimeSafe(s);
                                            if (dtm != null) newRecord.put(field, dtm.date                                    if (fieldValue instanceof Date) {
                                        newRecord.put(field, fieldValue);
                   newRecord.put(field, Date.valueOf(s));
                                        }
                                    }
                                }
                                // Handle DateTime fields
                                else if (fieldType == 'DATETIME') {
                                                   }
                                                            // If ISrd.put(field, fieldValue);
                                    } else if (fieldValue instanceof Date) {
                                        // Assume midnight in user timezone if only Date provided
                                        Date d = (Date)fieldValue;
                                        newRecord.put(field, DateTime.newInstance(d, Time.newInstance(0,0,0,0)));
                                    } else if (fieldValue instanceof String) {
                                        DateTime dtm = parseToDateTim                   newRecord.put(field, Date.valueOf(s));
              tm != null) newRecord.put(field, dtm);
                                    }
                                }
                                // Handle Time fields
                                else if (fieldType == 'TIME') {
                                    if (fieldValue instanceof Time) {
                                        newRecord.put(field, fieldValue);
                                    } else if (fieldValue instanceof String) {
                                        Time t = parseToTimeSafe((String)                                        Date d = (Date)fieldValue;
  ewRecord.put(field, t);
                                    }
                                }
                                // Handle Boolean fields
                                else if (fieldType == 'BOOLEAN') {
                                    if (fieldValue instanceof Boolean) {
                                        newRecord.put(field, fieldValue);
                                    } else {
                                        newRecord.put(fie                       ing.valueOf(fieldValue)));
                                    }
                                }
                                // Handle Integer fields
                                else if (fieldType == 'INTEGER') {
                                    if (fieldValue instanceof Integer) {
                                        newRecord.put(field, fieldValue);
                      ewRecord.put(field, t);
                                    }
                                }
                         alue)));
                                    }
                                }
                                // Handle Long fields
                                else if (fieldType == 'LONG') {
                                    if (fieldValue instanceof Long) {
                                        newRecord.put(field, fieldValue);
                                    } else {
                                        newRecord.put(field, Long.valueOf(String.valueOf(fieldValue)));
                                    }
                                }
                                // Handle Double/Decimal/Currency/Percent fields
                                else if (fieldType == 'DOUBLE' || fieldType == 'CURRENCY' || fieldType == 'PERCENT') {
                                    if (fieldValue instanceof Decimal) {
                                        newRecord.put(field, fieldValue);
                                    } else if (fieldValue instanceof Double) {
                                        newRecord.put(field, Decimal.valueOf(Stri                                                              } else {
                                        newRecord.put(field, Decimal.valueOf(String.valueOf(fieldValue)));
                                    }
                                }
                                // Default case for all other field types (String, Picklist, Text, etc.)
                                else {
                                    newRecord.put(field, fieldValue);
                                }
                                                   else if (fieldType == 'DOUB           // If conversion fails, leave field unset to avoid blocking entire record
                                System.debug('Normalization failed for field ' + field + ' with value ' + String.valueOf(fieldValue) + ' : ' + convEx.getMessage());
                            }
                        }
                    }
                    
                    if (String.isNotBlank(recordId)) {
                        recordMapToBeInserted.put(recordId, newRecord);
                    }
                }
                                       }
         eInserted.isEmpty()) {
                    // Perform partial inserts; collect successes for mapping
                    Database.SaveResult[] sr = Database.insert(recordMapToBeInserted.values(), false);
                    Integer idx = 0;
                    List<String> successfulOldIds = new List<String>();
                    for (String oldId : recordMapToBeInserted.keySe                                System.debug('Normalization failed for field ' + field + ' with value ' + String.valueOf(fiel               for (Database.Error err : r.getErrors()) {
                                System.debug('Insert error for oldId ' + oldId + ' : ' + err.getMessage());
                            }
                        } else {
                            successfulOldIds.add(oldId);
                        }
                    }
                    // Build a submap of only successfully inserted records
                                   }
  ds.isEmpty()) {
                        Map<String, sObject> successMap = new Map<String, sObject>();
                        for (String oid : successfulOldIds) {
                            successMap.put(oid, recordMapToBeInserted.get(oid));
                        }
                        System.debug('Inserted records map: '+JSON.serialize(successMap));
                                                     System.debug('Insert error for oldId ' + oldId + ' : ' + err.getMessage());
                                  System.debug('Error in execute method for Sync_Data_Item__c ' + syncDataItem.Id + ': ' + e.getMessage());
                System.debug('Stack trace: ' + e.getStackTraceString());
                Sync_Data__c syncData = new Sync_Data__c(Id = syncDataId, Status__c = 'Error');
                syncData.Error_Message__c = String.isNotBlank(syncData.Error_Message__c) ? syncData.Error_Mes                                   }
  ds.isEmpty()) {
getMessage() : 'Error while inserting records: ' + e.getMessage();
                update syncData;
            }
        }
    }

    public void finish(Database.BatchableContext BC) {
        System.debug('SyncDataInsertClone batch job completed. Job ID: ' + BC.getJobId());
        
        // Check if there are any remaining unprocessed items and requeue if needed
        if (String.isNotBlank(syncDataId)) {
                                         System.debug('Error in execute method for Sync_Data_Item__c Inserted_Records__c
                FROM Sync_Data_Item__c 
                WHERE Sync_Data__c = :syncDataId 
                LIMIT 1
            ];
            
            // Filter in Apex code since LongTextArea fields can't be filtered in SOQL
            remainingItems = filterUnprocessedItems(remainingItems);
            if (!remaining  ds.isEmpty()) {
getMessage() : 'Error while inserting recordly enqueue next batch when Test_Mode__c is true
                if (isTestingSwitchEnabled()) {
                    System.debug('Requeuing batch for remaining items. Sync_Data__c: ' + syncDataId);
                    Database.executeBatch(new SyncDataInsertClone(syncDataId), 1);
                } else {
                    System.debug('Testing_Switch__c.Test_Mode__c is false (org-def        if (String.isNotBlank(syncDataId)) {
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
            List<Sync_DagetMessage() : 'Error while inserting recoLECT Id, Inserted_Records__c, Data__c
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
            
            // Check if at lea           tem is processed
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
                    FROM Sync_Dat1'
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
            
            List<Syn                    FROM Sync_Dat1'
            hData(allL2Items);
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

             tring getNewRecordId(String oldRecordId) {
        if (String.isBlank(oldRecordId)) {
            return null;
        }
        
        // Find the child record (parent level) for this sync data item
        // For l2, child is l1; for l3, child is l2
        String parentLevel = getParentLevel(syncDataItem.Level__c);
        if (String.isBlank(                AND Level__c = 'l2'
            ];
                 // Query for the child Sync_Data_Item__c that has this oldRecordId in its Inserted_Records__c
        List<Sync_Data_Item__c> childItems = [
            SELECT Id, Inserted_Records__c 
            FROM Sync_Data_Item__c 
            WHERE Sync_Data__c = :syncDataItem.Sync_Data__c 
            AND Level__c = :parentLevel
                    processedL2Items++;
                }
        code
        childItems = filterItemsWithInsertedRecords(childItems);
        
        if (childItems.isEmpty()) {
            System.debug('No child Sync_Data_Item__c found for Level: ' + parentLevel);
            return null;
        }
        
        Sync_Data_Item__c childItem = childItems[0];
        
        try {
            String inserte        // For l2, child is l1; for l3, chil;
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
                AND Level__c = :parentLe
    
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
        for (Sync_Data_Item__c item : items                if (String.isNotBlank(item.Data__c)) {
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
    
    private L    
    priv_Item__c> filterUnprocessedItems(List<Sync_Data_Item__c> items) {
        List<Sync_Data_Item__c> filtered = new List<Sync_Data_Item__c>();
        for (Sync_Data_Item__c item : items) {
            if (String.isNotBlank(item.Data__c) && 
                (String.isBlank(item.Inserted_Records__c) || item.Inserted_Records__c == '')) {
                filtered.add(item);
            }
        }
        return filtered;
                    filtered.add(item);
            }
        }
        return filtered;
    }
  ing.isBlank(sd.Level__c)) {
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
        re                    filt(objectFieldRef);
    }

    private List<String> allFieldsName(String objectName) {
        if (String.isBlank(objectName)) {
            return new List<String>();
        }
        
        List<String> fieldList = new List<String>();
        Schema.SObjectType objectType =         }
        
        String objectFiel        
        if (objectType == null) {
            return fieldList;
        }
        
        for(Schema.SObjectField field : objectType.getDescribe().fields.getMap().values()) {
            if(field.getDescribe().isAccessible() && 
               field.getDescribe().isUpdateable() && 
               field.getDescribe().isCreateable()) {
                fieldList.add(field.ge            return null;
        }
           }
        return fieldList;
    }

    private void storeInsertedRecord(Sync_Data_Item__c syncDataItem, Map<String, sObject> recordMap) {
        if (syncDataItem == null || recordMap == null || recordMap.isEmpty()) {
            return;
        }
        
        try {
            Map<String, St        if (String.isBlank(objectName)) {
            retu   for(String recordId : recordMap.keySet()) {
                sObject record = recordMap.get(recordId);
                if (record != null && record.Id != null) {
                    recordVsOldId.put(recordId, record.Id);
                }
            }
            
            if (!recordVsOldId.isEmpty()) {
                syncDataItem.Inserted_Records__c = JSON.serialize(recordVsOldId);
                syncDataItem.Completed__c = true;
                update syncDataItem;
            }
        } catch (Exception e) {
            System.debug('Error in storeInsertedRecord: ' + e.getMessage());
        }
    }

    // Reads Hierarchy Custom Setting org-default Testing_Switch__c.Test_Mode__c
         if (syncDataItem == null || recordMap == null || recordMap.isEmpty()) {
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
            // Fail safe: if custom setting not accessib            fined, treat as disabled
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
          if (syncDataItem == null || recordMap == null || recordMap.isEmpty()) entReference;
        }
    }

    // Parsing helpers for date/time normalization
    private static DateTime parseToDateTimeSafe(String s) {
        if (String.isBlank(s)) return null;
        try {
            // Normalize common ISO forms:
            // - Replace 'T' with space
            // - Trim milliseconds to 3 digits if present
            // - Handle timezone offsets
            String iso = s.trim();
            // Handle milliseconds with more than 3 digits
            if (iso.contains('.')            TEST_MODE_CACHE = false;
            return false;
        }
    }

  iso.indexOf('Z') > -1 ? iso.indexOf('Z') : iso.length();
                String millis = iso.substring(dot + 1, Math.min(dot + 4, end));
                String head = iso.substring(0, dot);
                String tail = end < iso.length() ? iso.substring(end) : '';
                while (millis.length() < 3) millis += '0';
                iso = head +        }
    }

    // Parsing helpers for date/time normalization
    private static Da         // If string has explicit Z/offset, use user timezone interpretation
            if (space.endsWith('Z') || space.contains('+') || space.contains('-')) {
                // For user timezone interpretation, we'll parse as-is and let DateTime handle it
                // This preserves the timezone information for user context
                return DateTime.parse(space);
            }
                       if (iso.contains('.')            T-dd HH:mm:ss[.SSS]"
            return DateTime.valueOf(space);
        } catch (Exception e) {
            System.debug('parseToDateTimeSafe failed for '+s+' : '+e.getMessage());
            return null;
        }
    }

    private static Time parseToTimeSafe(String s) {
        if (String.isBlank(s)) return null;
        try {
            String t = s.trim();
            // Accept "HH:mm" or "HH:mm:ss" or "HH:mm:ss.SSS"
            if (t.length()    }

    // Parsing helpers for dat += ':00.000';
            } else if (t.length() == 8) { // "HH:mm:ss"
                t += '.000';
            } else if (t.endsWith('Z')) {
                t = t.substring(0, t.length()-1);
            }
            // Use DateTime.parse for time parsing (this is more reliable)
            return Time.parse(t);
        } catch (Exception e) {
            System.debug('parseToTimeSafe failed for '+s+' : '+e.getMessage());
            return null;
        }
    }
}
