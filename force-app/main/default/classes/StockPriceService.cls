public with sharing class StockPriceService {
  public static Map<String, Decimal> getStockPrices(String symbols) {
    Map<String, Decimal> stockPrices = new Map<String, Decimal>();
    try {
      String encodedSymbols = EncodingUtil.urlEncode(symbols, 'UTF-8');
      String endpointUrl =
        'https://square-shape-db5a.raidipu55.workers.dev/?symbols=' +
        encodedSymbols;
      HttpRequest req = new HttpRequest();
      req.setEndpoint(endpointUrl);
      req.setMethod('GET');
      req.setTimeout(20000);
      Http http = new Http();
      HttpResponse res = http.send(req);
      System.debug('Response: ' + res.getBody());
      Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(
        res.getBody()
      );

      for (String symbol : responseMap.keySet()) {
        Object value = responseMap.get(symbol);

        if (value != null) {
          Decimal price = Decimal.valueOf(String.valueOf(value));

          stockPrices.put(symbol, price);
        }
      }
    } catch (Exception ex) {
      System.debug('Error: ' + ex.getMessage());
    }

    return stockPrices;
  }
}
