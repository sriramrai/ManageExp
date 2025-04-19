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

    public static List<Investment__c> getAllInvestments() {
        String query = 'SELECT Id, Name, Account_Number__c, Maturity_Amount__c, Start_Date__c, Amount__c, ';
        query += ' Rate__c, Bank__c, TAX_SAVER__c, Maturity_Date__c, Month__c, Year__c, Day__c ';
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
        List<Investment__c> ivtList = new List<Investment__c>([
                                            SELECT Id, Bank__c, Account_Number__c, Maturity_Date__c 
                                            FROM Investment__c 
                                            WHERE Maturity_Date__c <= :endDate AND Is_Closed__c = false AND is_Test__c =: isTestMode()]);
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
}