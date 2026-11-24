const FINANCIAL_TRANSACTION_CONFIG = {
  gmailQuery: "after:2026/11/22 {ICICI Axis}",

  processedLabel: "EXPENSE_SF_PROCESSED",
  reviewLabel: "ICICI_SF_REVIEW",

  salesforceEndpoint: "/services/apexrest/gmail/expenses/"
};

const AUTOMATION_START_DATE = new Date("2026-11-21T00:00:00+05:30");

function identifyProvider_(message) {
  const subject = message.getSubject();
  const body = message.getPlainBody();
  const sender = message.getFrom();

  // ICICI identification
  if (/ICICI Bank Credit Card/i.test(body)) {
    return "ICICI";
  }

  // Axis identification
  if (
    /Axis Bank/i.test(subject) ||
    /Axis Bank/i.test(body) ||
    /axisbank/i.test(sender)
  ) {
    return "AXIS";
  }

  return null;
}

function parseTransaction_(message, provider) {
  let transaction = null;

  switch (provider) {
    case "ICICI":
      transaction = parseICICIEmail_(message);
      break;

    case "AXIS":
      transaction = parseAxisEmail_(message);
      break;

    default:
      return null;
  }

  if (!transaction) {
    return null;
  }

  // Common fields for every provider
  transaction.provider = provider;
  transaction.emailMessageId = message.getId();
  transaction.source = "GMAIL";
  return transaction;
}

function parseAxisEmail_(message) {
  // Axis parsing will be implemented after
  // confirming the actual notification format.

  Logger.log("Axis parser not implemented yet: " + message.getId());

  return null;
}

/**
 * Main Gmail processing function.
 */

function processTransactions() {
  const lock = LockService.getScriptLock();

  if (!lock.tryLock(1000)) {
    Logger.log("Another transaction-processing execution is running.");
    return;
  }

  let successCount = 0;
  let reviewCount = 0;
  let failedCount = 0;
  let skippedCount = 0;

  try {
    const threads = GmailApp.search(
      FINANCIAL_TRANSACTION_CONFIG.gmailQuery,
      0,
      50
    );

    Logger.log("Threads found: " + threads.length);

    threads.forEach(function (thread) {
      const messages = thread.getMessages();
      let eligibleCount = 0;

      messages.forEach(function (message) {
        if (message.getDate() < AUTOMATION_START_DATE) {
          return;
        }

        const messageId = message.getId();
        const provider = identifyProvider_(message);

        if (!provider) {
          return;
        }

        eligibleCount++;

        // Skip messages that already have a processing status.
        const existingStatus = getMessageStatus_(messageId);

        if (existingStatus) {
          Logger.log(
            "Skipping message: " +
              messageId +
              " | Existing status: " +
              existingStatus
          );
          skippedCount++;
          return;
        }

        // Do not attempt providers whose parsers are not ready.
        if (!isProviderParserReady_(provider)) {
          markMessageStatus_(
            messageId,
            "PARSER_NOT_READY",
            provider,
            "Parser is not implemented yet."
          );

          Logger.log("Parser not ready: " + provider);
          return;
        }

        let transaction;

        try {
          transaction = parseTransaction_(message, provider);
        } catch (error) {
          markMessageStatus_(
            messageId,
            "REVIEW",
            provider,
            "Parsing exception: " + error.message
          );

          reviewCount++;
          return;
        }

        if (!transaction) {
          markMessageStatus_(
            messageId,
            "REVIEW",
            provider,
            "Unable to parse transaction email."
          );

          Logger.log("Parsing failed: " + provider + " | " + messageId);
          reviewCount++;
          return;
        }

        try {
          Logger.log(
            "Sending transaction to Salesforce: " + provider + " | " + messageId
          );

          const result = sendToSalesforce_(transaction);

          Logger.log("Salesforce response: " + JSON.stringify(result));

          const responseStatus =
            result && result.status ? result.status.toUpperCase() : "";

          if (responseStatus === "CREATED" || responseStatus === "DUPLICATE") {
            markMessageStatus_(messageId, responseStatus, provider, null);

            successCount++;
          } else if (
            responseStatus === "PARENT_NOT_FOUND" ||
            responseStatus === "MULTIPLE_PARENTS_FOUND" ||
            responseStatus === "VALIDATION_ERROR"
          ) {
            markMessageStatus_(
              messageId,
              "REVIEW",
              provider,
              result.message || responseStatus
            );

            reviewCount++;
          } else {
            markMessageStatus_(
              messageId,
              "FAILED",
              provider,
              result && result.message
                ? result.message
                : "Unexpected Salesforce response."
            );

            failedCount++;
          }
        } catch (error) {
          // No automatic retry.
          markMessageStatus_(messageId, "FAILED", provider, error.message);

          Logger.log("Salesforce error: " + messageId + " | " + error.message);

          failedCount++;
        }
      });

      // Label is for visibility only, not the processing ledger.
      if (eligibleCount > 0) {
        getOrCreateLabel_(
          FINANCIAL_TRANSACTION_CONFIG.processedLabel
        ).addToThread(thread);
      }
    });
  } finally {
    lock.releaseLock();

    Logger.log("--------------------------------");
    Logger.log("Successfully processed: " + successCount);
    Logger.log("Needs review: " + reviewCount);
    Logger.log("Failed: " + failedCount);
    Logger.log("Skipped: " + skippedCount);
  }
}

