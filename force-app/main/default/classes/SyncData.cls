@RestResource(urlMapping='/syncdata')
global with sharing class SyncData {
    public SyncData() {

    }
    
    @HttpGet
    global static void doGet() {
        System.debug('Inside doGet Method....');
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        try {
            SyncDataHandler.processRequest();
        }catch(Exception e) {
            System.debug('Inside catch block....');
            res.statusCode = 500;
            res.responseBody = Blob.valueOf('Error *** : '+e.getMessage());
        }
    }
}