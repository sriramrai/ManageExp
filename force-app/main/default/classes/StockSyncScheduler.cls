public with sharing class StockSyncScheduler implements Schedulable {
  public StockSyncScheduler() {
  }

  public void execute(SchedulableContext sc) {
    syncStockPrices();
  }

  @AuraEnabled(Cacheable=true)
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
