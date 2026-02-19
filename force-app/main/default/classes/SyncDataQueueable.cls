public with sharing class SyncDataQueueable implements Database.Batchable<String>, Database.AllowsCallouts, Database.Stateful {
    private String objectName;
    private Integer offset;
    private String step;
    private String filter;
    private String syncDataId;
    private String syncDataItemId;
    private boolean stop = false;
    private String errorMessage;
    public Integer count = 0;
    public SyncDataQueueable(String objectName, Integer offset, String step, String filter, String syncDataId, String syncDataItemId) {
        this.objectName = objectName;
        this.offset = offset;
        this.step = step;
        this.filter = filter;
        this.syncDataId = syncDataId;
        this.syncDataItemId = syncDataItemId;
    }
    public SyncDataQueueable(String objectName, Integer offset, String step, String filter, String syncDataId, String syncDataItemId, Integer count) {
        this.objectName = objectName;
        this.offset = offset;
        this.step = step;
        this.filter = filter;
        this.syncDataId = syncDataId;
        this.syncDataItemId = syncDataItemId;
        this.count = count;
    }

    public Iterable<String> start(Database.BatchableContext bc) {
        List<String> chunks = new List<String>();
        chunks.add('chunk'); // Only one chunk per execute
        return chunks;
    }
    
    public static Sync_Data_Configuration__mdt getSyncDataConfig(String configName) {
        Map<String, Sync_Data_Configuration__mdt> configMap = Sync_Data_Configuration__mdt.getAll();
        return configMap.get('Sync_Data_Config');
    }

    public static String getBaseEndpointURL() {
        String endpointURI = '';
        Sync_Data_Configuration__mdt config = getSyncDataConfig('Sync_Data_Config');
        if(config != null) {
            endpointURI = 
                config.Test_Mode__c ? 
                    URL.getOrgDomainUrl().toExternalForm() + '/services/apexrest/syncdata' : 
                    config.End_Point_URL__c;
        } 
        return endpointURI;
    }

    //System.debug('getSyncDataConfig Sync_Data_Config***  : '+SyncDataQueueable.getSyncDataConfig('Sync_Data_Config'));
    //System.debug('getBaseEndpointURL**** : '+SyncDataQueueable.getBaseEndpointURL());

    private HttpResponse sendRequest() {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        String endpointUrl =
            getBaseEndpointURL()
            + '?objectName=' + objectName
            + '&offset=' + offset
            + '&syncDataId='+ syncDataId
            + '&syncDataItemId=' + syncDataItemId
            + '&step='+step;
        String encodedFilter;
        if(step == 'l1' && String.isNotBlank(filter)) {
            encodedFilter = filter;
        }else if(String.isNotBlank(filter)) {
            encodedFilter = EncodingUtil.urlEncode(filter, 'UTF-8');
        }
        if(String.isNotBlank(encodedFilter)) {
            endpointUrl += '&filter=' + encodedFilter;
        }
        System.debug('endpointUrl**** : '+endpointUrl);
        req.setEndpoint(endpointUrl);
        //req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        HttpResponse response = new Http().send(req);
        System.debug('Status code: ' + response.getStatusCode());
        System.debug('Body: ' + response.getBody());
        return response;
    }

    public void execute(Database.BatchableContext bc, List<String> scope)  {
        HttpResponse response = sendRequest();
        System.debug('insidee execute before making the request**** : '+this.stop);
        String procssedData = SyncDataController.processResponse(response.getBody());
        SyncDataController.ProcessedResult pResult = 
            (SyncDataController.ProcessedResult)JSON.deserialize(procssedData, SyncDataController.ProcessedResult.class);
        this.objectName = pResult.objectName;
        this.offset = pResult.offset;
        this.step = pResult.step;
        this.filter = pResult.filter;
        this.syncDataId = this.syncDataId;
        this.syncDataItemId = pResult.syncDataItemId;
        this.stop = pResult.stop;
        this.errorMessage = pResult.errorMessage;
        System.debug('insidee execute after making the request**** : '+this.stop);
    }

    public void enqueuejob() {
        Database.executeBatch(new SyncDataQueueable(objectName, offset, step, filter, syncDataId, syncDataItemId), 1);
    }

    private void updateSyncData() {
        System.debug('inside updateSyncData this.syncDataId*** : '+this.syncDataId);
        Sync_Data__c syncData = new Sync_Data__c(Id = syncDataId, Status__c = 'Completed', Fetch_Completed__c = true);
        if(String.isNotBlank(this.errorMessage)) {
            syncData.Error_Message__c = this.errorMessage;
            syncData.Status__c = 'Error';
            syncData.Fetch_Completed__c = false;
        }
        update syncData;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Batch finished. code *** : '+this.offset);
        Testing_Switch__c cs = Testing_Switch__c.getInstance();
        Sync_Data_Configuration__mdt synDataConfig = getSyncDataConfig('Sync_Data_Config');
        System.debug('inside finish test mode***  : '+cs.Test_Mode__c);
        System.debug('inside finish this.stop*** : '+this.stop);
        System.debug('inside finish this.syncDataId*** : '+this.syncDataId);
        System.debug('inside finish this.errormessage *** : '+this.errorMessage);
        if(this.stop) {
            updateSyncData();
        }else if(synDataConfig.Enabled__c){
            enqueuejob();
        }
    }
}