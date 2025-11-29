public with sharing class ExpenseManagerUtilHelper {
    public ExpenseManagerUtilHelper() {

    }

    public static Decimal calculateInterest(Investment_Line_Items__c lineItem, Date startDate, Date endDate) {
        Decimal interest = 0;
        Decimal tdsDeducted = lineItem.TDS_Deducted__c != null ? lineItem.TDS_Deducted__c : 0;
        if(lineItem.Investment_Date__c >= startDate && lineItem.Maturity_Date__c <= endDate) {
            interest = lineItem.Incurred_Interest__c+tdsDeducted;
        }else {
            Integer totalTermDays = lineItem.Investment_Date__c.daysBetween(lineItem.Maturity_Date__c);
            Decimal totalInterest =  (lineItem.Amount__c - lineItem.Principle__c) + tdsDeducted;
            Decimal perDayInterest = totalInterest / totalTermDays;
            Integer applicableDays;
            if(lineItem.Investment_Date__c < startDate) {
                applicableDays = lineItem.Maturity_Date__c <= endDate ? 
                    startDate.daysBetween(lineItem.Maturity_Date__c) : startDate.daysBetween(endDate);

            }else if(lineItem.Investment_Date__c >= startDate) {
                applicableDays = lineItem.Maturity_Date__c <= endDate ? 
                    lineItem.Investment_Date__c.daysBetween(lineItem.Maturity_Date__c) : lineItem.Investment_Date__c.daysBetween(endDate);
            }
            lineItem.Investment_Date__c.daysBetween(endDate);
            interest = applicableDays * perDayInterest;
        }

        return interest != null ? interest.setScale(2) : 0;
    }

    public static Decimal calculateAccumlatedInterest(Investment__c ivt, Date fyStart, Date fyEnd) {
        Decimal accumulatedInt;
        Integer termDays = ivt.Maturity_Date__c.daysBetween(ivt.Start_Date__c);
        Decimal perDayInt = (ivt.Maturity_Amount__c - ivt.Amount__c) / termDays;
        if(ivt.Start_Date__c >= fyStart && ivt.Maturity_Date__c <= fyEnd) {
            accumulatedInt = ivt.Maturity_Amount__c - ivt.Amount__c;
        }else if(ivt.Start_Date__c < fyStart && ivt.Maturity_Date__c <= fyEnd){
            Integer daysDiff1 = ivt.Maturity_Date__c.daysBetween(fyStart);
            accumulatedInt = daysDiff1 * perDayInt;
        }else if(ivt.Start_Date__c < fyStart && ivt.Maturity_Date__c >= fyEnd) {
            Integer daysDiff1 = fyEnd.daysBetween(fyStart);
            accumulatedInt = daysDiff1 * perDayInt;
        }else if(ivt.Start_Date__c > fyStart && ivt.Maturity_Date__c >= fyEnd) {
            Integer daysDiff1 = fyEnd.daysBetween(ivt.Start_Date__c);
            accumulatedInt = daysDiff1 * perDayInt;
        }

        return accumulatedInt.setScale(2);
    }

    public static Map<String, List<Investment__c>> getInvestmentByBank(Date startDate, Date endDate) {
        Map<String, List<Investment__c>> investmentByBank = new Map<String, List<Investment__c>>();
        List<Investment__c> allInvestments = DataProvider.getInvestments(startDate, endDate);
        for(Investment__c ivt : allInvestments) {
            if(investmentByBank.containsKey(ivt.Bank__c)) {
                investmentByBank.get(ivt.Bank__c).add(ivt);
            }else {
                investmentByBank.put(ivt.Bank__c, new List<Investment__c>{ivt});
            }
        }

        return investmentByBank;
    }

    public static Map<String, List<Investment_Line_Items__c>> getInvestmentLinesByBank(Date startDate, Date endDate) {
        Map<String, List<Investment_Line_Items__c>> investmentLinesByBank = new Map<String, List<Investment_Line_Items__c>>();
        List<Investment_Line_Items__c> lines = DataProvider.getAllLines(startDate, endDate);
        
        for(Investment_Line_Items__c ivtLine : lines) {
            String key = ivtLine.Investment__r.Bank__c;
            if(investmentLinesByBank.containsKey(key)) {
                investmentLinesByBank.get(key).add(ivtLine);
            }else {
                investmentLinesByBank.put(key, new List<Investment_Line_Items__c>{ivtLine});
            }
        }

        return investmentLinesByBank;
    } 

    public static List<InterestWrapper> processInvestmentLines(List<Investment__c> allInvestments, List<Investment_Line_Items__c> lines, Date startDate, Date endDate, String bankName) {
        Map<String, Decimal> alreadyPaidIntByAcct = new Map<String, Decimal>();
        // tdsByAccountNumber having no use, as we are dynamically calculating the 10% tds based on the earned interest.
        Map<String, Decimal> tdsByAccountNumber = new Map<String, Decimal>();
        Map<String, Decimal> accumulatedInterest = new Map<String, Decimal>();
        Map<String, String> accountNumberById = new Map<String, String>();
        Map<String, InterestWrapper> wrapperByAccountMap = new Map<String, InterestWrapper>();

        for(Investment_Line_Items__c line : lines) {
            String accountNumber = line.Investment__r.Account_Number__c;
            Decimal interest = calculateInterest(line, startDate, endDate);
            if(alreadyPaidIntByAcct.containsKey(accountNumber)) {
                interest += alreadyPaidIntByAcct.get(accountNumber);
            }
            alreadyPaidIntByAcct.put(accountNumber, interest);
            Decimal tds = interest * 0.10;
            if(tdsByAccountNumber.containsKey(accountNumber)) {
                tds += tdsByAccountNumber.get(accountNumber);
            }
            tdsByAccountNumber.put(accountNumber, tds);
            accountNumberById.put(accountNumber, line.Investment__r.Id);
        }

        for(Investment__c ivt : allInvestments) {
            String accountNumber = ivt.Account_Number__c;
            Decimal interest = calculateAccumlatedInterest(ivt, startDate, endDate);
            accumulatedInterest.put(accountNumber, interest);
            Decimal tds = interest * 0.10;
            if(tdsByAccountNumber.containsKey(accountNumber)) {
                tds += tdsByAccountNumber.get(accountNumber);
            }
            tdsByAccountNumber.put(accountNumber, tds);
            accountNumberById.put(accountNumber, ivt.Id);
        }

        for(String key : alreadyPaidIntByAcct.keySet()) {
            Decimal tds = tdsByAccountNumber.get(key);
            Decimal paidInterest = alreadyPaidIntByAcct.get(key);
            String recordId = accountNumberById.get(key);
            InterestWrapper iwrapper = new InterestWrapper(key, bankName, paidInterest, tds, recordId);
            wrapperByAccountMap.put(key, iwrapper);
        }

        for(String key : accumulatedInterest.keySet()) {
            InterestWrapper tempWrapper;
            Decimal accIntr = accumulatedInterest.get(key);
            String recordId = accountNumberById.get(key);
            if(wrapperByAccountMap.containsKey(key)) {
                tempWrapper = wrapperByAccountMap.get(key);
                tempWrapper.accumulatedInteres = accIntr;
            }else {
                Decimal tds = tdsByAccountNumber.get(key);
                tempWrapper = new InterestWrapper(key, bankName, accIntr, recordId, tds);
            }
            wrapperByAccountMap.put(key, tempWrapper);
        }

        for(String key : wrapperByAccountMap.keySet()) {
            InterestWrapper iwr = wrapperByAccountMap.get(key);
            iwr.accumulatedInteres = iwr.accumulatedInteres != null ? iwr.accumulatedInteres : 0;
            iwr.interestPaid = iwr.interestPaid != null ? iwr.interestPaid : 0;
            Decimal totalInterest = iwr.accumulatedInteres + iwr.interestPaid;
            Decimal totalTDS = totalInterest * 0.10;
            iwr.tds = totalTDS;
        }
        return wrapperByAccountMap.values();
    }

    public class InterestWrapper {
        @AuraEnabled public String accountNumber {get; set;}
        @AuraEnabled public String bankName {get; set;}
        @AuraEnabled public Decimal accumulatedInteres {get; set;}
        @AuraEnabled public Decimal interestPaid {get; set;}
        @AuraEnabled public Decimal tds {get; set;}
        @AuraEnabled public Id recordId {get; set;}
        
        public InterestWrapper(InterestWrapper iwrapper, Decimal accumulatedInteres) {
            iwrapper.accumulatedInteres = accumulatedInteres;
        }

        public InterestWrapper(String accountNumber, String bankName, Decimal interestPaid, Decimal tds, String recordId) {
            this.accountNumber = accountNumber;
            this.bankName = bankName;
            this.interestPaid = interestPaid;
            this.tds = tds != null ? tds : 0;
            this.recordId = recordId;
        }

        public InterestWrapper(String accountNumber, String bankName, Decimal accumulatedInteres, String recordId, Decimal tds) {
            this.accountNumber = accountNumber;
            this.bankName = bankName;
            this.accumulatedInteres = accumulatedInteres;
            this.recordId = recordId;
            this.tds = tds;
        }
    }

    public static Map<String, List<OneViewWrapper>> getOneViewMap(Date sDate, Date eDate, String fiscalYear) {
        Map<String, List<OneViewWrapper>> resultMap = new Map<String, List<OneViewWrapper>>();
        List<Earning__c> earnings = DataProvider.getEarnings(fiscalYear);
        Integer numbersOfSalary = 0;
        Decimal totalSalary = 0;
        for(Earning__c earning : earnings) {
            numbersOfSalary++;
            totalSalary += earning.Net_In_Hand__c;
        }
        OneViewWrapper salary = new OneViewWrapper('Salary', totalSalary);
        resultMap.put('Earning', new List<OneViewWrapper> { salary }); //Earning From Salary
        OneViewWrapper pluxee = new OneViewWrapper('Food Card', numbersOfSalary*2000);
        resultMap.get('Earning').add(pluxee);

        Decimal totalExpenses = 0;
        for(Expense__c exp : DataProvider.getAllExpense(sDate, eDate)) {
            totalExpenses += exp.Total_Expense__c;
        }
        OneViewWrapper expense = new OneViewWrapper('Expense', totalExpenses);
        resultMap.put('Expense', new List<OneViewWrapper> { expense }); //Total Expenses

        Decimal totalTreasures = 0;
        List<Treasure__c> treasures = DataProvider.getAllTresures(sDate, eDate);
        for(Treasure__c treasure : treasures) {
            if(!treasure.FD_Breakage__c) {
                totalTreasures += treasure.Amount__c;
            }
        }
        OneViewWrapper treasure = new OneViewWrapper('Tresure', totalTreasures);
        resultMap.put('Investment', new List<OneViewWrapper> { treasure }); //Investment Via Treasure

        Decimal totalPPF = 0;
        Decimal totalNPS = 0;
        List<Investment_Line_Items__c> ppfNps = DataProvider.getAllPPFNPSContributions(sDate, eDate);
        for(Investment_Line_Items__c line : ppfNps) {
            if(line.Investment__r.Bank__c == 'PPF') {
                totalPPF += line.Amount__c;
            }else {
                totalNPS += line.Amount__c;
            }
        }
        OneViewWrapper ppf = new OneViewWrapper('PPF', totalPPF);
        OneViewWrapper nps = new OneViewWrapper('NPS', totalNPS);
        resultMap.get('Investment').add(ppf);
        resultMap.get('Investment').add(nps);
        return resultMap;
    }

    public class OneViewWrapper {
        @AuraEnabled
        public String type;
        @AuraEnabled
        public Decimal amount;
        
        public OneViewWrapper(String type, Decimal amount) {
            this.type = type;
            this.amount = amount;
        }
    }

    public static List<Date> getFiscalYear(Date dt) {
        Date today = Date.today();
        Integer year = today.year();
        Integer month = today.month();
        List<Date> fiscalYearDates = new List<Date>();
        Date fyStart;
        Date fyEnd;
        if (month >= 4) {
            fyStart = Date.newInstance(year, 4, 1);
            fyEnd   = Date.newInstance(year + 1, 3, 31);
        } else {
            fyStart = Date.newInstance(year - 1, 4, 1);
            fyEnd   = Date.newInstance(year, 3, 31);
        }
        fiscalYearDates.add(fyStart);
        fiscalYearDates.add(fyEnd);
        return fiscalYearDates;
    }
}