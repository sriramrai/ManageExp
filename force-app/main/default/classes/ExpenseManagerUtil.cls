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
}