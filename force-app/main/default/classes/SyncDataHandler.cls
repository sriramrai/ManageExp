public with sharing class SyncDataHandler {
    public static void processRequest() {
        RestRequest req = RestContext.request;
        RestResponse response = RestContext.response;
        String objectName = req.params.get('objectName');
        Integer offset = Integer.valueOf(req.params.get('offset'));
        String filter = req.params.get('filter');
        String syncDataId = req.params.get('syncDataId');
        String step = req.params.get('step');
        String syncDataItemId = req.params.get('syncDataItemId');
        System.debug('before query***');
        String queryString = prepareQueryString(objectName, offset, filter, step, syncDataId);
        System.debug('inside process request method**** : '+queryString);
        List<sObject> data = Database.query(queryString);

        SyncDataWrapper wrapper = new SyncDataWrapper();
        wrapper.objectName = objectName;
        wrapper.data = data;
    	wrapper.step = step;
        wrapper.syncDataId = syncDataId;
        wrapper.syncDataItemId = syncDataItemId;
        wrapper.offset = offset;
        wrapper.filter = filter;
        System.debug('response body*** : '+JSON.serialize(wrapper));
        response.statusCode = 200;
        response.responseBody = Blob.valueOf(JSON.serialize(wrapper));
    }

    private static String prepareQueryString(String objectName, Integer offset, String filter, String step, String syncDataId) {
        DateTime dateFilter;
        if(String.isNotBlank(step) && step.equalsIgnoreCase('l1')) {
            Sync_Data__c syncData = [SELECT Id, Date_Filter__c FROM Sync_Data__c WHERE Id =: syncDataId LIMIT 1];
            if(syncData.Date_Filter__c != null) {
                Date dateValue = syncData.Date_Filter__c;
                DateTime dateTimeValue = DateTime.newInstanceGMT(
                    dateValue.year(),
                    dateValue.month(),
                    dateValue.day(),
                    0, 0, 0
                );
            }
        }
        String queryString = 'SELECT Id ';
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        for(Schema.SObjectField field : objectType.getDescribe().fields.getMap().values()) {
            if(field.getDescribe().isAccessible() && field.getDescribe().isUpdateable() && field.getDescribe().isCreateable()) {
                queryString += ', ' + field.getDescribe().getName();
            }
        }
        queryString += ' FROM ' + objectName;
        if(String.isNotEmpty(filter) && filter != 'null') {
            filter = filter.replace('[', '(').replace(']', ')');
			filter = filter.replace('"', '\'');
            queryString += filter;
        }
        if(dateFilter != null) {
            String dateStr = dateFilter.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            queryString += ' WHERE CreatedDate >= '+dateStr;
        }

        queryString += ' LIMIT 30 OFFSET ' + offset;
        return queryString;
    }

    public class SyncDataWrapper {
        public String objectName;
        public List<sObject> data;
        public String step;
        public Integer offset;
        public String syncDataId;
        public String syncDataItemId;
        public String filter;
    }
}