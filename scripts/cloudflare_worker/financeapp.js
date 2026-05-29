//https://dash.cloudflare.com/73965ed39bd9bf518f425516dba2a72e/workers/services/edit/square-shape-db5a/production
export default {

  async fetch(request) {

    const url = new URL(request.url);

    const symbols =
      url.searchParams.get("symbols");

    if (!symbols) {

      return new Response(
        JSON.stringify({
          error: "symbols parameter required"
        }),
        {
          headers: {
            "Content-Type": "application/json"
          }
        }
      );
    }

    const stockList =
      symbols.split(",");

    let result = {};

    for (const stock of stockList) {

      try {

        const yahooUrl =
          `https://query1.finance.yahoo.com/v7/finance/quote?symbols=${stock}.NS`;

        const response =
          await fetch(yahooUrl, {
            headers: {
              "User-Agent": "Mozilla/5.0"
            }
          });

        const data =
          await response.json();

        const quote =
          data.quoteResponse.result[0];

        if (quote) {

          result[stock] =
            quote.regularMarketPrice;
        }

      } catch (err) {

        result[stock] = null;
      }
    }

    return new Response(
      JSON.stringify(result),
      {
        headers: {
          "Content-Type": "application/json"
        }
      }
    );
  }
}