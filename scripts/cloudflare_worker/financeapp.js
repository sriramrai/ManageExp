export default {
  async fetch(request, env) {
    // ============================
    // CORS
    // ============================

    if (request.method === "OPTIONS") {
      return new Response(null, {
        status: 204,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type"
        }
      });
    }

    const url = new URL(request.url);

    // ============================
    // FD RECEIPT OCR
    // ============================

    if (url.pathname === "/ocr") {
      const corsHeaders = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type",
        "Content-Type": "application/json"
      };

      if (request.method !== "POST") {
        return new Response(
          JSON.stringify({
            success: false,
            error: "OCR endpoint requires POST"
          }),
          {
            status: 405,
            headers: corsHeaders
          }
        );
      }

      try {
        // ========================================
        // READ REQUEST
        // ========================================

        const body = await request.json();

        if (!body.image) {
          return new Response(
            JSON.stringify({
              success: false,
              error: "image is required"
            }),
            {
              status: 400,
              headers: corsHeaders
            }
          );
        }

        let image = body.image;

        const mimeType = body.mimeType || "image/jpeg";

        // ========================================
        // CLEAN BASE64
        // ========================================

        if (image.startsWith("data:")) {
          const commaIndex = image.indexOf(",");

          if (commaIndex === -1) {
            throw new Error("Invalid image data URI");
          }

          image = image.substring(commaIndex + 1);
        }

        image = image.replace(/\s/g, "");

        // Fix Base64 padding
        const remainder = image.length % 4;

        if (remainder !== 0) {
          image += "=".repeat(4 - remainder);
        }

        console.log("OCR MIME:", mimeType);
        console.log("Base64 length:", image.length);

        const imageDataUri = `data:${mimeType};base64,${image}`;

        // ========================================
        // FD EXTRACTION PROMPT
        // ========================================

        const prompt = `
Extract FD receipt information from the image.

Return ONLY this JSON:

{
  "bank_name": "",
  "account_number": "",
  "account_number_label": "",
  "investment_date": "",
  "interest_rate": "",
  "principal_amount": "",
  "duration": ""
}

ACCOUNT NUMBER RULE:

Find the number that is explicitly associated with a bank account label.

Valid examples:
Account Number
Account No.
A/C Number
A/C No.
A/c No.
SB Account No.
Savings Account No.
e-TDR/e-STDR Account No.

Customer ID, Customer No, CIF, CIF No, FD Number,
FD No, Deposit Number, Receipt Number and Reference Number
are NOT account numbers.

If both Customer ID and Account Number exist,
use ONLY the number next to the Account Number label.

Preserve leading zeroes.

Return the exact account number visible in the image.
BANK NAME RULES:

The "bank_name" field MUST contain ONLY one of these exact values:

"SBI"
"Axis"
"BOB"
"SC"
"HDFC"
"BOI"
"UBI"

IMPORTANT:
You MUST normalize the bank's full name to the corresponding value above.

Bank name mapping:

- State Bank of India
- State Bank Of India
- STATE BANK OF INDIA
- SBI
=> return exactly "SBI"

- Axis Bank
- Axis Bank Ltd
- Axis Bank Limited
- AXIS
- Axis
=> return exactly "Axis"

- Bank of Baroda
- Bank Of Baroda
- BANK OF BARODA
- Bank of Badoda
- Bank Of Badoda
- BANK OF BADODA
- BOB
=> return exactly "BOB"

- Standard Chartered
- Standard Chartered Bank
=> return exactly "SC"

- HDFC Bank
- HDFC Bank Limited
=> return exactly "HDFC"

- Bank of India
- Bank Of India
- BOI
=> return exactly "BOI"

- Union Bank of India
- Union Bank Of India
- UBI
=> return exactly "UBI"

NEVER return the full bank name.
NEVER return "State Bank Of India".
NEVER return "Bank Of Baroda".
NEVER return "Bank Of Badoda".
NEVER return any value other than one of the allowed codes above.

If the bank cannot be identified clearly, return "".
Do not guess the bank name.

For investment_date use the FD opening/investment date,
NOT maturity date.

For principal_amount use the original deposit amount,
NOT maturity amount.

principal_amount should be the numeric value.
interest_rate should be the numberic value, dont add p.a.

For duration use the explicitly printed tenure.
Do not calculate it.

If a value cannot be clearly read, return "".

Never guess.

Return ONLY valid JSON.
No explanation.
No markdown.
No reasoning.
`;

        // ========================================
        // CALL LLAMA VISION
        // ========================================

        const aiResponse = await env.AI.run(
          "@cf/meta/llama-3.2-11b-vision-instruct",
          {
            messages: [
              {
                role: "user",
                content: [
                  {
                    type: "text",
                    text: prompt
                  },
                  {
                    type: "image_url",
                    image_url: {
                      url: imageDataUri
                    }
                  }
                ]
              }
            ],

            max_tokens: 1024
          }
        );

        // ========================================
        // LOG RAW AI RESPONSE
        // ========================================

        console.log("LLAMA RAW RESPONSE:", JSON.stringify(aiResponse));

        // ========================================
        // GET MODEL CONTENT
        // ========================================

        const rawResponse =
          aiResponse?.choices?.[0]?.message?.content ??
          aiResponse?.response ??
          aiResponse?.result ??
          "";

        console.log("RAW MODEL CONTENT:", rawResponse);

        if (!rawResponse) {
          return new Response(
            JSON.stringify({
              success: false,
              error: "Model returned empty response",
              raw_response: aiResponse
            }),
            {
              status: 422,
              headers: corsHeaders
            }
          );
        }

        // ========================================
        // EXTRACT JSON FROM MODEL RESPONSE
        // ========================================

        let fdData;

        try {
          let text = String(rawResponse).trim();

          console.log("MODEL TEXT BEFORE PARSING:", text);

          // Remove markdown code fences
          text = text
            .replace(/```json/gi, "")
            .replace(/```/g, "")
            .trim();

          // ----------------------------------------
          // Find first JSON object
          // ----------------------------------------

          const start = text.indexOf("{");

          const end = text.lastIndexOf("}");

          if (start === -1 || end === -1 || end <= start) {
            throw new Error("No JSON object found in AI response");
          }

          const jsonText = text.substring(start, end + 1);

          console.log("EXTRACTED JSON:", jsonText);

          fdData = JSON.parse(jsonText);
        } catch (parseError) {
          console.log("JSON PARSE ERROR:", parseError);

          return new Response(
            JSON.stringify({
              success: false,
              error: "AI response could not be converted to JSON",
              raw_response: rawResponse
            }),
            {
              status: 422,
              headers: corsHeaders
            }
          );
        }

        // ========================================
        // NORMALIZE FIELDS
        // ========================================

        const requiredFields = [
          "bank_name",
          "account_number",
          "account_number_label",
          "investment_date",
          "interest_rate",
          "principal_amount",
          "duration"
        ];

        for (const field of requiredFields) {
          if (fdData[field] === null || fdData[field] === undefined) {
            fdData[field] = "";
          }

          if (typeof fdData[field] !== "string") {
            fdData[field] = String(fdData[field]);
          }

          fdData[field] = fdData[field].trim();
        }

        // ========================================
        // ACCOUNT NUMBER VALIDATION
        // ========================================

        console.log("ACCOUNT NUMBER BEFORE VALIDATION:", fdData.account_number);

        console.log(
          "ACCOUNT LABEL BEFORE VALIDATION:",
          fdData.account_number_label
        );

        // ========================================
        // FINAL RESULT
        // ========================================

        console.log("FINAL FD DATA:", JSON.stringify(fdData, null, 2));

        return new Response(
          JSON.stringify({
            success: true,
            data: fdData
          }),
          {
            status: 200,
            headers: corsHeaders
          }
        );
      } catch (error) {
        console.log("OCR ERROR:", error);

        return new Response(
          JSON.stringify({
            success: false,
            error: error?.message || String(error)
          }),
          {
            status: 500,
            headers: corsHeaders
          }
        );
      }
    }

    // ============================
    // ORIGINAL STOCK API
    // ============================

    const symbols = url.searchParams.get("symbols");

    if (!symbols) {
      return Response.json({
        error: "symbols parameter required"
      });
    }

    const stockList = symbols.split(",");

    const result = {};

    for (const stock of stockList) {
      try {
        const yahooUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${stock}.NS?interval=1d&range=1d`;

        const response = await fetch(yahooUrl, {
          headers: {
            "User-Agent": "Mozilla/5.0"
          }
        });

        if (!response.ok) {
          throw new Error(`Yahoo Finance API error: ${response.status}`);
        }

        const data = await response.json();

        const chart = data.chart?.result?.[0];

        const price = chart?.meta?.regularMarketPrice;

        result[stock] = price || null;
      } catch (err) {
        result[stock] = null;
      }
    }

    return Response.json(result);
  }
};
