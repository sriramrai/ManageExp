// https://dash.cloudflare.com/73965ed39bd9bf518f425516dba2a72e/workers/services/edit/square-shape-db5a/production
export default {
  async fetch(request) {
    // Handle CORS preflight requests
    if (request.method === "OPTIONS") {
      return new Response(null, {
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type",
          "Access-Control-Max-Age": "86400"
        }
      });
    }

    const url = new URL(request.url);
    const symbols = url.searchParams.get("symbols");

    if (!symbols) {
      return new Response(
        JSON.stringify({
          error: "symbols parameter required"
        }),
        {
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type"
          }
        }
      );
    }

    const stockList = symbols.split(",");
    const result = {};

    for (const stock of stockList) {
      try {
        // Try multiple Yahoo Finance endpoints
        let yahooUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${stock}.NS?interval=1d&range=1d`;

        let response = await fetch(yahooUrl, {
          headers: {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
          }
        });

        if (!response.ok) {
          // Try alternate endpoint if first fails
          yahooUrl = `https://query2.finance.yahoo.com/v7/finance/quote?symbols=${stock}.NS`;
          response = await fetch(yahooUrl, {
            headers: {
              "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
            }
          });
        }

        const data = await response.json();
        
        // Try chart endpoint format
        let price = data.chart?.result?.[0]?.meta?.regularMarketPrice;
        
        // Try quote endpoint format if chart didn't work
        if (!price && data.quoteResponse?.result?.[0]) {
          price = data.quoteResponse.result[0].regularMarketPrice;
        }

        result[stock] = price || null;
        
      } catch (err) {
        // Log error for debugging (will appear in Cloudflare logs)
        console.error(`Error fetching ${stock}:`, err.message);
        result[stock] = null;
      }
    }

    return new Response(
      JSON.stringify(result),
      {
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type"
        }
      }
    );
  }
}