function getMessageStatus_(messageId) {
  const properties = PropertiesService.getScriptProperties();
  const record = properties.getProperty("FT_MSG_" + messageId);

  if (!record) {
    return null;
  }

  return JSON.parse(record).status;
}

function markMessageStatus_(messageId, status, provider, error) {
  const properties = PropertiesService.getScriptProperties();

  const record = {
    status: status,
    provider: provider,
    error: error || null,
    updatedAt: new Date().toISOString()
  };

  properties.setProperty("FT_MSG_" + messageId, JSON.stringify(record));
}

function isProviderParserReady_(provider) {
  const readyProviders = ["ICICI"];

  return readyProviders.indexOf(String(provider).toUpperCase()) !== -1;
}

function resetTransactionMessage(messageId) {
  PropertiesService.getScriptProperties().deleteProperty("FT_MSG_" + messageId);

  Logger.log("Processing status reset for message: " + messageId);
}

/**
 * Identify relevant successful payment notifications.
 */
function isICICITransaction_(message) {
  const subject = message.getSubject();
  const body = message.getPlainBody();

  const correctSubject =
    /Transaction alert for your ICICI Bank Credit Card/i.test(subject);

  const correctBody =
    /has been used for a transaction of\s+INR\s*[\d,]+(?:\.\d{1,2})?\s+on\s+[A-Za-z]{3}\s+\d{1,2},\s+\d{4}\s+at\s+\d{2}:\d{2}:\d{2}\.\s*Info:/i.test(
      body
    );

  return correctSubject && correctBody;
}

/**
 * Extract transaction details from the email.
 */

function parseICICIEmail_(message) {
  const body = message.getPlainBody();

  const amountMatch = body.match(
    /transaction of\s+INR\s*([\d,]+(?:\.\d{1,2})?)\s+on/i
  );

  const dateMatch = body.match(
    /\bon\s+([A-Za-z]{3}\s+\d{1,2},\s+\d{4})\s+at\s+\d{2}:\d{2}:\d{2}/i
  );

  const merchantMatch = body.match(/\bInfo:\s*([^\r\n]+)/i);

  const cardMatch = body.match(/\bXX(\d{4})\b/i);

  if (!amountMatch || !dateMatch || !merchantMatch) {
    return null;
  }

  const amount = parseFloat(amountMatch[1].replace(/,/g, ""));

  const merchant = merchantMatch[1].trim().replace(/\.$/, "");

  const transactionDate = parseTransactionDate_(dateMatch[1]);

  if (!transactionDate || amount <= 0 || !merchant) {
    return null;
  }

  return {
    transactionDate: transactionDate,
    merchant: merchant,
    amount: amount,
    cardLastFour: cardMatch ? cardMatch[1] : null,
    transactionReference: null,
    emailMessageId: message.getId()
  };
}

/**
 * Convert supported email dates to yyyy-MM-dd.
 */

function parseTransactionDate_(value) {
  const match = value.match(/^([A-Za-z]{3})\s+(\d{1,2}),\s+(\d{4})$/);

  if (!match) {
    return null;
  }

  const monthNames = [
    "jan",
    "feb",
    "mar",
    "apr",
    "may",
    "jun",
    "jul",
    "aug",
    "sep",
    "oct",
    "nov",
    "dec"
  ];

  const month = monthNames.indexOf(match[1].toLowerCase()) + 1;

  const day = Number(match[2]);
  const year = Number(match[3]);

  if (month < 1 || day < 1 || day > 31) {
    return null;
  }

  const date = new Date(year, month - 1, day);

  if (
    date.getFullYear() !== year ||
    date.getMonth() !== month - 1 ||
    date.getDate() !== day
  ) {
    return null;
  }

  return Utilities.formatDate(date, "Asia/Kolkata", "yyyy-MM-dd");
}

/**
 * Obtain Salesforce access token.
 */
