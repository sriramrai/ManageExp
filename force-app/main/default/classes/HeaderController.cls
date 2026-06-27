public with sharing class HeaderController {
    static final String TAX_SAVER_KEY = 'TAX SAVER';
    static final String AXIS_KEY = 'AXIS';
    static final String SBI_KEY = 'SBI';
    static final String SC_KEY = 'SC';
    static final Integer OLAKH = 100000;
    static final String GOLD = 'Gold';
    static final String TREASUREE_KEY = 'Treasuree';
    static final String NET_WEALTH_KEY = 'Net Wealth';
    static final String TOTAL_KEY = 'Total';
    
    private static String getKey(Investment__c ivt) {
        if(ivt.TAX_SAVER__c) {
            return TAX_SAVER_KEY;
        }else if(ivt.Bank__c.equalsIgnoreCase(AXIS_KEY)) {
            return AXIS_KEY;
        }else if(ivt.Bank__c.equalsIgnoreCase(SBI_KEY)){
            return SBI_KEY;
        }else {
            return SC_KEY;
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Total> getTotal() {
        List<Total> total = new List<Total>();
        Map<String, Decimal> depositeMap = new Map<String, Decimal>();
        Map<String, Decimal> maturedMap = new Map<String, Decimal>();
        
        // Process Investment (Bank) data - existing logic
        for(Investment__c ivt : DataProvider.getAllInvestments()) {
            String mapKey = getKey(ivt);
            Decimal totalDeposite = depositeMap.containsKey(mapKey) ? depositeMap.get(mapKey) : 0;
            Decimal totalMatured = maturedMap.containsKey(mapKey) ? maturedMap.get(mapKey) : 0;
            depositeMap.put(mapKey, totalDeposite + ivt.Amount__c);
            maturedMap.put(mapKey, totalMatured + ivt.Maturity_Amount__c);
        }
        
        // Accumulate Treasure for display row and Net Wealth; Stock, PPF, and NPS for Net Wealth only
        Decimal totalTreasureDeposit = 0;
        for(Treasure__c treasure : [
            SELECT Id, Tresuree__c, Amount__c 
            FROM Treasure__c 
            WHERE Tresuree__c != :GOLD
        ]) {
            totalTreasureDeposit += treasure.Amount__c != null ? treasure.Amount__c : 0;
        }

        Decimal totalStockAmount = 0;
        Id stockRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName().get('Stock').getRecordTypeId();
        for(Investment__c stock : [
            SELECT Amount__c
            FROM Investment__c
            WHERE RecordTypeId = :stockRT
        ]) {
            totalStockAmount += stock.Amount__c != null ? stock.Amount__c : 0;
        }

        Decimal totalPPF = 0;
        Decimal totalNPS = 0;
        for(DataProvider.FutureInvestmentWrapper futureInvestment : DataProvider.getAllFutureInvestments()) {
            if(futureInvestment.bankName == 'PPF') {
                totalPPF += futureInvestment.amount != null ? futureInvestment.amount : 0;
            } else if(futureInvestment.bankName == 'NPS') {
                totalNPS += futureInvestment.amount != null ? futureInvestment.amount : 0;
            }
        }

        Decimal totalDeposite = 0;
        Decimal totalMatured = 0;
    
        for(String mapKey : depositeMap.keySet()) {
            Decimal deposite = depositeMap.get(mapKey);
            Decimal matured = maturedMap.containsKey(mapKey) ? maturedMap.get(mapKey) : 0;
            total.add(new Total(deposite, matured, mapKey));
            totalDeposite += deposite;
            totalMatured += matured;
        }

        if(totalTreasureDeposit > 0) {
            total.add(new Total(totalTreasureDeposit, 0, TREASUREE_KEY));
        }
        
        total.add(new Total(totalDeposite + totalTreasureDeposit, totalMatured, TOTAL_KEY));

        Decimal netWealth = totalStockAmount + totalTreasureDeposit + totalPPF + totalNPS + totalDeposite;
        total.add(new Total(netWealth, 0, NET_WEALTH_KEY));

        total.sort();
        return total;
    }

    private static Integer getRowOrder(String type) {
        if(type == NET_WEALTH_KEY) {
            return 3;
        }
        if(type == TOTAL_KEY) {
            return 2;
        }
        if(type == TREASUREE_KEY) {
            return 1;
        }
        return 0;
    }

    public class Total implements comparable {
        @AuraEnabled public Decimal deposited;
        @AuraEnabled public Decimal maturedamount;
        @AuraEnabled public String type;

        public Total() { 
            this.deposited = 0;
            this.maturedamount = 0;
            this.type = '';
        }

        public Total(Decimal deposited, Decimal matured, String type) {
            this.deposited = (deposited / OLAKH).setScale(2);
            this.maturedamount = (matured / OLAKH).setScale(2);
            this.type = type;
        }

        public Integer compareTo(Object tot) {
            Total obj = (Total) tot;

            Integer thisOrder = getRowOrder(this.type);
            Integer objOrder = getRowOrder(obj.type);
            if(thisOrder != objOrder) {
                return thisOrder < objOrder ? -1 : 1;
            }

            if(this.type < obj.type) {
                return -1;
            }else if(this.type > obj.type){
                return 1;
            }

            return 0;
        }
    }
}