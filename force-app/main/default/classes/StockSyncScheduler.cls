public with sharing class StockSyncScheduler implements Schedulable, Database.AllowsCallouts {
  public StockSyncScheduler() {
  }

  public void execute(SchedulableContext sc) {
    System.enqueueJob(new StockSyncQueableJob());
    scheduleNextRun();
  }

  private void scheduleNextRun() {
    // 2. Calculate next run time
    Datetime nextRun = System.now().addMinutes(1);

    // Assuming scheduler user timezone is IST
    Integer dayOfWeek = Integer.valueOf(nextRun.format('u')); // 1=Mon ... 7=Sun
    Integer hour = nextRun.hour();
    Integer minute = nextRun.minute();

    Boolean shouldSchedule =
      dayOfWeek <= 5 &&
      ((hour > 9 &&
      hour < 16) ||
      (hour == 9) ||
      (hour == 16 &&
      minute == 0));

    if (shouldSchedule) {
      String cron = String.format(
        '{0} {1} {2} {3} {4} ? {5}',
        new List<String>{
          String.valueOf(nextRun.second()),
          String.valueOf(nextRun.minute()),
          String.valueOf(nextRun.hour()),
          String.valueOf(nextRun.day()),
          String.valueOf(nextRun.month()),
          String.valueOf(nextRun.year())
        }
      );

      System.schedule(
        'StockSyncScheduler_' + nextRun.getTime(),
        cron,
        new StockSyncScheduler()
      );
    }
  }

  public static void syncStockPrices() {
    List<Investment__c> stockRecords = DataProvider.getAllStockRecords();

    if (stockRecords.isEmpty()) {
      System.debug('No stock records found to update.');
      return;
    }

    Set<String> stockSymbols = new Set<String>();

    for (Investment__c record : stockRecords) {
      if (record.Code__c != null) {
        stockSymbols.add(record.Code__c);
      }
    }

    if (stockSymbols.isEmpty()) {
      System.debug('No valid stock symbols found in records.');
      return;
    }

    String symbolsParam = String.join(new List<String>(stockSymbols), ',');

    Map<String, Decimal> latestPrices = StockPriceService.getStockPrices(
      symbolsParam
    );

    List<Investment__c> recordsToUpdate = new List<Investment__c>();

    for (Investment__c record : stockRecords) {
      if (record.Code__c != null && latestPrices.containsKey(record.Code__c)) {
        Decimal newPrice = latestPrices.get(record.Code__c);

        if (record.Current_Price__c != newPrice) {
          record.Current_Price__c = newPrice;
          recordsToUpdate.add(record);
        }
      }
    }

    if (!recordsToUpdate.isEmpty()) {
      try {
        update recordsToUpdate;
        StockUpdateEvent__e stockUpdateEvent = new StockUpdateEvent__e(
          Price_Updated__c = true
        );
        //EventBus.publish(stockUpdateEvent);
        // commenting the platform event for now as it is not needed the data is being refreshed from the client side using polling
        System.debug(
          'Updated ' +
            recordsToUpdate.size() +
            ' stock records with latest prices.'
        );
      } catch (DmlException e) {
        System.debug('Error updating stock records: ' + e.getMessage());
      }
    } else {
      System.debug('No stock prices needed updating.');
    }
  }
}
