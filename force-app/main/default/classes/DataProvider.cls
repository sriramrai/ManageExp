public with sharing class DataProvider {
    public static Boolean isTestMode() {
        Testing_Switch__c ts = Testing_Switch__c.getInstance();
        if(ts != null) {
            return ts.Test_Mode__c;
        }

        return false;
    }

    public static Investment__c getInvestment(String recordId) {
        return [SELECT Id, Name, Account_Number__c, Maturity_Amount__c, Start_Date__c, Amount__c, Rate__c, Bank__c, TAX_SAVER__c,
                 Maturity_Date__c, Month__c, Year__c, Day__c, Is_Closed__c
                 FROM Investment__c WHERE Id =: recordId LIMIT 1];
    }

    public static List<Investment__c> getInvestments(Date startDate, Date endDate) {
        return new List<Investment__c> ([SELECT Id, Start_Date__c, Amount__c, Bank__c 
                                            FROM Investment__c
                                            WHERE Start_Date__c >=: startDate AND Start_Date__c <=: endDate AND Re_invested_Count__c = 0
                                            ORDER BY Start_Date__c DESC
                                        ]);
    }

    public static List<FutureInvestmentWrapper> getAllFutureInvestments() {
        List<FutureInvestmentWrapper> wrapperList = new List<FutureInvestmentWrapper>();
        for(Investment__c ivt : [SELECT Id, Start_Date__c, Amount__c, Account_Number__c, Maturity_Date__c, Bank__c,
                                    (SELECT Id, Date__c, Amount__c FROM Investment_Line_Items__r ORDER BY Date__c DESC)
                                    FROM Investment__c
                                    WHERE Bank__c IN ('NPS', 'PPF') AND Account_Number__c IN ('1893PPF0000000138', '110168495351')]) {
            FutureInvestmentWrapper fiw = new FutureInvestmentWrapper(ivt);
            wrapperList.add(fiw);
        }
        return wrapperList;
    }

    public static List<Investment__c> getAllInvestments() {
        String query = 'SELECT Id, Name, Account_Number__c, Maturity_Amount__c, Start_Date__c, Amount__c, ';
        query += ' Rate__c, Bank__c, TAX_SAVER__c, Maturity_Date__c, Month__c, Year__c, Day__c, RecordTypeId, RecordType.Name ';
        query += ' FROM Investment__c WHERE Bank__c NOT IN (\'PPF\', \'NPS\') AND RecordType.Name = \'Investment\' AND ';
        if(isTestMode()) {
            query += ' is_Test__c = true';
        }else {
            query += ' is_Test__c = false';
        }

        query += ' AND Is_Closed__c = false ';
        
        return (List<Investment__c>) Database.query(query);
    }

    public static List<Investment__c> getAllInvestments(String bankname) {
        String query = 'SELECT Id, Name, Account_Number__c, Maturity_Amount__c, Start_Date__c, Amount__c, ';
        query += ' Rate__c, Bank__c, TAX_SAVER__c, Maturity_Date__c, Month__c, Year__c, Day__c, Re_invested_Count__c ';
        query += ' FROM Investment__c WHERE bank__c =: bankname AND ';
        if(isTestMode()) {
            query += ' is_Test__c = true';
        }else {
            query += ' is_Test__c = false';
        }

        query += ' AND Is_Closed__c = false ';

        return (List<Investment__c>) Database.query(query);
    }

    public static Investment__c getInvestmentWithAllLineItems(String recordId) {
        return [SELECT Id, Account_Number__c, Start_Date__c, Maturity_Date__c, Amount__c, Maturity_Amount__c, Rate__c,
                  (SELECT Id, Investment_Date__c, Maturity_Date__c, Expected_Maturity__c, Principle__c, TDS_Deducted__c,      Rate__c, Amount__c FROM Investment_Line_Items__r) 
                FROM Investment__c
                WHERE Id = :recordId];
    }

    public static Map<String, List<Investment__c>> invetmentByBank() {
        Map<String, List<Investment__c>> ivtByBank = new Map<String, List<Investment__c>>();
        List<Investment__c> allInvestments = getAllInvestments();
        for(Investment__c ivt: allInvestments) {
            if(String.isNotBlank(ivt.Bank__c)) {
                String key = ivt.Bank__c.toLowerCase();
                if(ivtByBank.containsKey(key)) {
                    ivtByBank.get(key).add(ivt);
                }else {
                    List<Investment__c> ivts = new List<Investment__c>{ivt};
                    ivtByBank.put(key, ivts);
                }
            }
        }

        return ivtByBank;
    }

    @AuraEnabled(cacheable = true)
    public static List<Investment__c> maturityThisMonth() {
        Date today = Date.Today();
        Integer lastDay = Date.daysInMonth(today.year(), today.month());
        Date startDate = Date.newInstance(today.year(), today.month(), 1);
        Date endDate = Date.newInstance(today.year(), today.month(), lastDay);
        //endDate = endDate.addMonths(3);
        Id ivtRecordType = Schema.SobjectType.Investment__c.getRecordTypeInfosByName().get('Investment').getRecordTypeId();
        List<Investment__c> ivtList = new List<Investment__c>([
                                            SELECT Id, Bank__c, Account_Number__c, Maturity_Date__c 
                                            FROM Investment__c 
                                            WHERE Maturity_Date__c <= :endDate AND Is_Closed__c = false AND is_Test__c =: isTestMode() AND RecordTypeId =: ivtRecordType]);
        return ivtList;
    }

    public static List<Investment_Line_Items__c> getThisFYLineItems(Investment__c ivt) {
        Date today = Date.Today();
        Integer currentYear = today.year();
        Integer currentMonth = today.month();

        Integer startFyYear = currentMonth <= 3 ? currentYear-1 : currentYear;
        Date fyStartDate = Date.newInstance(startFyYear, 04, 01);
        Date fyEndDate = Date.newInstance(startFyYear+1, 03, 31);

        List<Investment_Line_Items__c> lineItems = new List<Investment_Line_Items__c>([
            SELECT Id, Date__c, Amount__c FROM Investment_Line_Items__c WHERE Date__c >=: fyStartDate AND Date__c <=: fyEndDate and Investment__c =: ivt.Id
        ]);

        return lineItems;
    }

    public static List<Expense__c> getAllExpense() {
        List<Expense__c> expenses = new List<Expense__c>([
            SELECT Id, Name, Start_Date__c, End_Date__c, Other__c, Shivam__c, Sriram__c, Total_Expense__c
            FROM Expense__c
        ]);

        return expenses;
    }

    public static List<Expense__c> getExpenseByName(String name) {
        List<Expense__c> expenses = new List<Expense__c>([
            SELECT Id, Name, Start_Date__c, End_Date__c, Other__c, Shivam__c, Sriram__c, Total_Expense__c
            FROM Expense__c WHERE Name = : name
        ]);

        return expenses;
    }

    @AuraEnabled(cacheable=true)
    public static List<StockWrapper> getAllStocks() {
        Id stockRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName().get('Stock').getRecordTypeId();
        List<StockWrapper> stockList = new List<StockWrapper>();
        for(Investment__c ivt : [
            SELECT Id, Account_Number__c, Total_buy__c, Total_Sold__c, Amount__c, 
                (SELECT Id, Amount__c, Buy_Sell__c, Exchange__c, Quantity__c, Date__c, Per_Share_Price__c FROM Investment_Line_Items__r)
            FROM Investment__c WHERE RecordTypeId =: stockRT
        ]) {
            StockWrapper sw = new StockWrapper(ivt);
            stockList.add(sw);
        }

        return stockList;
    } 

    public class StockWrapper {
        @AuraEnabled public Id recordId {get; set;}
        @AuraEnabled public String stockName {get; set;}
        @AuraEnabled public Integer totalBuyed {get; set;}
        @AuraEnabled public Integer totalSold {get; set;}
        @AuraEnabled public Decimal totalInvested {get; set;}
        @AuraEnabled public List<StockLinesWrapper> lines {get; set;}
        @AuraEnabled public String recordURL {get; set;}
        public StockWrapper() {}
        public StockWrapper(Investment__c ivt) {
            this.recordId = ivt.Id;
            this.recordURL = '/'+this.recordId;
            this.stockName = ivt.Account_Number__c;
            this.totalBuyed = Integer.valueOf(ivt.Total_buy__c);
            this.totalSold = Integer.valueOf(ivt.Total_Sold__c);
            this.totalInvested = ivt.Amount__c;
            this.lines = new List<StockLinesWrapper>();
            for(Investment_Line_Items__c ivtLine : ivt.Investment_Line_Items__r) {
                StockLinesWrapper sline = new StockLinesWrapper(ivtLine);
                this.lines.add(sline);
            }
        }
    }
    public class StockLinesWrapper {
        @AuraEnabled public Id recordId {get; set;}
        @AuraEnabled public Date sdate {get; set;}
        @AuraEnabled public Decimal amount {get; set;}
        @AuraEnabled public String buySell {get; set;}
        @AuraEnabled public String exchange {get; set;}
        @AuraEnabled public Integer quantity {get; set;}
        @AuraEnabled public Decimal pricePerShare {get; set;}
        @AuraEnabled public String recordURL {get; set;}
        public StockLinesWrapper() {}
        public StockLinesWrapper(Investment_Line_Items__c ivtLine) {
            this.recordId = ivtLine.Id;
            this.recordURL = '/'+this.recordId;
            this.sdate = ivtLine.Date__c;
            this.amount = ivtLine.Amount__c;
            this.buySell = ivtLine.Buy_Sell__c;
            this.exchange = ivtLine.Exchange__c;
            this.quantity = Integer.valueOf(ivtLine.Quantity__c);
            this.pricePerShare = ivtLine.Per_Share_Price__c;
        }
    }

    public class FutureInvestmentWrapper {
        @AuraEnabled public Id recordId {get; set;}
        @AuraEnabled public String accountNumber {get; set;}
        @AuraEnabled public Decimal amount {get; set;}
        @AuraEnabled public String bankName {get; set;} 
        @AuraEnabled public Date startDate {get; set;}
        @AuraEnabled public Date maturityDate {get; set;}
        @AuraEnabled public Integer numberOfInvestments {get; set;}
        @AuraEnabled public List<FutureInvestmentLinesWrapper> lines {get; set;}
        public FutureInvestmentWrapper() {}
        public FutureInvestmentWrapper(Investment__c ivt) {
            this.recordId = ivt.Id;
            this.accountNumber = ivt.Account_Number__c;
            this.amount = ivt.Amount__c;
            this.bankName = ivt.Bank__c;
            this.startDate = ivt.Start_Date__c;
            this.maturityDate = ivt.Maturity_Date__c;
            this.numberOfInvestments = ivt.Investment_Line_Items__r.size();
            this.lines = new List<FutureInvestmentLinesWrapper>();
            for(Investment_Line_Items__c ivtLine : ivt.Investment_Line_Items__r) {
                FutureInvestmentLinesWrapper fw = new FutureInvestmentLinesWrapper(ivtLine);
                this.lines.add(fw);
            }
        }
    }

    public class FutureInvestmentLinesWrapper {
        @AuraEnabled public Id recordId {get; set;}
        @AuraEnabled public Date contributionDate {get; set;}
        @AuraEnabled public Decimal contributionAmount {get; set;}
        @AuraEnabled public String taggedFY {get; set;}
        @AuraEnabled public String recordURL {get; set;}
        public FutureInvestmentLinesWrapper() {}
        public FutureInvestmentLinesWrapper(Investment_Line_Items__c lineItem){
            this.recordId = lineItem.Id;
            this.recordURL = '/'+this.recordId;
            this.contributionDate = lineItem.Date__c;
            this.contributionAmount = lineItem.Amount__c;
            this.taggedFY = tagFiscalYear();
        }

        private String tagFiscalYear() {
            Integer year = this.contributionDate.year();
            Integer month = this.contributionDate.month();
            Integer startYr, endYr;
            if(month <= 3) {
                startYr = year-1;
                endYr = year;
            }else {
                startYr = year;
                endYr = year+1;
            }
            return String.valueOf(startYr) + ' - ' + String.valueOf(endYr);
        }
    }
}