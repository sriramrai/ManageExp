/**
 * Purpose: This Data Provider class is responsible to provide the data to all required places
 * Modified On : 03 Sept, to test the CI CD pro
 * Next Push
 */
public without sharing class DataProvider {
  public static Boolean isTestMode() {
    Testing_Switch__c ts = Testing_Switch__c.getInstance();
    if (ts != null) {
      return ts.Test_Mode__c;
    }

    return false;
  }

  public static Investment__c getInvestment(String recordId) {
    return [
      SELECT
        Id,
        Name,
        Account_Number__c,
        Maturity_Amount__c,
        Start_Date__c,
        Amount__c,
        Rate__c,
        Bank__c,
        TAX_SAVER__c,
        Maturity_Date__c,
        Month__c,
        Year__c,
        Day__c,
        Is_Closed__c,
        closed_Date__c
      FROM Investment__c
      WHERE Id = :recordId
    ];
  }

  public static List<Investment__c> getInvestments(
    Date startDate,
    Date endDate,
    String entityName
  ) {
    return new List<Investment__c>(
      [
        SELECT
          Id,
          Name,
          Account_Number__c,
          Maturity_Amount__c,
          Start_Date__c,
          Amount__c,
          Rate__c,
          Bank__c,
          TAX_SAVER__c,
          Maturity_Date__c,
          Month__c,
          Year__c,
          Day__c,
          Is_Closed__c,
          closed_Date__c
        FROM Investment__c
        WHERE
          Start_Date__c <= :endDate
          AND Maturity_Date__c >= :startDate
          AND RecordType.Name != 'Stock'
          AND Bank__c NOT IN ('PPF', 'NPS')
          AND is_Test__c = FALSE
          AND Entity__c = :entityName
        ORDER BY Start_Date__c DESC
      ]
    );
  }

  public static List<FutureInvestmentWrapper> getAllFutureInvestments() {
    List<FutureInvestmentWrapper> wrapperList = new List<FutureInvestmentWrapper>();
    for (Investment__c ivt : [
      SELECT
        Id,
        Start_Date__c,
        Amount__c,
        Account_Number__c,
        Maturity_Date__c,
        Bank__c,
        (
          SELECT Id, Date__c, Amount__c
          FROM Investment_Line_Items__r
          ORDER BY Date__c DESC
        )
      FROM Investment__c
      WHERE
        Bank__c IN ('NPS', 'PPF')
        AND Account_Number__c IN ('1893PPF0000000138', '110168495351')
    ]) {
      FutureInvestmentWrapper fiw = new FutureInvestmentWrapper(ivt);
      wrapperList.add(fiw);
    }
    return wrapperList;
  }

  public static List<Investment__c> getAllInvestments() {
    String query = 'SELECT Id, Name, Account_Number__c, Maturity_Amount__c, Start_Date__c, Amount__c, ';
    query += ' Rate__c, Bank__c, TAX_SAVER__c, Maturity_Date__c, Month__c, Year__c, Day__c, RecordTypeId, RecordType.Name ';
    query += ' FROM Investment__c WHERE Bank__c NOT IN (\'PPF\', \'NPS\') AND RecordType.Name = \'Investment\' AND ';
    if (isTestMode()) {
      query += ' is_Test__c = true';
    } else {
      query += ' is_Test__c = false';
    }

    query += ' AND Is_Closed__c = false ';

    return (List<Investment__c>) Database.query(query);
  }

  public static List<Investment__c> getAllInvestmentsByEntity(
    String entityName
  ) {
    entityName = String.isBlank(entityName) ? 'Sriram' : entityName;
    return new List<Investment__c>(
      [
        SELECT
          Id,
          Name,
          Account_Number__c,
          Maturity_Amount__c,
          Start_Date__c,
          Amount__c,
          Rate__c,
          Bank__c,
          TAX_SAVER__c,
          Maturity_Date__c,
          Month__c,
          Year__c,
          Day__c,
          RecordTypeId,
          RecordType.Name,
          Entity__c
        FROM Investment__c
        WHERE
          Bank__c NOT IN ('NPS', 'PPF')
          AND RecordType.Name = 'Investment'
          AND Entity__c = :entityName
          AND is_closed__c = FALSE
        ORDER BY Bank__c ASC
      ]
    );
  }

  public static List<Investment_Line_Items__c> getAllPPFNPSContributions(
    Date sDate,
    Date eDate
  ) {
    return new List<Investment_Line_Items__c>(
      [
        SELECT Id, Amount__c, Investment__r.Bank__c
        FROM Investment_Line_Items__c
        WHERE
          Date__c >= :sDate
          AND Date__c <= :eDate
          AND Investment__r.Account_Number__c IN (
            '1893PPF0000000138',
            '110168495351'
          )
      ]
    );
  }

  public static List<Investment__c> getAllInvestments(String bankname) {
    String query = 'SELECT Id, Name, Account_Number__c, Maturity_Amount__c, Start_Date__c, Amount__c, ';
    query += ' Rate__c, Bank__c, TAX_SAVER__c, Maturity_Date__c, Month__c, Year__c, Day__c, Re_invested_Count__c ';
    query += ' FROM Investment__c WHERE bank__c =: bankname AND ';
    if (isTestMode()) {
      query += ' is_Test__c = true';
    } else {
      query += ' is_Test__c = false';
    }

    query += ' AND Is_Closed__c = false ';

    return (List<Investment__c>) Database.query(query);
  }

  public static Investment__c getInvestmentWithAllLineItems(String recordId) {
    return [
      SELECT
        Id,
        Account_Number__c,
        Start_Date__c,
        Maturity_Date__c,
        Amount__c,
        Maturity_Amount__c,
        Rate__c,
        (
          SELECT
            Id,
            Investment_Date__c,
            Maturity_Date__c,
            Expected_Maturity__c,
            Principle__c,
            TDS_Deducted__c,
            Rate__c,
            Amount__c
          FROM Investment_Line_Items__r
        )
      FROM Investment__c
      WHERE Id = :recordId
    ];
  }

  public static Map<String, List<Investment__c>> invetmentByBank() {
    Map<String, List<Investment__c>> ivtByBank = new Map<String, List<Investment__c>>();
    List<Investment__c> allInvestments = getAllInvestments();
    for (Investment__c ivt : allInvestments) {
      if (String.isNotBlank(ivt.Bank__c)) {
        String key = ivt.Bank__c.toLowerCase();
        if (ivtByBank.containsKey(key)) {
          ivtByBank.get(key).add(ivt);
        } else {
          List<Investment__c> ivts = new List<Investment__c>{ ivt };
          ivtByBank.put(key, ivts);
        }
      }
    }

    return ivtByBank;
  }

  public static Map<String, List<Investment__c>> invetmentByBank(
    String entityName
  ) {
    Map<String, List<Investment__c>> ivtByBank = new Map<String, List<Investment__c>>();
    List<Investment__c> allInvestments = getAllInvestmentsByEntity(entityName);
    for (Investment__c ivt : allInvestments) {
      if (String.isNotBlank(ivt.Bank__c)) {
        String key = ivt.Bank__c.toLowerCase();
        if (ivtByBank.containsKey(key)) {
          ivtByBank.get(key).add(ivt);
        } else {
          List<Investment__c> ivts = new List<Investment__c>{ ivt };
          ivtByBank.put(key, ivts);
        }
      }
    }

    return ivtByBank;
  }

  @AuraEnabled(cacheable=true)
  public static List<Investment__c> maturityThisMonth(String entityName) {
    Date today = Date.Today();
    Integer lastDay = Date.daysInMonth(today.year(), today.month());
    Date startDate = Date.newInstance(today.year(), today.month(), 1);
    Date endDate = Date.newInstance(today.year(), today.month(), lastDay);
    //endDate = endDate.addMonths(3);
    Id ivtRecordType = Schema.SobjectType.Investment__c.getRecordTypeInfosByName()
      .get('Investment')
      .getRecordTypeId();
    List<Investment__c> ivtList = new List<Investment__c>(
      [
        SELECT Id, Bank__c, Account_Number__c, Maturity_Date__c
        FROM Investment__c
        WHERE
          Maturity_Date__c <= :endDate
          AND Is_Closed__c = FALSE
          AND is_Test__c = :isTestMode()
          AND RecordTypeId = :ivtRecordType
          AND Entity__c = :entityName
      ]
    );
    return ivtList;
  }

  public static List<Investment_Line_Items__c> getThisFYLineItems(
    Investment__c ivt
  ) {
    Date today = Date.Today();
    Integer currentYear = today.year();
    Integer currentMonth = today.month();

    Integer startFyYear = currentMonth <= 3 ? currentYear - 1 : currentYear;
    Date fyStartDate = Date.newInstance(startFyYear, 4, 1);
    Date fyEndDate = Date.newInstance(startFyYear + 1, 3, 31);

    List<Investment_Line_Items__c> lineItems = new List<Investment_Line_Items__c>(
      [
        SELECT Id, Date__c, Amount__c
        FROM Investment_Line_Items__c
        WHERE
          Date__c >= :fyStartDate
          AND Date__c <= :fyEndDate
          AND Investment__c = :ivt.Id
      ]
    );

    return lineItems;
  }

  public static List<Expense__c> getAllExpense(Date sDate, Date eDate) {
    List<Expense__c> expenses = new List<Expense__c>(
      [
        SELECT
          Id,
          Name,
          Start_Date__c,
          End_Date__c,
          Other__c,
          Shivam__c,
          Sriram__c,
          Total_Expense__c
        FROM Expense__c
        WHERE Start_Date__c >= :sDate AND End_Date__c <= :eDate
      ]
    );

    return expenses;
  }

  public static List<Expense__c> getAllExpense() {
    List<Expense__c> expenses = new List<Expense__c>(
      [
        SELECT
          Id,
          Name,
          Start_Date__c,
          End_Date__c,
          Other__c,
          Shivam__c,
          Sriram__c,
          Total_Expense__c
        FROM Expense__c
      ]
    );

    return expenses;
  }

  public static List<Earning__c> getEarnings(String fiscalYear) {
    return [
      SELECT
        Id,
        Fiscal_Year__c,
        Month__c,
        Credit_Date__c,
        Net_In_Hand__c,
        Net_Deduction__c
      FROM Earning__c
      WHERE Fiscal_Year__c = :fiscalYear
      ORDER BY Credit_Date__c DESC
    ];
  }

  public static List<Expense__c> getExpenseByName(String name) {
    List<Expense__c> expenses = new List<Expense__c>(
      [
        SELECT
          Id,
          Name,
          Start_Date__c,
          End_Date__c,
          Other__c,
          Shivam__c,
          Sriram__c,
          Total_Expense__c
        FROM Expense__c
        WHERE Name = :name
      ]
    );

    return expenses;
  }

  public static List<Payment__c> getPayments(Date sDate, Date eDate) {
    Date lastMonthSDate = sDate.addMonths(-1);
    Date nextMonthEDate = eDate.addMonths(1);
    return new List<Payment__c>(
      [
        SELECT
          Id,
          Due_Date__c,
          Purchased_Date__c,
          Amount__c,
          Description__c,
          Payment_Date__c,
          Source__c,
          Settled__c
        FROM Payment__c
        WHERE
          (Due_Date__c >= :sDate
          AND Due_Date__c <= :nextMonthEDate)
          OR (Due_Date__c <= :eDate
          AND Settled__c = FALSE)
      ]
    );
  }

  public static List<Investment__c> getAllStockRecords() {
    Id stockRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName()
      .get('Stock')
      .getRecordTypeId();
    return new List<Investment__c>(
      [
        SELECT Id, Account_Number__c, Code__c, Current_Price__c
        FROM Investment__c
        WHERE RecordTypeId = :stockRT
      ]
    );
  }

  @AuraEnabled(cacheable=true)
  public static List<StockWrapper> getAllStocks() {
    Id stockRT = Schema.SobjectType.Investment__c.getRecordTypeInfosByName()
      .get('Stock')
      .getRecordTypeId();
    List<StockWrapper> stockList = new List<StockWrapper>();
    for (Investment__c ivt : [
      SELECT
        Id,
        Account_Number__c,
        Buyed_Quantity__c,
        Sold_Quantity__c,
        Amount__c,
        Current_Price__c,
        Available_Quantity__c,
        (
          SELECT
            Id,
            Amount__c,
            Buy_Sell__c,
            Exchange__c,
            Quantity__c,
            Date__c,
            Per_Share_Price__c
          FROM Investment_Line_Items__r
          ORDER BY LastmodifiedDate DESC
        )
      FROM Investment__c
      WHERE RecordTypeId = :stockRT
      ORDER BY LastmodifiedDate DESC
    ]) {
      StockWrapper sw = new StockWrapper(ivt);
      stockList.add(sw);
    }

    return stockList;
  }

  public class StockWrapper {
    @AuraEnabled
    public Id recordId { get; set; }
    @AuraEnabled
    public String stockName { get; set; }
    @AuraEnabled
    public Integer totalBuyed { get; set; }
    @AuraEnabled
    public Integer totalSold { get; set; }
    @AuraEnabled
    public Integer quantity { get; set; }
    @AuraEnabled
    public Decimal totalInvested { get; set; }
    @AuraEnabled
    public List<StockLinesWrapper> lines { get; set; }
    @AuraEnabled
    public String recordURL { get; set; }
    @AuraEnabled
    public Decimal currentPrice { get; set; }
    @AuraEnabled
    public Decimal currentValue { get; set; }
    public StockWrapper() {
    }
    public StockWrapper(Investment__c ivt) {
      this.recordId = ivt.Id;
      this.recordURL = '/' + this.recordId;
      this.stockName = ivt.Account_Number__c;
      this.totalBuyed = Integer.valueOf(ivt.Buyed_Quantity__c);
      this.totalSold = Integer.valueOf(ivt.Sold_Quantity__c);
      this.totalInvested = ivt.Amount__c;
      this.quantity = Integer.valueOf(ivt.Available_Quantity__c);
      this.currentPrice = ivt.Current_Price__c;
      //this.currentValue = ivt.Current_Price__c != null && quantity != null ? ivt.Current_Price__c * ivt.Available_Quantity__c : null;
      this.currentValue = ivt.Current_Price__c != null &&
        quantity != null
        ? ivt.Current_Price__c * quantity
        : 0;
      this.lines = new List<StockLinesWrapper>();
      for (Investment_Line_Items__c ivtLine : ivt.Investment_Line_Items__r) {
        StockLinesWrapper sline = new StockLinesWrapper(ivtLine);
        this.lines.add(sline);
      }
    }
  }
  public class StockLinesWrapper {
    @AuraEnabled
    public Id recordId { get; set; }
    @AuraEnabled
    public Date sdate { get; set; }
    @AuraEnabled
    public Decimal amount { get; set; }
    @AuraEnabled
    public String buySell { get; set; }
    @AuraEnabled
    public String exchange { get; set; }
    @AuraEnabled
    public Integer quantity { get; set; }
    @AuraEnabled
    public Decimal pricePerShare { get; set; }
    @AuraEnabled
    public String recordURL { get; set; }
    public StockLinesWrapper() {
    }
    public StockLinesWrapper(Investment_Line_Items__c ivtLine) {
      this.recordId = ivtLine.Id;
      this.recordURL = '/' + this.recordId;
      this.sdate = ivtLine.Date__c;
      this.amount = ivtLine.Amount__c;
      this.buySell = ivtLine.Buy_Sell__c;
      this.exchange = ivtLine.Exchange__c;
      this.quantity = Integer.valueOf(ivtLine.Quantity__c);
      this.pricePerShare = ivtLine.Per_Share_Price__c;
    }
  }

  public class FutureInvestmentWrapper {
    @AuraEnabled
    public Id recordId { get; set; }
    @AuraEnabled
    public String accountNumber { get; set; }
    @AuraEnabled
    public Decimal amount { get; set; }
    @AuraEnabled
    public String bankName { get; set; }
    @AuraEnabled
    public Date startDate { get; set; }
    @AuraEnabled
    public Date maturityDate { get; set; }
    @AuraEnabled
    public Integer numberOfInvestments { get; set; }
    @AuraEnabled
    public List<FutureInvestmentLinesWrapper> lines { get; set; }
    public FutureInvestmentWrapper() {
    }
    public FutureInvestmentWrapper(Investment__c ivt) {
      this.recordId = ivt.Id;
      this.accountNumber = ivt.Account_Number__c;
      this.amount = ivt.Amount__c;
      this.bankName = ivt.Bank__c;
      this.startDate = ivt.Start_Date__c;
      this.maturityDate = ivt.Maturity_Date__c;
      this.numberOfInvestments = ivt.Investment_Line_Items__r.size();
      this.lines = new List<FutureInvestmentLinesWrapper>();
      for (Investment_Line_Items__c ivtLine : ivt.Investment_Line_Items__r) {
        FutureInvestmentLinesWrapper fw = new FutureInvestmentLinesWrapper(
          ivtLine
        );
        this.lines.add(fw);
      }
    }
  }

  public class FutureInvestmentLinesWrapper {
    @AuraEnabled
    public Id recordId { get; set; }
    @AuraEnabled
    public Date contributionDate { get; set; }
    @AuraEnabled
    public Decimal contributionAmount { get; set; }
    @AuraEnabled
    public String taggedFY { get; set; }
    @AuraEnabled
    public String recordURL { get; set; }
    public FutureInvestmentLinesWrapper() {
    }
    public FutureInvestmentLinesWrapper(Investment_Line_Items__c lineItem) {
      this.recordId = lineItem.Id;
      this.recordURL = '/' + this.recordId;
      this.contributionDate = lineItem.Date__c;
      this.contributionAmount = lineItem.Amount__c;
      this.taggedFY = tagFiscalYear();
    }

    private String tagFiscalYear() {
      Integer year = this.contributionDate.year();
      Integer month = this.contributionDate.month();
      Integer startYr, endYr;
      if (month <= 3) {
        startYr = year - 1;
        endYr = year;
      } else {
        startYr = year;
        endYr = year + 1;
      }
      return String.valueOf(startYr) + ' - ' + String.valueOf(endYr);
    }
  }

  public static List<Investment_Line_Items__c> getAllLines(
    Date startDate,
    Date endDate,
    String entityName
  ) {
    return [
      SELECT
        Id,
        Investment__r.Account_Number__c,
        Investment__r.Is_Closed__c,
        Investment__r.Closed_Date__c,
        Investment__r.Bank__c,
        Investment__r.Id,
        Investment__r.Entity__c,
        Type__c,
        Amount__c,
        Tenure_Day__c,
        Tenure_Mnt__c,
        Tenure_Yr__c,
        Rate__c,
        Principle__c,
        Investment_Date__c,
        Maturity_Date__c,
        IS_TDS__c,
        TDS_Deducted__c,
        Comment__c,
        Incurred_Interest__c
      FROM Investment_Line_Items__c
      WHERE
        ((Investment_Date__c >= :startDate
        AND Investment_Date__c <= :endDate)
        OR (Maturity_Date__c >= :startDate
        AND Maturity_Date__c <= :endDate))
        /* Investment__r.Id = 'a05In000000zYyDIAU' AND */
        AND Bank__c NOT IN ('PPF', 'NPS')
        AND Investment__r.Entity__c = :entityName
    ];
  }

  public static List<Treasure__c> getAllTresures(Date startDate, Date endDate) {
    String queryStr = 'SELECT Id, Tresuree__c, Date__c, Amount__c, Details__c, FD_Breakage__c ';
    queryStr += 'FROM Treasure__c ';
    if (startDate != null && endDate != null) {
      queryStr += 'WHERE Date__c >= :startDate AND Date__c <= :endDate ';
    }
    queryStr += 'ORDER BY Tresuree__c, Date__c DESC';

    return (List<Treasure__c>) Database.query(queryStr);
  }

  public static Map<String, Decimal> getExpenseByMonth(
    Date sDate,
    Date endDate
  ) {
    Map<String, Decimal> dataMap = new Map<String, Decimal>();
    for (Expense_Line_Item__c exp : [
      SELECT Id, Amount__c, Expense__r.Name
      FROM Expense_Line_Item__c
      WHERE
        Expense__r.Start_Date__c >= :sDate
        AND Expense__r.End_Date__c <= :endDate
      ORDER BY Expense__r.Start_Date__c DESC
    ]) {
      Decimal amount = exp.Amount__c;
      if (dataMap.containsKey(exp.Expense__r.Name)) {
        amount += dataMap.get(exp.Expense__r.Name);
      }
      dataMap.put(exp.Expense__r.Name, amount);
    }

    return dataMap;
  }

  public static List<NaamJapp__c> getNaamJaapRecords() {
    return [
      SELECT Id, Date__c, Entity__c, Count__c
      FROM NaamJapp__c
      ORDER BY Date__c DESC
    ];
  }

  public static List<Transaction__c> getAllTransaction() {
    return [
      SELECT Id, Name, Total_Debited__c, Total_Credited__c, Balance__c
      FROM Transaction__c
    ];
  }
  public static List<Transaction_Item__c> getAllTransactionItems(
    String transactionId
  ) {
    return [
      SELECT
        Id,
        Transaction__c,
        Amount__c,
        Date__c,
        Description__c,
        Type__c,
        Source_Record_Id__c
      FROM Transaction_Item__c
      WHERE Transaction__c = :transactionId
      ORDER BY LastModifiedDate DESC
    ];
  }
}
