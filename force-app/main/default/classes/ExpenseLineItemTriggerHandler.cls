public without sharing class ExpenseLineItemTriggerHandler {
    Set<String> applicableSource = new Set<String>{'Axis CC', 'ICICI CC'};
    Integer AXIS_BILLING_DAY = 18;
    Integer ICICI_BILLING_DAY = 24;
    Integer AXIS_DUE_DATE = 7;
    Integer ICIC_DUE_DATE = 10;

    private Date getDueDate(String source, Date expenseDate, Integer termNumber) {
        Integer billingDay = source.equalsIgnoreCase('AXIS CC') ? AXIS_BILLING_DAY : ICICI_BILLING_DAY;
        Integer dueDateDay = source.equalsIgnoreCase('AXIS CC') ? AXIS_DUE_DATE : ICIC_DUE_DATE;
        Integer expenseDay = expenseDate.day();
        Integer expenseMonth = expenseDate.month();
        Integer expenseYear = expenseDate.year();
        Date dueDate = Date.newInstance(expenseYear, expenseMonth, dueDateDay);
        if(expenseDay <= billingDay) {
            dueDate = dueDate.addMonths(termNumber);
        }else {
            dueDate = dueDate.addMonths(termNumber+1);
        }
        return dueDate;
    }

    private List<Payment__c> getPaymentSchedules(Expense_Line_Item__c exp) {
        List<Payment__c> schedules = new List<Payment__c>();
        Integer termLength = Integer.valueOf(exp.EMI_Term__c.split(' ')[0]);
        for(Integer counter = 1; counter <= termLength; counter++) {
            Payment__c payment = new Payment__c();
            payment.Expense_Line_Item__c = exp.Id;
            payment.Amount__c = termLength == 1 ? exp.Amount__c : ((exp.Amount__c/termLength) + ((exp.Amount__c/termLength)*0.16));
            //payment.Payment_Date__c = exp.Date__c;
            payment.Source__c = exp.Source__c;
            payment.Due_Date__c = getDueDate(exp.Source__c, exp.Date__c, counter);
            payment.Description__c = '('+ String.valueOf(counter) + '/' + String.valueOf(termLength) + ') - ' + exp.Details__c;
            schedules.add(payment);
        }
        return schedules;
    }

    private void createPayments(List<Expense_Line_Item__c> newExpenses) {
        List<Payment__c> payments = new List<Payment__c>();
        for(Expense_Line_Item__c exp : newExpenses) {
            payments.addAll(getPaymentSchedules(exp));
        }
        insert payments;
    }

    private void deletePayments(List<Id> lineItemIds) {
        delete [SELECT Id FROM Payment__c WHERE Expense_Line_Item__c IN :lineItemIds];
    }

    public void handleAfterInsert(List<Expense_Line_Item__c> newExpenses) {
        List<Expense_Line_Item__c> creditExpenses = new List<Expense_Line_Item__c>();
        for(Expense_Line_Item__c exp : newExpenses) {
            if(exp.Source__c.equalsIgnoreCase('AXIS CC') || exp.Source__c.equalsIgnoreCase('ICICI CC')) {
                creditExpenses.add(exp);
            }
        }
        createPayments(creditExpenses);
    }

    public void handleAfterUpdate(List<Expense_Line_Item__c> newExpenses, Map<Id, Expense_Line_Item__c> oldMap) {
        List<Expense_Line_Item__c> creditExpenses = new List<Expense_Line_Item__c>();
        List<Id> paymentsToBeDeleted = new List<Id>();
        for(Expense_Line_Item__c newExp : newExpenses) {
            Expense_Line_Item__c oldRecord = oldMap.get(newExp.Id);
            if(oldRecord.Source__c != newExp.Source__c || oldRecord.EMI_Term__c != newExp.EMI_Term__c) {
                paymentsToBeDeleted.add(newExp.Id);
                if(newExp.Source__c.equalsIgnoreCase('AXIS CC') || newExp.Source__c.equalsIgnoreCase('ICICI CC')) {
                    creditExpenses.add(newExp);
                }
            }
        }
        deletePayments(paymentsToBeDeleted);
        createPayments(creditExpenses);
    }

}