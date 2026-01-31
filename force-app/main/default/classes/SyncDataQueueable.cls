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

    private HttpResponse sendRequest() {
        HttpRequest req = new HttpRequest();
        req.setMethod('GET');
        //String endpointUrlBase = 'callout:DevOrg_REST/services/apexrest/syncdata';
        String endpointUrlBase = URL.getOrgDomainUrl().toExternalForm() + '/services/apexrest/syncdata';
        String endpointUrl =
            endpointUrlBase
            + '?objectName=' + objectName
            + '&offset=' + offset
            + '&syncDataId='+ syncDataId
            + '&syncDataItemId=' + syncDataItemId
            + '&step='+step;
        if(String.isNotBlank(filter)) {
            String encodedFilter = EncodingUtil.urlEncode(filter, 'UTF-8');
            endpointUrl += '&filter=' + encodedFilter;
        }
        System.debug('endpointUrl**** : '+endpointUrl);
        req.setEndpoint(endpointUrl);
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
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
        this.syncDataId = pResult.syncDataId;
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
        Sync_Data__c syncData = new Sync_Data__c(Id = syncDataId, Status__c = 'Completed');
        if(String.isNotBlank(this.errorMessage)) {
            syncData.Error_Message__c = this.errorMessage;
            syncData.Status__c = 'Error';
        }
        update syncData;
    }

    public void finish(Database.BatchableContext bc) {
        System.debug('Batch finished. code *** : '+this.offset);
        Testing_Switch__c cs = Testing_Switch__c.getInstance();
        System.debug('inside finish test mode***  : '+cs.Test_Mode__c);
        System.debug('inside finish this.stop*** : '+this.stop);
        System.debug('inside finish this.syncDataId*** : '+this.syncDataId);
        System.debug('inside finish this.errormessage *** : '+this.errorMessage);
        if(this.stop) {
            updateSyncData();
        }else if(!this.stop && cs.Test_Mode__c){
            enqueuejob();
        }
    }
}