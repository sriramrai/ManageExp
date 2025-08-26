public with sharing class ExpenseManagerUtilHelper {
    public ExpenseManagerUtilHelper() {

    }

    public static Decimal calculateInterest(Investment_Line_Items__c lineItem, Date startDate, Date endDate) {
        Decimal interest = 0;
        if(lineItem.Investment_Date__c >= startDate) {
            interest = lineItem.Incurred_Interest__c+lineItem.TDS_Deducted__c;
        }else {
            Integer daysBetween = lineItem.Investment_Date__c.daysBetween(startDate);
            Integer totalTermDays = lineItem.Investment_Date__c.daysBetween(lineItem.Maturity_Date__c);
            Decimal totalInterest = lineItem.Incurred_Interest__c != null ? (lineItem.Incurred_Interest__c + lineItem.TDS_Deducted__c) : lineItem.Amount__c - lineItem.Principle__c;
            Decimal perDayInterest = totalInterest / totalTermDays;
            Integer applicableDays = startDate.daysBetween(lineItem.Maturity_Date__c);
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

    public static List<InterestWrapper> processInvestmentLines(List<Investment__c> allInvestments, List<Investment_Line_Items__c> lines, Date startDate, Date endDate, String bankName) {
        Map<String, Decimal> alreadyPaidIntByAcct = new Map<String, Decimal>();
        Map<String, Decimal> tdsByAccountNumber = new Map<String, Decimal>();
        Map<String, Decimal> accumulatedInterest = new Map<String, Decimal>();

        for(Investment_Line_Items__c line : lines) {
            String accountNumber = line.Investment__r.Account_Number__c;
            Decimal interest = ExpenseManagerUtilHelper.calculateInterest(line, startDate, endDate);
            if(alreadyPaidIntByAcct.containsKey(accountNumber)) {
                interest += alreadyPaidIntByAcct.get(accountNumber);
            }
            alreadyPaidIntByAcct.put(accountNumber, interest);
            tdsByAccountNumber.put(accountNumber, line.TDS_Deducted__c);
        }

        System.debug('tdsByAccountNumber***** : '+JSON.serialize(tdsByAccountNumber));
        System.debug('alreadyPaidIntByAcct***** : '+JSON.serialize(alreadyPaidIntByAcct));

        for(Investment__c ivt : allInvestments) {
            String accountNumber = ivt.Account_Number__c;
            Decimal interest = ExpenseManagerUtilHelper.calculateAccumlatedInterest(ivt, startDate, endDate);
            accumulatedInterest.put(accountNumber, interest);
        }
        System.debug('accumulatedInterest***** : '+JSON.serialize(accumulatedInterest));

        Map<String, InterestWrapper> wrapperByAccountMap = new Map<String, InterestWrapper>();
        for(String key : alreadyPaidIntByAcct.keySet()) {
            Decimal tds = tdsByAccountNumber.get(key);
            Decimal paidInterest = alreadyPaidIntByAcct.get(key);
            InterestWrapper iwrapper = new InterestWrapper(key, bankName, paidInterest, tds);
            wrapperByAccountMap.put(key, iwrapper);
        }
        System.debug('wrapperByAccountMap***** : '+JSON.serialize(wrapperByAccountMap));

        for(String key : accumulatedInterest.keySet()) {
            InterestWrapper tempWrapper;
            Decimal accIntr = accumulatedInterest.get(key);
            if(wrapperByAccountMap.containsKey(key)) {
                tempWrapper = wrapperByAccountMap.get(key);
                tempWrapper.accumulatedInteres = accIntr;
            }else {
                tempWrapper = new InterestWrapper(key, bankName, accIntr);
            }
            wrapperByAccountMap.put(key, tempWrapper);
        }

        return wrapperByAccountMap.values();

        /* Map<String, List<InterestWrapper>> wrapperMap = new Map<String, List<InterestWrapper>>();
        for(InterestWrapper iwp : wrapperByAccountMap.values()) {
            String key = iwp.bankName;
            if(wrapperMap.containsKey(key)) {
                wrapperMap.get(key).add(iwp);
            }else {
                wrapperMap.put(key, new List<InterestWrapper> {iwp});
            }
        } */
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
}