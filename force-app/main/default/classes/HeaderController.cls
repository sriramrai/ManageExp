public with sharing class HeaderController {
    static final String TAX_SAVER_KEY = 'TAX SAVER';
    static final String AXIS_KEY = 'AXIS';
    static final String SBI_KEY = 'SBI';
    static final String SC_KEY = 'SC';
    static final Integer OLAKH = 100000;
    static final String GOLD = 'Gold';
    
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
        
        // Process Treasure__c records excluding Gold - combine all into single "Treasuree" row
        Decimal totalTreasureDeposit = 0;
        for(Treasure__c treasure : [
            SELECT Id, Tresuree__c, Amount__c 
            FROM Treasure__c 
            WHERE Tresuree__c != :GOLD
        ]) {
            totalTreasureDeposit += treasure.Amount__c;
        }
        
        // Add combined Treasure data as single row if there are any Treasure records
        if(totalTreasureDeposit > 0) {
            String treasureeKey = 'Treasuree';
            depositeMap.put(treasureeKey, totalTreasureDeposit);
            maturedMap.put(treasureeKey, 0);
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
        
        total.add(new Total(totalDeposite, totalMatured, 'Total'));
        total.sort();
        return total;
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

            // Always put 'Total' row at the end
            if(this.type.equals('Total')) {
                return 1;
            }
            if(obj.type.equals('Total')) {
                return -1;
            }

            // For all other rows, sort alphabetically
            if(this.type < obj.type) {
                return -1;
            }else if(this.type > obj.type){
                return 1;
            }

            return 0;
        }
    }
}