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
        fy = '2024-2025';
        List<Date> fyDates = constructFyDate(fy);
        List<String> fiscalYears = fy.split('-');
        Date startDate = fyDates[0];
        Date endDate = fyDates[1];
        System.debug('start Date*** : '+startDate);
        System.debug('End Date**** : '+endDate);
        List<Investment_Line_Items__c> lines = DataProvider.getAllLines(startDate, endDate);
        System.debug('lines*** : '+JSON.serialize(lines));
        List<Investment__c> allInvestments = DataProvider.getInvestments(startDate, endDate);
        
        Map<String, List<Investment_Line_Items__c>> investmentLinesByBank = new Map<String, List<Investment_Line_Items__c>>();
        Map<String, List<Investment__c>> investmentByBank = new Map<String, List<Investment__c>>();
        for(Investment_Line_Items__c ivtLine : lines) {
            String key = ivtLine.Investment__r.Bank__c;
            if(investmentLinesByBank.containsKey(key)) {
                investmentLinesByBank.get(key).add(ivtLine);
            }else {
                investmentLinesByBank.put(key, new List<Investment_Line_Items__c>{ivtLine});
            }
        }
        for(Investment__c ivt : allInvestments) {
            if(investmentByBank.containsKey(ivt.Bank__c)) {
                investmentByBank.get(ivt.Bank__c).add(ivt);
            }else {
                investmentByBank.put(ivt.Bank__c, new List<Investment__c>{ivt});
            }
        }
        System.debug('investmentLinesByBank***** : '+JSON.serialize(investmentLinesByBank));
        System.debug('investmentByBank*** : '+JSON.serialize(investmentByBank));
        Map<String, List<ExpenseManagerUtilHelper.InterestWrapper>> wrapperMap = new Map<String, List<ExpenseManagerUtilHelper.InterestWrapper>>();
        for(String bank : investmentByBank.keySet()) {
            List<Investment_Line_Items__c> lineItems = new List<Investment_Line_Items__c>(investmentLinesByBank.get(bank));
            List<Investment__c> investments = new List<Investment__c>(investmentByBank.get(bank));
            List<ExpenseManagerUtilHelper.InterestWrapper> wrapperList = new List<ExpenseManagerUtilHelper.InterestWrapper>();
            System.debug('investments*** : '+investments.size());
            System.debug('lineItems*** : '+lineItems.size());
            wrapperList = ExpenseManagerUtilHelper.processInvestmentLines(investments, lineItems, startDate, endDate, bank);
            System.debug('bank**** : '+bank);
            System.debug('WrapperList '+JSON.serialize(wrapperList));
            wrapperMap.put(bank, wrapperList);
        }
        
        return wrapperMap;
    }

    public class InterestWrapper {
        @AuraEnabled public String accountNumber {get; set;}
        @AuraEnabled public String bankName {get; set;}
        @AuraEnabled public Decimal accumulatedInteres {get; set;}
        @AuraEnabled public Decimal interestPaid {get; set;}
        @AuraEnabled public Decimal tds {get; set;}
        
        public InterestWrapper(InterestWrapper iwrapper, Decimal accumulatedInteres) {
            iwrapper.accumulatedInteres = accumulatedInteres;
        }

        public InterestWrapper(String accountNumber, String bankName, Decimal interestPaid, Decimal tds) {
            this.accountNumber = accountNumber;
            this.bankName = bankName;
            this.interestPaid = interestPaid;
            this.tds = tds != null ? tds : 0;
        }

        public InterestWrapper(String accountNumber, String bankName, Decimal accumulatedInteres) {
            this.accountNumber = accountNumber;
            this.bankName = bankName;
            this.accumulatedInteres = accumulatedInteres;
        }
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
}
