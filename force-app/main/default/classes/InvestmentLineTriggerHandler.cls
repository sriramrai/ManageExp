public with sharing class InvestmentLineTriggerHandler {
    private static List<Investment_Line_Items__c> stocks;
    private static Id stockRT;
    private static List<Investment_Line_Items__c> newList;

    public static void handleAfterInsert(List<Investment_Line_Items__c> ivtList) {
        processStock(ivtList);
    }

    public static void handleAfterUpdate(List<Investment_Line_Items__c> newList, Map<Id, Investment_Line_Items__c> oldMap) {
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

    private static void updateAmountOnInvestment(List<Investment_Line_Items__c> stocks) {
        List<Investment__c> investmentToUpdate = new List<Investment__c>();
        Map<Id, List<Decimal>> totalBuySoldMap = new Map<Id, List<Decimal>>();
        for(Investment_Line_Items__c stock : stocks) {
            if(String.isBlank(stock.Investment__c)) {
                continue;
            }
            String ivtId = stock.Investment__c;
            Decimal amount = stock.Amount__c;
            String buySell = stock.Buy_Sell__c;
            decimal buyPrice = 0;
            decimal sellPrice = 0;
            if(totalBuySoldMap.containsKey(ivtId)) {
                buyPrice = totalBuySoldMap.get(ivtId)[0];
                sellPrice = totalBuySoldMap.get(ivtId)[1];
            }
            buyPrice = buySell == 'Buy' ?  buyPrice + amount : buyPrice;
            sellPrice = buySell == 'Sell' ? sellPrice + amount : sellPrice;
            totalBuySoldMap.put(ivtId, new List<Decimal> {buyPrice, sellPrice});
        }

        for(Investment__c ivt : [SELECT Id, Amount__c FROM Investment__c WHERE Id IN : totalBuySoldMap.keySet()]) {
            List<Decimal> buySellPrices = totalBuySoldMap.get(ivt.Id);
            ivt.Amount__c = ivt.Amount__c == null ? 0 : ivt.Amount__c;
            Decimal totalAmount = ivt.Amount__c + (buySellPrices[0] - buySellPrices[1]);
            ivt.Amount__c = totalAmount;
            investmentToUpdate.add(ivt);
        }

        if(!investmentToUpdate.isEmpty()) {
            update investmentToUpdate;
        }
    }
    private static void processStock(List<Investment_Line_Items__c> newList) {
        List<Investment_Line_Items__c> stocks = getAllStocks(newList);
        updateAmountOnInvestment(stocks);
    }
}