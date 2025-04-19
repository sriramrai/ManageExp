public with sharing class ExpenseController {
    
    private static String getExpenseName(Date dateValue) {
        Integer month = dateValue.month();
        Integer year = dateValue.year();
        String yearName = String.valueOf(Math.Mod(year,2000));
        String monthName;
        switch on month {
            when  1{
                monthName = 'JAN';
            }
            when 2 {
                monthName = 'FEB';
            }
            when 3 {
                monthName = 'MAR';
            }
            when 4 {
                monthName = 'APR';
            }
            when 5 {
                monthName = 'MAY';
            }
            when 6 {
                monthName = 'JUN';
            }
            when 7 {
                monthName = 'JUL';
            }
            when 8 {
                monthName = 'AUG';
            }
            when 9 {
                monthName = 'SEP';
            }
            when 10 {
                monthName = 'OCT';
            }
            when 11 {
                monthName = 'NOV';
            }
            when 12 {
                monthName = 'DEC';
            }
        }

        return monthName+' '+yearName;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> calculateDifference() {
        Map<String, Decimal> resultMap = new Map<String, Decimal>();
        Map<String, Decimal> diffMap = new Map<String, Decimal>{'Shivam' => 0, 'Sriram' => 0};
        Date startDate = Date.newInstance(2023, 06, 01);
        Date currentDate = Date.today();
        String expenseName = getExpenseName(Date.today());
        
        for(Expense__c exp : [SELECT Shivam__c, Sriram__c, Diff__c, Name FROM Expense__c WHERE Start_Date__c >=: startDate]) {
            Decimal firstPerson = exp.Shivam__c == null ? 0 : exp.Shivam__c;
            Decimal secondPerson = exp.Sriram__c == null ? 0 : exp.Sriram__c;
            diffMap.put('Shivam' , diffMap.get('Shivam')+ firstPerson);
            diffMap.put('Sriram' , diffMap.get('Sriram')+ secondPerson);
            if(exp.Name.equalsIgnoreCase(expenseName)) {
                if(exp.Diff__c > 0) {
                    resultMap.put('Current:Sriram', exp.Diff__c);
                }else if(exp.Diff__c < 0) {
                    resultMap.put('Current:Shivam', exp.Diff__c);
                }
            }
        }
        System.debug(diffMap);
        if(diffMap.get('Shivam') > diffMap.get('Sriram')) {
            resultMap.put('Shivam', diffMap.get('Shivam')-diffMap.get('Sriram'));
        }else if(diffMap.get('Sriram') > diffMap.get('Shivam')) {
            resultMap.put('Sriram', diffMap.get('Sriram')-diffMap.get('Shivam'));
        }else {
            resultMap.put('Diffrence', 0);
        }

        return resultMap; 
    }

    private static List<ExpenseWrapper> pastExpenses(Integer last_N_Months) {
        Date currentDate = Date.today();
        Date toDate = currentDate.addMonths(1).toStartOfMonth().addDays(-1);
        Date fromDate = currentDate.toStartOfMonth().addMonths(-last_N_Months);
        List<ExpenseWrapper> expenses = new List<ExpenseWrapper>();
        for(Expense__c exp : [SELECT Id, Name, Start_Date__c, Sriram__c, Other__c FROM Expense__c 
                                WHERE Start_Date__c >=: fromDate AND Start_Date__c <=: toDate ORDER BY Start_Date__c DESC]) {
            Decimal total = exp.Sriram__c + exp.Other__c;
            expenses.add(new ExpenseWrapper(exp.Name, total, exp.Id));
        }
        return expenses;
    }

    @AuraEnabled(cacheable = true) 
    public static Id getCurrentExpenseId() {
        String expenseName = getExpenseName(Date.today());
        List<Expense__c> expenseList = new List<Expense__c>([SELECT Id, Name FROM Expense__c WHERE Name =: expenseName]);
        if(!expenseList.isEmpty()) {
            return expenseList[0].Id;
        }

        return '';
    }

    @AuraEnabled(cacheable = true)
    public static List<ExpenseWrapper> getAllExpenses() {
        List<ExpenseWrapper> expenseList = new List<ExpenseWrapper>();
        Date sdate = Date.newInstance(2023, 09, 01);
        for(Expense__c expense : [SELECT Id, Name, Other__c, Ragini__c 
                                    FROM Expense__c 
                                    WHERE Start_Date__c > :sdate 
                                    ORDER BY Start_Date__c DESC]) {
            ExpenseWrapper exp = new ExpenseWrapper(expense);
            expenseList.add(exp);
        }

        return expenseList;
    }

    @AuraEnabled(cacheable = true)
    public static List<Expense__c> getAllExpensesV2() {
        List<ExpenseWrapper> expenseList = new List<ExpenseWrapper>();
        Date sdate = Date.newInstance(2023, 09, 01);
        return [SELECT Id, Name, Other__c, Ragini__c 
        FROM Expense__c 
        WHERE Start_Date__c > :sdate 
        ORDER BY Start_Date__c DESC];
    }

    @AuraEnabled(cacheable = true)
    public static List<Expense_Line_Item__c> getExpensesV2(Date fromDate, Date toDate, String expenseBy) {
        List<String> expendBy = new List<String> {expenseBy};
        String query = 'SELECT Id, Date__c, Amount__c, Details__c, Debited_By__c FROM Expense_Line_Item__c ';
        query +=  fromDate != null ? ' WHERE Date__c >= :fromDate AND Date__c <= :toDate ' : '';
        query += ' AND Debited_By__c IN :expendBy ORDER BY Date__c DESC';
        return (List<Expense_Line_Item__c>)(Database.query(query));
    }

    @AuraEnabled(cacheable=true)
    public static List<ExpenseWrapper> getExpenses(Date startDate, Date endDate, String expenseBy) {
        System.debug('StartDate**** : '+startDate);
        System.debug('EndDate**** : '+endDate);
        System.debug('ExpenseBy**** : '+expenseBy);
        List<String> expenseByList = new List<String>();
        if(expenseBy.equals('pastExpenses')) {
            System.debug('pastExpenses(6)** : '+JSON.serialize(pastExpenses(6)));
            return pastExpenses(3);
        }
        if(expenseBy.equals('Daywise')) {
            expenseByList.add('Sriram');
            expenseByList.add('Ragini');
            expenseByList.add('Other');

        }else {
            expenseByList.add(expenseBy);
        }
        
        List<ExpenseWrapper> expenses = new List<ExpenseWrapper>();
        for(Expense_Line_Item__c lineItem : [SELECT Id, Date__c, Amount__c,Details__c, Debited_By__c 
                                            FROM Expense_Line_Item__c 
                                            WHERE Debited_By__c IN :expenseByList AND Date__c >= :startDate AND Date__c <= :endDate ORDER BY Date__c DESC]) {
            ExpenseWrapper ew = new ExpenseWrapper(lineItem.Id, lineItem.Date__c, lineItem.Amount__c, lineItem.Details__c, lineItem.Debited_By__c);
            expenses.add(ew);                                    
        }
        return expenses;
    }

    @AuraEnabled(cacheable=true)
    public static List<ExpenseWrapper> getCurrentMonthExpenses(String expenseBy){
        try {
            String expenseName = getExpenseName(Date.today());
            System.debug('Expense By***** :'+expenseBy);
            System.debug('Expense Name***** :'+expenseName);
            List<ExpenseWrapper> lineItems = new List<ExpenseWrapper>();

            if(expenseBy.equalsIgnoreCase('Leading')) {
                for(Expense__c exp : [SELECT Id, Diff__c,Name FROM Expense__c ORDER BY Start_Date__c DESC]) {
                    if(exp.Diff__c != null && exp.Diff__c != 0) {
                        ExpenseWrapper ew = new ExpenseWrapper(exp.Id, exp.Name, exp.Diff__c);
                        lineItems.add(ew);
                    }
                }
            }else {
                for(Expense_Line_Item__c lineItem : [SELECT Id, Date__c, Amount__c,Details__c, Debited_By__c  
                FROM Expense_Line_Item__c 
                WHERE Debited_By__c =: expenseBy AND Expense__r.Name =: expenseName
                ORDER BY Date__c DESC]) {
                    ExpenseWrapper ew = new ExpenseWrapper(lineItem.Id, lineItem.Date__c, lineItem.Amount__c, lineItem.Details__c, lineItem.Debited_By__c);
                    lineItems.add(ew);
                }
                System.debug(expenseName+lineItems.size());
            }
            return lineItems;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }
    
    public class ExpenseWrapper {
        @AuraEnabled public String expenseDate;
        @AuraEnabled public Integer amount;
        @AuraEnabled public String description;
        @AuraEnabled public Id id;
        @AuraEnabled public String recordURL;
        @AuraEnabled public String expenseName;
        @AuraEnabled public String leadBy;
        @AuraEnabled public Integer difference;
        @AuraEnabled public String debitedBy;
        @AuraEnabled public Integer ragini;
        @AuraEnabled public Integer sriram;

        public ExpenseWrapper(){}

        public ExpenseWrapper(Expense__c exp) {
            this.expenseName = exp.Name;
            this.ragini = Integer.valueOf(exp.Ragini__c);
            this.sriram = Integer.valueOf(exp.Other__c);
            this.Id = exp.Id;
        }

        public ExpenseWrapper(String name, Decimal amount, Id id) {
            this.id = id;
            this.expenseName = name;
            this.amount = Integer.valueOf(amount);
        }

        private String formatDate(Date dt) {
            String dateFormat = 'd MMM, yyyy';
            Datetime dtime = Datetime.newInstance(dt.year(), dt.month(), dt.day());
            return dtime.format(dateFormat);
        }

        public ExpenseWrapper(Id id, Date ed, Decimal amt, String description, String debitedBy) {
            this.id = id;
            this.expenseDate = formatDate(ed);
            this.amount = Integer.valueOf(amt);
            this.description = description;
            this.recordURL = '/'+id;
            this.debitedBy = debitedBy;
        }

        public ExpenseWrapper(Id id, String name, Decimal difference) {
            this.id = id;
            this.expenseName = name;
            this.recordURL = '/'+id;
            this.leadBy = (difference > 0) ? 'Sriram' : 'Shivam';
            
            this.difference = Math.abs(Integer.valueOf(difference));
        }
    }

    @AuraEnabled
    public static String deleteELI(List<String> recordIds) {
        List<Expense_Line_Item__c> expenseList = new List<Expense_Line_Item__c>([SELECT Id FROM Expense_Line_Item__c WHERE Id IN :recordIds]);
        delete expenseList;
        return 'success';
    } 

    @AuraEnabled(cacheable=true)
    public static List<Expense_Line_Item__c> getCCStatements(Integer month, Integer year, String bank) {
        Integer dueDay = bank == 'ICICI CC' ? 10 : 7; 
        Date dueDate = Date.newInstance(year, month, dueDay);
        System.debug('dueDate.... : '+dueDate);
        return new List<Expense_Line_Item__c>([
            SELECT Id, Amount__c, Details__c, Date__c, Payment_Due_Date__c FROM Expense_Line_Item__c 
            WHERE Source__c = :bank AND Payment_Due_Date__c = :dueDate
        ]);
    }
}