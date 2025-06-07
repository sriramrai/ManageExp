public with sharing class InvestmentLineTriggerHandler {
    private static List<Investment_Line_Items__c> stocks;
    private static Id stockRT;

    public static void handleAfterInsert(List<Investment_Line_Items__c> ivtList) {
        getAllStocks(ivtList);
        processStock(stocks);
    }

    public static void handleAfterUpdate(List<Investment_Line_Items__c> newList, Map<Id, Investment_Line_Items__c> oldMap) {
        getAllStocks(newList);
    }

    private static List<Investment_Line_Items__c> getAllStocks(List<Investment_Line_Items__c> newLines) {
        if(stocks != null) {
            return stocks;
        }

        stockRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName().get('Stock').getRecordTypeId();
        Map<Id, Investment__c> ivtStockMap = new Map<Id, Investment__c>([SELECT Id FROM Investment__c WHERE RecordTypeId = :stockRT]);
        stocks = new List<Investment_Line_Items__c>();
        for(Investment_Line_Items__c line : newLines) {
            if(ivtStockMap.containsKey(line.Investment__c)) {
                stocks.add(line);
            }
        }

        return stocks;
    }

    private static void processStock(List<Investment_Line_Items__c> stockList) {
        Map<Id, List<Investment_Line_Items__c>> stockByParent = new Map<Id, List<Investment_Line_Items__c>>();
        for(Investment_Line_Items__c line : stockList) {
            String investmentId = line.Investment__c;
            if(stockByParent.containsKey(investmentId)) {
                stockByParent.get(investmentId).add(line);
            }else {
                stockByParent.put(investmentId, new List<Investment_Line_Items__c>{line});
            }
        }

        List<Investment__c> ivtList = new List<Investment__c>();
        Map<Id, Investment__c> investmentMap = new Map<Id, Investment__c> ([
            SELECT Id, Total_Buy__c, Total_Sold__c, Amount__c FROM Investment__c WHERE Id IN :stockByParent.keySet()
        ]);

        for(String key : stockByParent.keySet()) {
            String ivtId = key;
            List<Investment_Line_Items__c> lineItems = stockByParent.get(ivtId);
            Decimal totalBuy = 0;
            Decimal totalSold = 0;
            Decimal buyAmount = 0;
            Decimal soldAmount = 0;
            for(Investment_Line_Items__c lineItem : lineItems) {
                if(lineItem.Buy_Sell__c == 'Buy') {
                    totalBuy += lineItem.quantity__c;
                    buyAmount += lineItem.Amount__c;
                }else {
                    totalSold += lineItem.quantity__c;
                    soldAmount += lineItem.Amount__c;
                }
            }
            investmentMap.get(ivtId).Total_Buy__c += totalBuy;
            investmentMap.get(ivtId).Total_Sold__c += totalSold;
            //investmentMap.get(ivtId).Amount__c = (investmentMap.get(ivtId).Amount__c+buyAmount)-soldAmount;
            //investmentMap.get(ivtId).Amount__c = 
        }
        for(Investment__c ivt : [SELECT Id, Amount__c, 
            (SELECT Id, Amount__c, Buy_Sell__c FROM Investment_Line_Items__r) 
        FROM Investment__c WHERE Id IN :investmentMap.keySet()]) {
            Decimal totalBuy = 0;
            Decimal totalSold = 0;
            for(Investment_Line_Items__c ivtLine : ivt.Investment_Line_Items__r) {
                if(ivtLine.Buy_Sell__c == 'Buy') {
                    totalBuy+= ivtLine.Amount__c;
                }else if(ivtLine.Buy_Sell__c == 'Sell') {
                    totalSold+= ivtLine.Amount__c;
                }
                
            }
            investmentMap.get(ivt.Id).Amount__c = totalBuy-totalSold;
        }
        update investmentMap.values();
    }
}