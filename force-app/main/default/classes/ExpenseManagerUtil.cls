public with sharing class ExpenseManagerUtil {
    @AuraEnabled(cacheable=true)
    public static Income__c getIncome(String fiscalYear) {
        List<Income__c> incomes = new List<Income__c>([
            SELECT Id, Start_Date__c, End_date__c, Salary__c, Other__c 
            FROM Income__c
            WHERE Fiscal_Year__c =: fiscalYear
        ]);

        return !incomes.isEmpty() ? incomes[0] : null;
    }

    @AuraEnabled(cacheable=true)
    public static Salary_Structure__c getSalaryStructure(String fy) {
        List<Salary_Structure__c> salary = new List<Salary_Structure__c>(
            [SELECT Basic__c, Conveyance__c, Food_Allowance__c, EPF_Contribution__c, Fiscal_Year__c,
            HRA__c, Income_Tax__c, Labor_Welfare_Fund__c, LTA__c, Medical_Allowance__c, Professional_Tax__c,
            Project_Allowance__c, Telephone_Allowance__c
            FROM Salary_Structure__c
            WHERE Fiscal_Year__c = :fy]
        );
        
        if(!salary.isEmpty()) {
           // salary[0].Credit_Date__c = Date.today();
            return salary[0];
        }
        
        return null;
    }

    @AuraEnabled(cacheable=true)
    public static Earning__c getEarning(String fy, Integer month){
        try {
            String[] years = fy.split('-');
            Integer year = month <= 3 ? Integer.valueOf(years[1]) : Integer.valueOf(years[0]);
            Date sdt = Date.newInstance(year, month, 25);
            Date edt = sdt.addDays(15);
            List<Earning__c> earnings = new List<Earning__c>(
                [
                    SELECT Id, Credit_Date__c, Basic__c, Conveyance__c, Food_Allowance__c, EPF_Contribution__c, Fiscal_Year__c,
                    HRA__c, Income_Tax__c, Labor_Welfare_Fund__c, LTA__c, Medical_Allowance__c, Professional_Tax__c,
                    Project_Allowance__c, Bonus__c, Telephone_Allowance__c
                    FROM Earning__c
                    WHERE Credit_Date__c >= :sdt AND Credit_Date__c <= :edt
                ]
            );
            if(!earnings.isEmpty()) {
                return earnings[0];
            }
            return null;
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Investment__c> getAllInvestmentByBank(String bankName) {
        return DataProvider.getAllInvestments(bankName);
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<Investment__c>> getAllInvestMentMap() {
        return DataProvider.invetmentByBank();
    }

    @AuraEnabled(cacheable=true)
    public static List<DataProvider.FutureInvestmentWrapper> getAllFutureInvestments() {
        return DataProvider.getAllFutureInvestments();
    }

    @AuraEnabled
    public static String postFutureInvestment(String formData) {
        try {
            Map<String, Object> fieldValueMap = (Map<String, Object>)JSON.deserializeUntyped(formData);
            System.debug('inside post future investment *** '+formData);
            System.debug('inside post future ***** : '+fieldValueMap.get('contributionAmount'));
            String bank = String.valueOf(fieldValueMap.get('bank'));
            Investment__c ivt = [SELECT Id, Amount__c FROM Investment__c WHERE Bank__c =: bank AND Account_Number__c IN ('1893PPF0000000138', '110168495351') LIMIT 1];
            Investment_Line_Items__c lineItem = new Investment_Line_Items__c();
            lineItem.Investment__c = ivt.Id;
            lineItem.Date__c = Date.valueOf(String.valueOf(fieldValueMap.get('contributionDate')));
            lineItem.Amount__c = Decimal.valueOf(String.valueOf(fieldValueMap.get('contributionAmount')));
            lineItem.Type__c = 'Re-invest';
            insert lineItem;
            ivt.Amount__c += lineItem.Amount__c;
            update ivt;
            return 'success';
        }catch(Exception exp) {
            throw new AuraHandledException('Record Saving Failed '+exp.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<DataProvider.StockWrapper> getAllStocks() {
        return DataProvider.getAllStocks();
    }

    @AuraEnabled
    public static String manageStock(String stockData) {
        try {
            System.debug('inside managestock server....');
            Investment_Line_Items__c ivtLineItem = (Investment_Line_Items__c)JSON.deserialize(stockData, Investment_Line_Items__c.Class);
            System.debug('investmentLine Iten**** : '+ivtLineItem);
            insert ivtLineItem;
            return 'success';
        }catch(Exception exp) {
            throw new AuraHandledException(exp.getMessage());
        }
    }

    @AuraEnabled
    public static String createStock(String stockData) {
        try {
            Investment__c ivt = (Investment__c) JSON.deserialize(stockData, Investment__c.Class);
            Id stockRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName().get('Stock').getRecordTypeId();
            ivt.RecordTypeId = stockRT;
            ivt.Total_Buy__c = 0;
            System.debug('Investment*** : '+ivt);
            insert ivt;
            return 'success';
        }catch(Exception exp) {
            throw new AuraHandledException(exp.getMessage());
        }
    }
}