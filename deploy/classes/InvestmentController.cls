/***
 * @description This a Server side controller to handle all the Investment requests
*/
public with sharing class InvestmentController {
    static Date fyStartDate;
    static Date fyEndDate;
    static Set<String> integerFields = new Set<String> {'Amount__c', 'Tenure_Day__c', 'Tenure_Mnt__c', 'Tenure_Yr__c'};
    static Set<String> decimalFields = new Set<String> {'Rate__c', 'TDS_Deducted__c'};
    static Set<String> dateFields = new Set<String> {'Date__c'};
    static Set<String> booleanFields = new Set<String> {'IS_TDS__c'};
    static final String RE_INVEST = 'Re-Invest';
    static final String CLOSE = 'Close';

    public class CustomException extends Exception{}

    /* 
        @description Convet String date to Date Object date format should be yyyy-mm-dd
    */
    private static Date getDateValue(String dateString) {
        List<String> dateArray = String.valueOf(dateString).split('-');
        Integer year = Integer.valueOf(dateArray[0]);
        Integer month = Integer.valueOf(dateArray[1]);
        Integer day = Integer.valueOf(dateArray[2]); 
        return Date.newInstance(year, month, day);
    }
    
    /***
     * @description populate nessasary fields on the line Item during data post
     **/ 
    private static Investment_Line_Items__c updateLineItem(Investment_Line_Items__c lineItem) {        
        Investment__c currentIvt = DataProvider.getInvestment(lineItem.Investment__c);
        lineItem.Rate__c = currentIvt.Rate__c;
        lineItem.Tenure_Yr__c = currentIvt.Year__c != null ? currentIvt.Year__c : 0;
        lineItem.Tenure_Mnt__c = currentIvt.Month__c != null ? currentIvt.Month__c : 0;
        lineItem.Tenure_Day__c = currentIvt.Day__c != null ? currentIvt.Day__c : 0;
        lineItem.Expected_Maturity__c = currentIvt.Maturity_Amount__c;
        lineItem.Principle__c = currentIvt.Amount__c;
        lineItem.Investment_Date__c = currentIvt.Start_Date__c;
        lineItem.Maturity_Date__c = currentIvt.Maturity_Date__c;
        lineItem.Bank__c = currentIvt.Bank__c;
        return lineItem;
    }

    /***
     * @description populate nessasary fields on the Investment during data post
     **/ 
    private static Investment__c updateInvestment(Investment_Line_Items__c lineItem, String data) {
        Map<String, Object> lineItemObj = (Map<String, Object>) JSON.deserializeUntyped(data);
        Investment__c ivt = new Investment__c(Id = lineItem.Investment__c);
        ivt.Amount__c = lineItem.Amount__c;
        ivt.Start_Date__c = lineItem.Date__c;
        ivt.Rate__c = Decimal.valueOf(lineItemObj.get('Rate__c').toString());
        ivt.Year__c = lineItem.Tenure_Yr__c;
        ivt.Month__c = lineItem.Tenure_Mnt__c;
        ivt.Day__c = lineItem.Tenure_Day__c;
        return ivt;
    }

    /***
     * @description create lineitem record with the posted data
     **/ 
    private static Investment_Line_Items__c createIvtLineItem(String ivtId, String data) {
        
        Investment_Line_Items__c lineItem = new Investment_Line_Items__c(Investment__c = ivtId);
        Map<String, Object> lineItemObj = (Map<String, Object>) JSON.deserializeUntyped(data);
        
        // Construct lineItem Object
        for(String fieldApiName : lineItemObj.keySet()) {
            Object fieldValue = lineItemObj.get(fieldApiName);
            if(fieldValue != null && fieldValue != '') {
                if(integerFields.contains(fieldApiName)) {
                    lineItem.put(fieldApiName, Integer.valueOf(fieldValue));
                }else if(decimalFields.contains(fieldApiName)) {
                    lineItem.put(fieldApiName, Decimal.valueOf(fieldValue.toString()));
                }else if(dateFields.contains(fieldApiName)) {
                    lineItem.put(fieldApiName, getDateValue(String.valueOf(fieldValue)));
                }else if(booleanFields.contains(fieldApiName)) {
                    lineItem.put(fieldApiName, (Boolean) fieldValue);
                }else {
                    lineItem.put(fieldApiName, String.valueOf(fieldValue));
                }
            }
        }
        
        lineItem = updateLineItem(lineItem);

        return lineItem;
    }

    /***
     * @description check if the PPFLimit is execeeded for this investment
     **/ 
    private static Boolean isPPFLimitExceeded(Investment__c ivt) {
        return false;

        /* List<Investment_Line_Items__c> currentFyInvestments = DataProvider.getThisFYLineItems(ivt);
        Decimal totalAmount = ivt.Amount__c;
        System.debug('totalamout*** : '+totalAmount);
        System.debug('currentFyInvestments*** : '+currentFyInvestments);
        for(Investment_Line_Items__c lineItem : currentFyInvestments) {
            totalAmount += lineItem.Amount__c;
        }
        System.debug('totalamout after*** : '+totalAmount);

        Boolean isLimitExceeded = totalAmount > 150000 ? true : false;

        return isLimitExceeded; */
    }

    /***
     * @description handle posted data from lwc
     **/ 
    @AuraEnabled
    public static String postData(String data, String recordId, Boolean isPPF) {
        Investment__c ivt = new Investment__c(Id = recordId);
        Investment_Line_Items__c lineItem = createIvtLineItem(recordId, data);

        if(lineItem.Type__c.equalsIgnoreCase(RE_INVEST)) {
            ivt = updateInvestment(lineItem, data);
        }else {
            ivt.Is_Closed__c = true;
        }

        if(isPPF) {
            if(isPPFLimitExceeded(ivt)) {
                throw new CustomException('You can not deposite more than 1.5L in a FY');
            }
            ivt.Amount__c = ivt.Amount__c + lineItem.Principle__c;
            ivt.Year__c = 2038 - Date.today().year();
            System.debug('inside year today*** : '+Date.today().year());
            System.debug('ivt.Year__c*** : '+ivt.Year__c);
        }

        try {
            update ivt;
            insert lineItem; 
        }catch(Exception exp) {
            throw exp;
        }

        return JSON.serialize(ivt) + ' ****** '+ JSON.serialize(lineItem);
    }

    @AuraEnabled
    public static void deleteFile(String fileName, String recordId) {
        System.debug('inside deleteFiles**** : '+fileName + ' recordId*** '+recordId);
        List<Id> docsToDelete = new List<Id>();
        for(ContentDocumentLink conDocLink : [SELECT Id, ContentDocumentId FROM ContentDocumentLink WHERE LinkedEntityId =: recordId]) {
            docsToDelete.add(conDocLink.ContentDocumentId);
        }

        delete [SELECT Id FROM ContentDocument WHERE Id IN : docsToDelete];
        /* List<ContentVersion> conVers = new List<ContentVersion>([
            SELECT Id FROM ContentVersion WHERE Title
        ]) */
    }

    @AuraEnabled(cacheable=true)
    public static Investment__c getinvestment(String recordId) {
        return DataProvider.getInvestment(recordId);
    }

    @AuraEnabled(cacheable=true)
    public static List<Investment__c> getInvestments(String selectedValue){
        try {
            Date today = Date.today();
            Date startDateOfMonth = today.toStartOfMonth();
            Date endDateOfMonth = today.addMonths(1).toStartOfMonth().addDays(-1);
            Integer addMonth;
            switch on selectedValue {
                when 'Last 6 Months' {
                    addMonth = -6;
                }

                when 'Last 1 Year' {
                    addMonth = -12;
                }

                when else {
                    addMonth = -3;
                }
            }
            Date targetDate = startDateOfMonth.addMonths(addMonth);

            return DataProvider.getInvestments(targetDate, endDateOfMonth);

        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Decimal> getFYIntrest(String fy){
        initFYRange(fy);
        Map<String, List<Investment__c>> ivtByBank = DataProvider.invetmentByBank();
        Map<String, Decimal> intrestMap = new Map<String, Decimal>();
        Decimal totalInterest = 0;
        for(String bankname : ivtByBank.keySet()) {
            intrestMap.put(bankname.toUpperCase(), totalInterest(ivtByBank.get(bankname)));
            totalInterest += intrestMap.get(bankname.toUpperCase()); 
        }
        intrestMap.put('Total', totalInterest);
        return intrestMap;
    }

    @AuraEnabled(cacheable=true)
    public static List<FyWrapper> getFdReport(String fy, String bank) {
        System.debug('fiscal year*** : '+fy);
        System.debug('bank*** : '+bank);
        List<FyWrapper> result = new List<FyWrapper>();
        initFYRange(fy);
        List<Investment__c> ivts = DataProvider.getAllInvestments(bank);
        Decimal totalInterest = 0;
        for(Investment__c ivt : ivts) {
            Integer noOfMnth = totalNoOfMnthsForFY(ivt);
            if(noOfMnth <= 0) {
                continue;
            }
            Decimal intrPermonths = intrestPM(ivt);
            Decimal intr = noOfMnth*intrPermonths;
            totalInterest += intr;
            FyWrapper fyw = new FyWrapper();
            fyw.recordId = ivt.Id;
            fyw.acno = ivt.Account_Number__c;
            fyw.startDate = String.valueOf(ivt.Start_Date__c.format());
            fyw.endDate = String.valueOf(ivt.Maturity_Date__c.format());
            fyw.roi = ivt.Rate__c;
            fyw.principle = ivt.Amount__c;
            fyw.maturity = ivt.Maturity_Amount__c;
            fyw.fyTenure = noOfMnth;
            fyw.fyintPM = intrPermonths.setScale(2);
            fyw.fyIntrest = intr.setScale(2);
            fyw.tds = intr*0.10;
            fyw.tds = fyw.tds.setScale(2);
            result.add(fyw);
        }

        for(FyWrapper obj : result) {
            if(totalInterest <= 40000) {
                obj.tds = 0;
            }
        }
        return result;
    }

    private static void initFYRange(String fy) {
        List<String> arr = fy.split('-');
        Integer fyStartYr = Integer.valueOf(arr.get(0));
        Integer fyEndYr = Integer.valueOf(arr.get(1));
        fyStartDate = Date.newInstance(fyStartYr, 04, 01);
        fyEndDate = Date.newInstance(fyEndYr, 03, 31);
    }

    private static Decimal totalInterest(List<Investment__c> allIvts) {
        Decimal totalInts = 0;
        for(Investment__c eachIvt : allIvts) {
            Integer noOfMonths = totalNoOfMnthsForFY(eachIvt);
            Decimal intrPermonths = intrestPM(eachIvt);
            Decimal intr = noOfMonths*intrPermonths;
            totalInts += intr;
        }

        totalInts = totalInts.setScale(2);
        return totalInts;
    }

    private static Integer totalNoOfMnthsForFY(Investment__c ivt) {
        Date counterDate = ivt.Start_Date__c <= fyStartDate ? fyStartDate : ivt.Start_Date__c;
        Integer noOfMnth = 0;
        While(counterDate <= fyEndDate && counterDate < ivt.Maturity_Date__c) {
            noOfMnth++;
            counterDate = counterDate.addMonths(1);
        }
        return noOfMnth;
    }

    private static Decimal intrestPM(Investment__c ivt) {
        System.debug('ivt**** : '+ivt);
        Decimal termIntr = ivt.Maturity_Amount__c - ivt.Amount__c;
        Integer extraMonth = ivt.Day__c == null || ivt.Day__c == 0 ? 0 : 1;
        ivt.Year__c = (ivt.Year__c == null) ? 0 : ivt.Year__c;
        ivt.Month__c = (ivt.Month__c == null) ? 0 : ivt.Month__c;
        Decimal totaltermMths = (ivt.Year__c*12) + ivt.Month__c + extraMonth;
        Decimal perMthsIntr = termIntr / totaltermMths;
        return perMthsIntr;
    }

    public class FyWrapper {
        @AuraEnabled public Id recordId;
        @AuraEnabled public String acno;
        //@AuraEnabled public Date startDate;
        @AuraEnabled public String startDate;
        //@AuraEnabled public Date endDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public Decimal roi;
        @AuraEnabled public Integer fyTenure;
        @AuraEnabled public Decimal fyintPM;
        @AuraEnabled public Decimal fyIntrest;
        @AuraEnabled public Decimal principle;
        @AuraEnabled public Decimal maturity;
        @AuraEnabled public Decimal tds;
        
        public FyWrapper() {}
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, String> allReinvestedAccounts(String recordId) {
        Investment__c investment = DataProvider.getInvestment(recordId);
        String bankName = investment.Bank__c;
        Map<String, String> investmentById = new Map<String, String>();
        for(Investment__c ivt : DataProvider.getAllInvestments(bankname)) {
            if(ivt.Re_invested_Count__c != null && ivt.Re_invested_Count__c > 0) {
                investmentById.put(ivt.Account_Number__c, ivt.Id);
            }
        }

        return investmentById;
    }

    @AuraEnabled(cacheable=true) 
    public static Investment__c getInvestmentWithLines(String investmentId){
        return DataProvider.getInvestmentWithAllLineItems(investmentId);
    }
}