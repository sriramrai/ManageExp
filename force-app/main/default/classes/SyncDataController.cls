public with sharing class SyncDataController {
    private static Integer OFFSET_SIZE = 30;
    private static String syncDataRef;
    
    private static Sync_Data__c getSyncData() {
        return [
            SELECT Id, L1__c, L2__c, L3__c, L2_REF__c, L3_REF__c, Date_Filter__c, Total_L1__c, Total_L2__c, Total_L3__c, Analyzed__c, Status__c, Fetch_Completed__c, Sync_Completed__c 
            FROM Sync_Data__c WHERE Id =: syncDataRef
        ];
    }
    
    private static String getSyncDataQuery(Boolean isFetch) {
        String querySelect = 'SELECT Id, Level__c, Record_Count__c, Inserted_Records__c ';
        String queryFrom = ' FROM Sync_Data_Item__c ';
        String queryWhere = ' WHERE Sync_Data__c = : syncDataRef ';
        String queryOrderBy = '';
        if(isFetch) {
            queryOrderBy += ' ORDER BY CreatedDate DESC ';
        }else {
            queryWhere += ' AND Completed__c = true ';
            queryOrderBy = ' ORDER BY LastModifiedDate DESC ';
        }

        return querySelect + queryFrom + queryWhere + queryOrderBy;
    }

    @AuraEnabled(cacheable=false)
    public static String checkSyncStatus(String syncDataId, Boolean isFetch) {
        // Defensive defaults
        String opMessage = isFetch ? 'Fetching...' : 'Saving...';
        ProgressData pd = new ProgressData(opMessage, false, 0);
        try {
            // Example status computation:
            // Progress is derived from number of Sync_Data_Item__c created vs. some target.
            // Adjust logic to your needs.
            Integer total = 0;
            Integer completed = 0;

            syncDataRef = syncDataId;
            Sync_Data__c syncData = getSyncData();
            String currentLevel;
            String message;
            Decimal toExpectedRecords = syncData.Total_L1__c + syncData.Total_L2__c + syncData.Total_L3__c;
            Decimal totalFetchedRecords = 0;
            String syncDataQuery = getSyncDataQuery(isFetch);
            System.debug('syncDataQuery**** : '+syncDataQuery);
            for(Sync_Data_Item__c sdItem : (List<Sync_Data_Item__c>)Database.query(syncDataQuery)) {
                if(String.isBlank(currentLevel)) {
                    currentLevel = sdItem.Level__c;
                }
                totalFetchedRecords += sdItem.Record_Count__c;
            }
            System.debug('inside checkSyncData isFetch*** : '+isFetch);
            if(isFetch) {
                if(String.isNotBlank(currentLevel)) {
                    message = opMessage + (String)syncData.get(currentLevel+'__c');
                }else if(
                    syncData.Status__c != 'Fetching' &&
                    !syncData.Fetch_Completed__c
                ){
                    syncData(syncDataId);
                }
            }else {
                if(String.isNotBlank(currentLevel)) {
                    message = opMessage + (String)syncData.get(currentLevel+'__c');
                }else if(!syncData.Sync_Completed__c) {
                    syncData.Status__c = 'Syncing';
                    update syncData;
                    System.debug('syncDataId**** : '+syncDataId);
                    SyncDataInsertClone sdI = new SyncDataInsertClone(syncDataId);
                    Database.executeBatch(sdI, 1);
                }
            }
           
            Boolean done = false;
            Decimal completedPercentage = 
                toExpectedRecords > 0 ? 
                (totalFetchedRecords / toExpectedRecords) * 100 : 100;
            if(completedPercentage >= 100) {
                completedPercentage = 100;
                message = opMessage + ' Completed...';
                done = true;
            }
            pd = new ProgressData(message, done, completedPercentage);
            return JSON.serialize(pd);
        } catch (Exception e) {
            // Surface an error payload back to LWC
            return JSON.serialize(new ProgressData('Error checking sync status: ' + e.getMessage(), false, 0));
        }
    }

    private static String makeCallout(Sync_Data__c syncData) {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        String endpointUrlBase = 'callout:DevOrg/services/apexrest/syncdata';
        String endpointUrl =
            SyncDataQueueable.getBaseEndpointURL()
            + '?context=' + 'analyze'
            + '&l1=' + syncData.L1__c
            + '&l2='+ syncData.L2__c
            + '&l3=' + syncData.L3__c
            + '&l2_REF='+syncData.L2_REF__c
            + '&L3_REF='+syncData.L3_REF__c;
        if(syncData.Date_Filter__c != null) {
            DateTime filterDT = DateTime.newInstanceGMT(syncData.Date_Filter__c, Time.newInstance(0, 0, 0, 0));
            String isoString = filterDT.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
            endpointUrl += '&filter=' + isoString;

        }
        req.setEndpoint(endpointUrl);
        HttpResponse response = new Http().send(req);
        System.debug('Status code: ' + response.getStatusCode());
        System.debug('Body: ' + response.getBody());
        if (response.getStatusCode() == 200) {
            return response.getBody();
        }else {
            String errorMsg = 'API Error: ' + response.getStatusCode();
            if (response.getBody() != null) {
                errorMsg += ' - ' + response.getBody();
            }
            throw new AuraHandledException(errorMsg);
        }
    }

    @AuraEnabled(cacheable=false)
    public static String analyzeData(Id syncDataId) {
        syncDataRef = syncDataId;
        Sync_Data__c syncData = getSyncData();
        Sync_Data_Configuration__mdt config = SyncDataQueueable.getSyncDataConfig('Sync_Data_Config');
        //config.Test_Mode__c = true;
        if(syncData.Analyzed__c) {
            SyncDataWrapper sdWrapper = new SyncDataWrapper();
            sdWrapper.l1Size = syncData.Total_L1__c.toString();
            sdWrapper.l2Size = syncData.Total_L2__c.toString();
            sdWrapper.l3Size = syncData.Total_L3__c.toString();
            return JSON.serialize(sdWrapper);
        }else {
            String responseStr = makeCallout(syncData);
            System.debug('responseStr*** : '+responseStr);
            SyncDataWrapper wrapper = (SyncDataWrapper)JSON.deserialize(responseStr, SyncDataWrapper.class);
            Integer l1Size = String.isNotBlank(wrapper.l1Size) ? Integer.valueOf(wrapper.l1Size) : 0;
            Integer l2Size = String.isNotBlank(wrapper.l2Size) ? Integer.valueOf(wrapper.l2Size) : 0;
            Integer l3Size = String.isNotBlank(wrapper.l3Size) ? Integer.valueOf(wrapper.l3Size) : 0;
            syncData.Total_L1__c = l1Size;
            syncData.Total_L2__c = l2Size;
            syncData.Total_L3__c = l3Size;
            syncData.Analyzed__c = true;
            update syncData;
            return responseStr;
        }   
    }

    public static void syncData(String syncDataId) {
        Sync_Data__c sdata = [
            SELECT Id, L1__c, Date_Filter__c, Status__c FROM Sync_Data__c WHERE Id =: syncDataId
        ];
        String objectName = sdata.L1__c;
        Integer offset = 0;
        String step = 'l1';
        String filter = null;
        if(sdata.Date_Filter__c != null) {
            DateTime filterDT = DateTime.newInstanceGMT(sdata.Date_Filter__c, Time.newInstance(0, 0, 0, 0));
            String isoString = filterDT.formatGMT('yyyy-MM-dd\'T\'HH:mm:ss.SSS\'Z\'');
            filter = isoString;
        }
        String syncDataItemId = null;
        sdata.Status__c = 'Fetching';
        update sdata;
        Database.executeBatch(new SyncDataQueueable(objectName, offset, step, filter, syncDataId, syncDataItemId), 1);
    }

    @AuraEnabled(cacheable=true)
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

    @AuraEnabled(cacheable=true)
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
    public static void syncData1(String syncDataId) {
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

    public static Map<String, String> getRecordTypeMap(String objectName) {
        Map<String, String> rtMap = new Map<String, String>();
        for(RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE sObjectType = :objectName]) {
            rtMap.put(rt.DeveloperName, rt.Id);
        }
        return rtMap;
    }

    public static Sync_Data_Item__c formatAndFillData(Sync_Data_Item__c syncDataItem, SyncDataWrapper wrapper) {
        String dataPayload = JSON.serialize(wrapper.data);
        //String dataPayload = syncDataItem.Data__c;
        String objectName = wrapper.objectName;
        Map<String, String> recordTypeMap = getRecordTypeMap(objectName);
        List<Object> records = (List<Object>) JSON.deserializeUntyped(dataPayload);
        List<String> recordIds = new List<String>();
        for(Object obj : records) {
            Map<String, Object> recordMap = (Map<String, Object>) obj;
            if(recordMap.containsKey('Id')) {
                String recordId = (String) recordMap.get('Id');
                recordIds.add(recordId);
            }

            if(recordMap.containsKey('RecordType') && recordMap.get('RecordType') != null) {
                Map<String, Object> rtMap = (Map<String, Object>) recordMap.get('RecordType');
                if(rtMap.containsKey('DeveloperName')) {
                    String devName = (String) rtMap.get('DeveloperName');
                    if(recordTypeMap.containsKey(devName)) {
                        recordMap.put('RecordTypeId', recordTypeMap.get(devName));
                    }else {
                        recordMap.put('RecordTypeId', '');
                    }
                }
                recordMap.remove('RecordType');
            }
        }
        syncDataItem.Data__c = JSON.serialize(records);
        syncDataItem.RecordId__c = JSON.serialize(recordIds);
        return syncDataItem;
    }

    public static void createSyncDataItem(SyncDataWrapper wrapper, String data) {
        Sync_Data_Item__c sdItem = new Sync_Data_Item__c(
            Sync_Data__c = wrapper.syncDataId,
            Level__c = wrapper.step,
            Record_Count__c = wrapper.data.size()
        );
        sdItem = formatAndFillData(sdItem, wrapper);
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
        public String l1Size;
        public String l2Size;
        public String l3Size;
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

    public class ProgressData {
        public String message;
        public Boolean done;
        public Decimal progress;
        public ProgressData(String message, Boolean done, Decimal progress) {
            this.message = message;
            this.done = done;
            this.progress = progress;
        }
    }
    public class ProgressDataError {
        public String error;
        public ProgressDataError(String error) {
            this.error = error;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Expense__c> exportExpenseRecord() {
        return [SELECT id, name, Other__c, Ragini__c, Sriram__c, Shivam__c, Start_Date__c, End_Date__c 
                FROM Expense__c  
                ORDER BY CreatedDate ASC];
    }

    @AuraEnabled
    public static List<sObject> exportRecords(String objectName, String groupedField, Date fromDate, Date toDate, String filterField) {
        System.debug('fromDate**** : '+fromDate);
        System.debug('toDate***** : '+toDate);
        Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();
        Schema.SObjectType sobjectType = globalMap.get(objectName);
        Schema.DescribeSObjectResult descResult = sobjectType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = descResult.fields.getMap();
        List<String> fieldNames = new List<String>(fieldMap.keySet());
        String fieldList = String.join(fieldNames, ',');
        if(String.isNotBlank(groupedField)) {
            fieldList += ', '+groupedField;
        }
        String query = 'SELECT ' + fieldList + ' FROM ' + objectName;
        if(fromDate != null && toDate != null) {
            query += ' WHERE ' + filterField + ' >= :fromDate AND ' + filterField + ' <= :toDate';
        }
        return Database.query(query);
    }
}
