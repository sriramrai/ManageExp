public with sharing class InvestmentTriggerHandler {
    private static Id invetmentRT;
    private static Id stockRT;
    private static List<Investment__c> stocks;
    private static Set<String> stockName;
    public static void handleBeforeInsert(List<Investment__c> newList) {
        getStocks(newList);
        checkDuplicate(newList);
    }

    public static void handleAfterInsert(List<Investment__c> newInvestments) {
        System.debug('Investment*** : '+JSON.serialize(newInvestments));
        List<Investment_Line_Items__c> lineItems = convertLineItems(newInvestments);
        System.debug('LineItem*** : '+JSON.serialize(lineItems));
        if(!lineItems.isEmpty()) {
            insert lineItems;
        }
    }



    private static List<Investment_Line_Items__c> convertLineItems(List<Investment__c> newIvts) {
        List<Investment_Line_Items__c> lineItems = new List<Investment_Line_Items__c>();
        for(Investment__c ivt : newIvts) {
            Investment_Line_Items__c lineItem = new Investment_Line_Items__c(Investment__c = ivt.Id);
            lineItem.Exchange__c = ivt.Exchng__c;
            lineItem.Amount__c = ivt.Amount__c;
            lineItem.Per_Share_Price__c = ivt.Buying_Price__c;
            lineItem.Date__c = ivt.Start_Date__c;
            lineItem.Quantity__c = ivt.Quantity__c;
            lineItem.Buy_Sell__c = 'Buy';
            lineItem.Type__c = 'Re-invest';
            lineItems.add(lineItem);
        }

        return lineItems;
    }

    private static List<Investment__c> getStocks(List<Investment__c> ivts) {
        stockRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName().get('Stock').getRecordTypeId();
        stockName = new Set<String>();
        if(stocks == null) {
            stocks = new List<Investment__c>();
            for(Investment__c ivt : ivts) {
                if(ivt.RecordTypeId == stockRT) {
                    stocks.add(ivt);
                    stockName.add(ivt.Account_Number__c);
                }
            }
        }
        return stocks;
    }

    private static void checkDuplicate(List<Investment__c> ivts) {
        Set<String> existingStock = new Set<String>();
        for(Investment__c ivt : [SELECT Id, Account_Number__c FROM Investment__c WHERE Account_Number__c IN: stockName]) {
            existingStock.add(ivt.Account_Number__c);
        }
        for(Investment__c ivt : ivts) {
            if(existingStock.contains(ivt.Account_Number__c)) {
                ivt.addError('Stock is already exist, Please add the line item for the same');
            }
        }
    }
}