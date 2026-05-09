/**
 * Purpose: Controller for naamJaapTracker Lightning Web Component
 * Provides methods to query and expose Naam_Jaap__c records
 */
public with sharing class NaamJaapController {
    
    @AuraEnabled(cacheable=true)
    public static List<NaamJaapWrapper> getNaamJaapData() {
        List<NaamJaapWrapper> wrapperList = new List<NaamJaapWrapper>();
        
        for(NaamJapp__c record : DataProvider.getNaamJaapRecords()) {
            NaamJaapWrapper wrapper = new NaamJaapWrapper(record);
            wrapperList.add(wrapper);
        }
        
        return wrapperList;
    }

    @AuraEnabled(cacheable=true)
    public static List<NaamJaapWrapper> getNaamJaapDataByMonthYear(Integer month, Integer year) {
        List<NaamJaapWrapper> wrapperList = new List<NaamJaapWrapper>();
        
        Date startDate = Date.newInstance(year, month, 1);
        Integer lastDay = Date.daysInMonth(year, month);
        Date endDate = Date.newInstance(year, month, lastDay);
        
        List<NaamJapp__c> records = [
            SELECT Id, Date__c, Entity__c, Count__c
            FROM NaamJapp__c
            WHERE Date__c >= :startDate AND Date__c <= :endDate
            ORDER BY Date__c DESC
        ];
        
        for(NaamJapp__c record : records) {
            NaamJaapWrapper wrapper = new NaamJaapWrapper(record);
            wrapperList.add(wrapper);
        }
        
        return wrapperList;
    }
    
    public class NaamJaapWrapper {
        @AuraEnabled public Id recordId {get; set;}
        @AuraEnabled public Date naamJaapDate {get; set;}
        @AuraEnabled public String entity {get; set;}
        @AuraEnabled public Integer count {get; set;}
        @AuraEnabled public String formattedDate {get; set;}
        
        public NaamJaapWrapper() {}
        
        public NaamJaapWrapper(NaamJapp__c record) {
            this.recordId = record.Id;
            this.naamJaapDate = record.Date__c;
            this.entity = record.Entity__c;
            this.count = Integer.valueOf(record.Count__c);
            this.formattedDate = formatDate(record.Date__c);
        }
        
        private String formatDate(Date dateValue) {
            if(dateValue != null) {
                DateTime dt = DateTime.newInstance(dateValue.year(), dateValue.month(), dateValue.day());
                return dt.format('dd-MMM-yyyy');
            }
            return '';
        }
    }
}
