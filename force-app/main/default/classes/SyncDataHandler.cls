public with sharing class SyncDataHandler {
    private static RestRequest req;
    private static RestResponse response;
    private static SyncDataWrapper sdWrapper;
	
    private static DateTime parseDateTime(String str) {
        // Remove T and Z
        str = str.replace('T', ' ').replace('Z', '');
        // Remove milliseconds if present
        if(str.contains('.')) {
            str = str.substring(0, str.indexOf('.'));
        }
        Datetime filter = Datetime.valueOfGmt(str);
        return filter;
    }
    
    public static SyncDataWrapper analyzeData() {
        String l1 = req.params.get('l1');
        String l2 = req.params.get('l2');
        String l3 = req.params.get('l3');
        String l2Ref = req.params.get('l2_REF');
        String l3Ref = req.params.get('L3_REF');
        String filterstr = req.params.get('filter');
        DateTime filter;
        // Initialize the wrapper
        sdWrapper = new SyncDataWrapper();
        l1 = String.isNotBlank(l1) && l1 != 'null' ? l1 : null;
        l2 = String.isNotBlank(l2) && l2 != 'null' ? l2 : null;
        l3 = String.isNotBlank(l3) && l3 != 'null' ? l3 : null;
        l2Ref = String.isNotBlank(l2Ref) && l2Ref != 'null' ? l2Ref : null;
        l3Ref = String.isNotBlank(l3Ref) && l3Ref != 'null' ? l3Ref : null;
        filterstr = String.isNotBlank(filterstr) && filterstr != 'null' ? filterstr : null;
        try {
            System.debug('filterstr**** : '+filterstr);
            // Parse the filter date properly
            if(filterstr != null && filterstr != '' && filterstr != 'null') {
                // Try to parse the filter as a date
                try {
                    filter = parseDateTime(filterstr);
                } catch(Exception e) {
                    // If parsing fails, set filter to null to avoid query errors
                    filter = null;
                }
            } else {
                filter = null;
            }

            // Count records for L1 object with filter applied
            String l1Query = 'SELECT COUNT() FROM ' + l1;
            if (filter != null) {
                // Format the datetime properly for SOQL
                String filterString = filter.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
                l1Query += ' WHERE CreatedDate >= ' + filterString;
            }
            System.debug('l1Query*** : '+l1Query);
            Integer l1Count = Database.countQuery(l1Query);
            sdWrapper.l1Size = l1Count.toString();
            
            // Count records for L2 object that have a valid relationship to L1 records
            // Handle case where L2 might be null/empty
            if (l2 != null && l2 != '') {
                String l2Query = 'SELECT COUNT() FROM ' + l2 + ' WHERE ' + l2Ref + ' IN (SELECT Id FROM ' + l1;
                if (filter != null) {
                    // Format the datetime properly for SOQL
                    String filterString = filter.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
                    l2Query += ' WHERE CreatedDate >= ' + filterString;
                }
                l2Query += ')';
                System.debug('l2Query*** : '+l2Query);
                Integer l2Count = Database.countQuery(l2Query);
                sdWrapper.l2Size = l2Count.toString();
            } else {
                sdWrapper.l2Size = '0';
            }
            
            // Count records for L3 object that have a valid relationship to L2 records
            // Handle case where L3 might be null/empty
            if (l3 != null && l3 != '') {
                // Since nested subqueries aren't supported, we'll use a two-step approach:
                // 1. First get all L2 record IDs that are related to filtered L1 records
                String l2IdsQuery = 'SELECT Id FROM ' + l2 + ' WHERE ' + l2Ref + ' IN (SELECT Id FROM ' + l1;
                if (filter != null) {
                    // Format the datetime properly for SOQL
                    String filterString = filter.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
                    l2IdsQuery += ' WHERE CreatedDate >= ' + filterString;
                }
                l2IdsQuery += ')';
                
                // Get the L2 IDs first, then use them in a second query
                try {
                    List<sObject> l2Records = Database.query(l2IdsQuery);
                    List<Id> l2Ids = new List<Id>();
                    for(sObject record : l2Records) {
                        l2Ids.add((Id)record.get('Id'));
                    }
                    
                    if(l2Ids.size() > 0) {
                        // Now count L3 records that reference these L2 IDs
                        String l3QueryFinal = 'SELECT COUNT() FROM ' + l3 + ' WHERE ' + l3Ref + ' IN :l2Ids';
                        System.debug('l3QueryFinal*** : '+l3QueryFinal);
                        Integer l3Count = Database.countQuery(l3QueryFinal);
                        sdWrapper.l3Size = l3Count.toString();
                    } else {
                        sdWrapper.l3Size = '0';
                    }
                } catch(Exception e) {
                    // Fallback to simple count if the complex approach fails
                    String l3QueryFallback = 'SELECT COUNT() FROM ' + l3 + ' WHERE ' + l3Ref + ' != null';
                    System.debug('l3QueryFallback*** : '+l3QueryFallback);
                    Integer l3Count = Database.countQuery(l3QueryFallback);
                    sdWrapper.l3Size = l3Count.toString();
                }
            } else {
                sdWrapper.l3Size = '0';
            }
        } catch(Exception e) {
            // Handle any errors during counting
            System.debug('Error in analyzeData: ' + e.getMessage() + ' - ' + e.getStackTraceString());
            sdWrapper.l1Size = '0';
            sdWrapper.l2Size = '0';
            sdWrapper.l3Size = '0';
        }
        
        return sdWrapper;
    }

    private static SyncDataWrapper syncData() {
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

        sdWrapper = new SyncDataWrapper();
        sdWrapper.objectName = objectName;
        sdWrapper.data = data;
    	sdWrapper.step = step;
        sdWrapper.syncDataId = syncDataId;
        sdWrapper.syncDataItemId = syncDataItemId;
        sdWrapper.offset = offset;
        sdWrapper.filter = filter;
        System.debug('response body*** : '+JSON.serialize(sdWrapper)); 
        return sdWrapper;
    }

    public static void processRequest() {
        req = RestContext.request;
        response = RestContext.response;
        if(req.params.containsKey('context')) {
            sdWrapper = analyzeData();
        }else {
            sdWrapper = syncData();
        }
        response.statusCode = 200;
        response.responseBody = Blob.valueOf(JSON.serialize(sdWrapper));
    }

    public static String prepareQueryString(String objectName, Integer offset, String filter, String step, String syncDataId) {
        DateTime dateFilter;
        if(String.isNotBlank(step) && step.equalsIgnoreCase('l1') && String.isNotBlank(filter)) {
            dateFilter = parseDateTime(filter);
            filter = null;
        }
        String queryString = 'SELECT Id ';
        Schema.SObjectType objectType = Schema.getGlobalDescribe().get(objectName);
        for(Schema.SObjectField field : objectType.getDescribe().fields.getMap().values()) {
            if(field.getDescribe().isAccessible() && field.getDescribe().isCreateable()) {
                String fieldApiName = field.getDescribe().getName();
                fieldApiName = 
                    fieldApiName.equalsIgnoreCase('RecordTypeId') ? 
                    'RecordType.Developername' : fieldApiName;
                queryString += ', ' + fieldApiName;
            }
        }
        queryString += ' FROM ' + objectName;
        if(String.isNotEmpty(filter) && filter != 'null') {
            filter = filter.replace('[', '(').replace(']', ')');
			filter = filter.replace('"', '\'');
            queryString += filter;
        }
        System.debug('dateFilter***' + dateFilter);
        if(dateFilter != null) {
            String dateStr = dateFilter.formatGmt('yyyy-MM-dd\'T\'HH:mm:ss\'Z\'');
            queryString += ' WHERE CreatedDate >='+dateStr;
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
        public String l1Size;
        public String l2Size;
        public String l3Size;
    }
}