function getSalesforceToken_() {
  const cache = CacheService.getScriptCache();

  const cached = cache.get("SF_ACCESS_TOKEN");

  if (cached) {
    return JSON.parse(cached).accessToken;
  }

  const properties = PropertiesService.getScriptProperties();

  const domain = properties.getProperty("SF_MY_DOMAIN");
  const clientId = properties.getProperty("SF_CLIENT_ID");
  const clientSecret = properties.getProperty("SF_CLIENT_SECRET");

  if (!domain || !clientId || !clientSecret) {
    throw new Error("Salesforce OAuth properties are missing.");
  }

  const response = UrlFetchApp.fetch(domain + "/services/oauth2/token", {
    method: "post",
    payload: {
      grant_type: "client_credentials",
      client_id: clientId,
      client_secret: clientSecret
    },
    muteHttpExceptions: true
  });

  const status = response.getResponseCode();
  const result = JSON.parse(response.getContentText());

  if (status !== 200) {
    throw new Error(
      "Salesforce authentication failed: " + response.getContentText()
    );
  }

  const tokenData = {
    accessToken: result.access_token,
    instanceUrl: result.instance_url
  };

  cache.put("SF_ACCESS_TOKEN", JSON.stringify(tokenData), 3000);

  return tokenData.accessToken;
}

/**
 * Send transaction to Salesforce.
 */

function sendToSalesforce_(transaction) {
  const properties = PropertiesService.getScriptProperties();

  const myDomain = properties.getProperty("SF_MY_DOMAIN");

  if (!myDomain) {
    throw new Error("SF_MY_DOMAIN is missing from Script Properties.");
  }

  const endpoint =
    myDomain.replace(/\/$/, "") +
    FINANCIAL_TRANSACTION_CONFIG.salesforceEndpoint;

  Logger.log("Salesforce URL: " + endpoint);

  const accessToken = getSalesforceToken_();
  Logger.log("Access token received: " + accessToken);
  Logger.log("Access token received: " + Boolean(accessToken));
  Logger.log("Access token length: " + (accessToken || "").length);

  const response = UrlFetchApp.fetch(endpoint, {
    method: "post",
    contentType: "application/json",
    headers: {
      Authorization: "Bearer " + accessToken
    },
    payload: JSON.stringify(transaction),
    muteHttpExceptions: true
  });

  const statusCode = response.getResponseCode();
  const responseBody = response.getContentText();

  Logger.log("HTTP STATUS: " + statusCode);
  Logger.log("RESPONSE BODY: " + responseBody);

  if (statusCode < 200 || statusCode >= 300) {
    throw new Error(
      "Salesforce request failed: HTTP " + statusCode + " - " + responseBody
    );
  }

  return JSON.parse(responseBody);
}

/**
 * Execute Salesforce REST request.
 */
function callSalesforceAPI_(tokenData, transaction) {
  const response = UrlFetchApp.fetch(
    tokenData.instanceUrl + FINANCIAL_TRANSACTION_CONFIG.salesforceEndpoint,
    {
      method: "post",
      contentType: "application/json",

      headers: {
        Authorization: "Bearer " + tokenData.accessToken
      },

      payload: JSON.stringify(transaction),
      muteHttpExceptions: true
    }
  );

  return {
    status: response.getResponseCode(),
    body: response.getContentText()
  };
}

/**
 * Create Gmail labels when required.
 */
function getOrCreateLabel_(name) {
  return GmailApp.getUserLabelByName(name) || GmailApp.createLabel(name);
}

function testSalesforceAuthentication() {
  const token = getSalesforceToken_();

  Logger.log("Salesforce authentication successful.");
  Logger.log("Connected Salesforce org: " + token.instanceUrl);
}

function testICICIExpenseIntegration() {
  const sampleTransaction = {
    transactionDate: "2026-11-24",
    merchant: "AMAZON INDIA",
    amount: 2499.0,
    cardLastFour: "1234",
    transactionReference: "TEST-ICICI-001",
    emailMessageId: "TEST-GMAIL-001"
  };

  const result = sendToSalesforce_(sampleTransaction);
  Logger.log(JSON.stringify(result));
}

function cleanupOldTransactionLedger() {
  const properties = PropertiesService.getScriptProperties();
  const allProperties = properties.getProperties();

  const retentionDays = 180;
  const cutoff = Date.now() - retentionDays * 24 * 60 * 60 * 1000;

  let deletedCount = 0;

  Object.keys(allProperties).forEach(function (key) {
    if (!key.startsWith("FT_MSG_")) {
      return;
    }

    try {
      const record = JSON.parse(allProperties[key]);

      if (record.updatedAt && new Date(record.updatedAt).getTime() < cutoff) {
        properties.deleteProperty(key);
        deletedCount++;
      }
    } catch (error) {
      Logger.log("Unable to parse ledger entry: " + key);
    }
  });

  Logger.log("Old ledger entries deleted: " + deletedCount);
}

function createHourlyTrigger() {
  // Avoid creating duplicate triggers.
  const triggers = ScriptApp.getProjectTriggers();

  triggers.forEach(function (trigger) {
    if (trigger.getHandlerFunction() === "processTransactions") {
      ScriptApp.deleteTrigger(trigger);
    }
  });

  ScriptApp.newTrigger("processTransactions")
    .timeBased()
    .everyHours(1)
    .create();

  Logger.log("Hourly trigger created successfully.");
}
