public with sharing class StockSyncQueableJob implements Queueable, Database.AllowsCallouts {
  public StockSyncQueableJob() {
  }
  public void execute(QueueableContext qc) {
    StockSyncScheduler.syncStockPrices();
  }
}
