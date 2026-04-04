public with sharing class InvestmentTriggerHandler {
    private Id invetmentRT;
    private Id stockRT;
    private List<Investment__c> stocks;
    private List<Investment__c> investments;

    public void init(List<Investment__c> newList) {
        invetmentRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName().get('Investment').getRecordTypeId();
        stockRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName().get('Stock').getRecordTypeId();
        stocks = new List<Investment__c>();
        investments = new List<Investment__c>();
        for(Investment__c ivt : newList) {
            if(ivt.RecordTypeId == stockRT) {
                stocks.add(ivt);
            } else if(ivt.RecordTypeId == invetmentRT) {
                investments.add(ivt);
            }
        }
    }

    public void handleBeforeInsert() {
        try {
            checkDuplicateStock();          
        }catch(Exception ex) {
            throw ex;
        }   
    }

    public void handleAfterInsert() {
        try {
            createStockLineItems();
            createInvestmentLineItems();
        }catch(Exception ex) {
            throw ex;
        }
    }

    private void createInvestmentLineItems() {
        List<Investment_Line_Items__c> lineItems = new List<Investment_Line_Items__c>();
        for(Investment__c ivt : investments) {
            Investment_Line_Items__c lineItem = new Investment_Line_Items__c(Investment__c = ivt.Id);
            lineItem.Amount__c = ivt.Amount__c;
            lineItem.Type__c = 'New';
            lineItem.Date__c = ivt.Start_Date__c;
            lineItem.Investment_Date__c = ivt.Start_Date__c;
            lineItem.Rate__c = ivt.Rate__c;
            lineItem.Maturity_Date__c = ivt.Maturity_Date__c;
            lineItem.Tenure_Day__c = ivt.Day__c;
            lineItem.Tenure_Mnt__c = ivt.Month__c;
            lineItem.Tenure_Yr__c = ivt.Year__c;
            lineItem.Expected_Maturity__c = ivt.Maturity_Amount__c;
            lineItem.Principle__c = ivt.Amount__c;
            lineItem.Bank__c = ivt.Bank__c;
            lineItems.add(lineItem);
        }

        if(!lineItems.isEmpty()) {
            insert lineItems;
        }
    }   

    private void createStockLineItems() {
        List<Investment_Line_Items__c> lineItems = new List<Investment_Line_Items__c>();
        for(Investment__c ivt : stocks) {
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

        if(!lineItems.isEmpty()) {
            insert lineItems;
        }
    }   
    private List<Investment_Line_Items__c> convertLineItems(List<Investment__c> newIvts) {
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

    private List<String> getStockNames() {
        List<String> stockNames = new List<String>();
        for(Investment__c ivt : stocks) {
            stockNames.add(ivt.Account_Number__c);
        }
        return stockNames;
    }

    private void checkDuplicateStock() {
        Set<String> existingStock = new Set<String>();
        List<String> stockNames = getStockNames();
        for(Investment__c ivt : [
            SELECT Id, Account_Number__c 
            FROM Investment__c 
            WHERE RecordTypeId = :stockRT 
            AND Account_Number__c IN :stockNames
        ]) {
            existingStock.add(ivt.Account_Number__c);
        }
        for(Investment__c ivt : stocks) {
            if(existingStock.contains(ivt.Account_Number__c)) {
                ivt.addError('Stock is already exist, Please add the line item for the same');
            }
        }
    }
}