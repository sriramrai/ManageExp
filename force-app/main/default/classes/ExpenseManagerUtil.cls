/* My conne */
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
                    Project_Allowance__c, Bonus__c, Telephone_Allowance__c, Month__c
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

    @AuraEnabled(cacheable = true)
    public static List<Earning__c> getEarnings(String fiscalYear) {
        return DataProvider.getEarnings(fiscalYear);
    }

    private static List<Date> constructFyDate(String fy) {
        List<Date> fyDates = new List<Date>();
        List<String> fiscalYears = fy.split('-');
        Date startDate = Date.newInstance(Integer.valueOf(fiscalYears[0]), 04, 01);
        Date endDate = Date.newInstance(Integer.valueOf(fiscalYears[1]), 03, 31);
        fyDates.add(startDate);
        fyDates.add(endDate);
        return fyDates;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, List<ExpenseManagerUtilHelper.InterestWrapper>> getInterestWrapper(String fy) {
        List<Date> fyDates = constructFyDate(fy);
        List<String> fiscalYears = fy.split('-');
        Date startDate = fyDates[0];
        Date endDate = fyDates[1];

        Map<String, List<Investment_Line_Items__c>> investmentLinesByBank = 
            ExpenseManagerUtilHelper.getInvestmentLinesByBank(startDate, endDate);
        Map<String, List<Investment__c>> investmentByBank = 
            ExpenseManagerUtilHelper.getInvestmentByBank(startDate, endDate);
        Map<String, List<ExpenseManagerUtilHelper.InterestWrapper>> wrapperMap = 
            new Map<String, List<ExpenseManagerUtilHelper.InterestWrapper>>();
        
        for(String bank : investmentByBank.keySet()) {
            List<Investment_Line_Items__c> lineItems = new List<Investment_Line_Items__c>(investmentLinesByBank.get(bank));
            List<Investment__c> investments = new List<Investment__c>(investmentByBank.get(bank));
            List<ExpenseManagerUtilHelper.InterestWrapper> wrapperList = new List<ExpenseManagerUtilHelper.InterestWrapper>();
            wrapperList = ExpenseManagerUtilHelper.processInvestmentLines(investments, lineItems, startDate, endDate, bank);
            wrapperMap.put(bank, wrapperList);
        }
        
        return wrapperMap;
    }

    @AuraEnabled(cacheable = true)
    public static List<Treasure__c> getTreasures(String fy) {
        Date startDate;
        Date endDate;
        if(String.isNotBlank(fy)) {
            List<Date> fiscalYears = constructFyDate(fy);
            startDate = fiscalYears[0];
            endDate = fiscalYears[1];
        }

        return DataProvider.getAllTresures(startDate, endDate);
    }

    @AuraEnabled(cacheable = true)
    public static Map<String, List<ExpenseManagerUtilHelper.OneViewWrapper>> getOneViewWrapper(String fiscalYear) {
        fiscalYear = getCurrentFiscalYear();
        List<Date> fyDates = constructFyDate(fiscalYear);
        Date startDate = fyDates[0];
        Date endDate = fyDates[1];
        return ExpenseManagerUtilHelper.getOneViewMap(startDate, endDate, fiscalYear);
    }

    public static String getCurrentFiscalYear() {
        List<Date> currentFyDates = ExpenseManagerUtilHelper.getFiscalYear(Date.today());
        String currentFy = '';
        currentFy = currentFyDates[0].year() + '-' + (currentFyDates[1].year());
        return currentFy;
    }

    @AuraEnabled(cacheable = true)
    public static Map<String, Decimal> getExpenseByMonth(String fy) {
        // Check if the fiscal year is the current fiscal year
        List<Date> currentFyDates = ExpenseManagerUtilHelper.getFiscalYear(Date.today());
        String currentFy = '';
        
        // Construct current fiscal year string in the same format as passed parameter
        currentFy = currentFyDates[0].year() + '-' + (currentFyDates[1].year());
        // If the requested fiscal year is the current one, get data for last 6 months from today
        if(fy.equals(currentFy)) {
            Date today = Date.today();
            Date todayDate = Date.today();
            Integer lastDay = Date.daysInMonth(todayDate.year(), todayDate.month());
            // toDate current date's last day of month
            Date toDate = Date.newInstance(todayDate.year(), todayDate.month(), lastDay);
            // From Date 6 months ago
            Date fromDate = toDate.addMonths(-5);
            fromDate = Date.newInstance(fromDate.year(), fromDate.month(), 1);
        
            // Get expense data for last 6 months from today
            return DataProvider.getExpenseByMonth(fromDate, toDate);
        } else {
            // For non-current fiscal years, use the existing logic
            List<Date> fyDates = constructFyDate(fy);
            Date startDate = fyDates[0];
            Date endDate = fyDates[1];
            return DataProvider.getExpenseByMonth(startDate, endDate);
        }
    }
}