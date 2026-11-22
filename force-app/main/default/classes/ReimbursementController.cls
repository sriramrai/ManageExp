public with sharing class ReimbursementController {
  public class LineItemDTO {
    @AuraEnabled
    public Id id;
    @AuraEnabled
    public Date expenseDate;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Decimal amount;
    @AuraEnabled
    public Integer scanCount;
    @AuraEnabled
    public Integer paymentCount;
    @AuraEnabled
    public String invoiceFileName;
    @AuraEnabled
    public String paymentFileName;
    @AuraEnabled
    public String invoiceFileSize;
    @AuraEnabled
    public String paymentFileSize;
    @AuraEnabled
    public Id invoiceContentDocumentId { get; set; }
    @AuraEnabled
    public Id paymentContentDocumentId { get; set; }
    @AuraEnabled
    public Boolean isScanned;
  }

  @AuraEnabled(cacheable=true)
  public static List<Reimburshments__c> getExistingReimbursements() {
    return [
      SELECT Id, Name
      FROM Reimburshments__c
      /* WHERE Status__c = 'Draft' */
      ORDER BY CreatedDate DESC
      LIMIT 100
    ];
  }

  @AuraEnabled
  public static Id createReimbursementLineItem(
    Id reimbursementId,
    Date expenseDate,
    String description,
    Decimal amount
  ) {
    if (reimbursementId == null) {
      throw new AuraHandledException('Please select a reimbursement.');
    }

    if (String.isBlank(description)) {
      throw new AuraHandledException('Description is required.');
    }

    if (amount == null || amount < 0) {
      throw new AuraHandledException('Please enter a valid amount.');
    }

    Reimburshment_Line__c lineItem = new Reimburshment_Line__c(
      Reimburshment__c = reimbursementId,
      Date__c = expenseDate,
      Description__c = description,
      Amount__c = amount,
      Is_Scanned__c = true
    );

    insert lineItem;

    return lineItem.Id;
  }

  @AuraEnabled
  public static Id uploadReceiptFile(
    Id recordId,
    String fileName,
    String base64Data,
    String contentType,
    String receiptType
  ) {
    if (recordId == null) {
      throw new AuraHandledException('Reimbursement line item Id is required.');
    }

    if (
      String.isBlank(receiptType) ||
      receiptType != 'Invoice' &&
      receiptType != 'Payment'
    ) {
      throw new AuraHandledException(
        'Invalid receipt type. Must be Invoice or Payment.'
      );
    }

    if (String.isBlank(fileName) || String.isBlank(base64Data)) {
      throw new AuraHandledException(
        'File name and file content are required.'
      );
    }

    try {
      ContentVersion contentVersion = new ContentVersion();
      contentVersion.Title = fileName.contains('.')
        ? fileName.substringBeforeLast('.')
        : fileName;
      contentVersion.PathOnClient = fileName;
      contentVersion.VersionData = EncodingUtil.base64Decode(base64Data);
      contentVersion.Receipt_Type__c = receiptType;

      // Link the uploaded file directly to the line item.
      contentVersion.FirstPublishLocationId = recordId;

      insert contentVersion;

      return contentVersion.Id;
    } catch (Exception e) {
      throw new AuraHandledException(
        'Unable to upload receipt: ' + e.getMessage()
      );
    }
  }

  @AuraEnabled(cacheable=true)
  public static Reimburshments__c getReimbursementDetails(Id reimbursementId) {
    if (reimbursementId == null) {
      throw new AuraHandledException('Reimbursement ID is required.');
    }

    return [
      SELECT Id, Name
      FROM Reimburshments__c
      WHERE Id = :reimbursementId
      LIMIT 1
    ];
  }

  @AuraEnabled
  public static Id createReimbursement(String reimbursementName) {
    if (String.isBlank(reimbursementName)) {
      throw new AuraHandledException('Reimbursement name is required.');
    }

    Reimburshments__c reimbursement = new Reimburshments__c(
      Name = reimbursementName.trim()
      /* Status__c = 'Draft' */
    );

    insert reimbursement;

    return reimbursement.Id;
  }

  @AuraEnabled
  public static Id createLineItem(Id reimbursementId) {
    if (reimbursementId == null) {
      throw new AuraHandledException('Reimbursement ID is required.');
    }

    Reimburshment_Line__c lineItem = new Reimburshment_Line__c(
      Reimburshment__c = reimbursementId
    );

    insert lineItem;

    return lineItem.Id;
  }

  @AuraEnabled(cacheable=false)
  public static List<LineItemDTO> getLineItems(Id reimbursementId) {
    List<Reimburshment_Line__c> records = [
      SELECT Id, Date__c, Description__c, Amount__c, Is_Scanned__c
      FROM Reimburshment_Line__c
      WHERE Reimburshment__c = :reimbursementId
      ORDER BY CreatedDate ASC
    ];

    List<LineItemDTO> results = new List<LineItemDTO>();
    System.debug(
      'Fetched ' +
        records.size() +
        ' line items for reimbursement ID: ' +
        reimbursementId
    );
    //Set<Id> lineItemIds = new Set<Id>();
    Map<Id, LineItemDTO> lineItemMap = new Map<Id, LineItemDTO>();
    for (Reimburshment_Line__c record : records) {
      //lineItemIds.add(record.Id);

      LineItemDTO dto = new LineItemDTO();
      dto.id = record.Id;
      dto.expenseDate = record.Date__c;
      dto.description = record.Description__c;
      dto.amount = record.Amount__c;
      dto.isScanned = record.Is_Scanned__c;
      dto.scanCount = 0;
      dto.paymentCount = 0;

      lineItemMap.put(record.Id, dto);
    }

    System.debug(
      'Line item map size: ' +
        lineItemMap.size() +
        ' for reimbursement ID: ' +
        reimbursementId
    );

    if (lineItemMap.keySet().isEmpty()) {
      return lineItemMap.values();
    }

    /* Map<Id, String> scanCounts = new Map<Id, Integer>();
     Map<Id, Integer> paymentCounts = new Map<Id, Integer>(); */

    for (ContentDocumentLink link : [
      SELECT
        LinkedEntityId,
        ContentDocumentId,
        ContentDocument.Title,
        ContentDocument.ContentSize,
        ContentDocument.LatestPublishedVersion.Receipt_Type__c
      FROM ContentDocumentLink
      WHERE LinkedEntityId IN :lineItemMap.keySet()
    ]) {
      String linkedEntityId = link.LinkedEntityId;
      if (!lineItemMap.containsKey(linkedEntityId)) {
        continue;
      }
      String receiptType = link.ContentDocument.LatestPublishedVersion.Receipt_Type__c;
      String fileName = link.ContentDocument.Title;
      String fileSize = String.valueOf(link.ContentDocument.ContentSize);
      LineItemDTO dto = lineItemMap.get(linkedEntityId);
      if (receiptType == 'Invoice') {
        dto.invoiceFileName = fileName;
        dto.invoiceFileSize = fileSize;
        dto.invoiceContentDocumentId = link.ContentDocumentId;
      } else if (receiptType == 'Payment') {
        dto.paymentFileName = fileName;
        dto.paymentFileSize = fileSize;
        dto.paymentContentDocumentId = link.ContentDocumentId;
      }
    }
    System.debug(
      'Returning ' +
        lineItemMap.values().size() +
        ' line items for reimbursement ID: ' +
        reimbursementId
    );
    return lineItemMap.values();
  }

  @AuraEnabled
  public static void updateLineItems(List<Reimburshment_Line__c> lineItems) {
    /* if (lineItems == null || lineItems.isEmpty()) {
      return;
    }

    for (Reimburshment_Line__c item : lineItems) {
      if (item.Amount__c != null && item.Amount__c < 0) {
        throw new AuraHandledException('Expense amount cannot be negative.');
      }
    }

    update lineItems; */
    //return null;
  }

  @AuraEnabled
  public static void deleteLineItem(Id lineItemId) {
    /* if (lineItemId == null) {
      throw new AuraHandledException('Line item ID is required.');
    }

    delete [
      SELECT Id
      FROM Reimburshment_Line__c
      WHERE Id = :lineItemId
      LIMIT 1
    ];*/
    // return null;
  }

  @AuraEnabled
  public static List<FileExportDTO> getFilesForExport(
    List<Id> contentDocumentIds
  ) {
    List<FileExportDTO> results = new List<FileExportDTO>();

    if (contentDocumentIds == null || contentDocumentIds.isEmpty()) {
      return results;
    }

    Set<Id> documentIds = new Set<Id>(contentDocumentIds);

    for (ContentVersion cv : [
      SELECT
        Id,
        ContentDocumentId,
        Title,
        FileExtension,
        VersionData,
        ContentSize
      FROM ContentVersion
      WHERE ContentDocumentId IN :documentIds AND IsLatest = TRUE
    ]) {
      FileExportDTO dto = new FileExportDTO();

      dto.contentDocumentId = cv.ContentDocumentId;
      dto.fileName = cv.Title;

      if (String.isNotBlank(cv.FileExtension)) {
        dto.fileName += '.' + cv.FileExtension;
      }

      dto.base64Data = EncodingUtil.base64Encode(cv.VersionData);

      results.add(dto);
    }

    return results;
  }

  public class FileExportDTO {
    @AuraEnabled
    public Id contentDocumentId { get; set; }
    @AuraEnabled
    public String fileName { get; set; }
    @AuraEnabled
    public String base64Data { get; set; }
  }

  @AuraEnabled
  public static void sendReimbursementEmail(
    String recipientEmail,
    List<String> ccAddresses,
    String emailSubject,
    String emailBody,
    String excelFileName,
    String excelBase64,
    List<Id> contentDocumentIds,
    List<String> attachmentNames
  ) {
    if (String.isBlank(recipientEmail)) {
      throw new AuraHandledException('Recipient email is required.');
    }

    if (String.isBlank(excelBase64)) {
      throw new AuraHandledException('Excel report is missing.');
    }

    if (contentDocumentIds == null) {
      contentDocumentIds = new List<Id>();
    }

    if (
      attachmentNames == null ||
      attachmentNames.size() != contentDocumentIds.size()
    ) {
      throw new AuraHandledException('Invalid attachment information.');
    }

    try {
      List<Messaging.EmailFileAttachment> emailFiles = new List<Messaging.EmailFileAttachment>();

      // Add Excel workbook.
      Messaging.EmailFileAttachment excelAttachment = new Messaging.EmailFileAttachment();

      excelAttachment.setFileName(excelFileName);
      excelAttachment.setContentType(
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      );
      excelAttachment.setBody(EncodingUtil.base64Decode(excelBase64));

      emailFiles.add(excelAttachment);

      // Retrieve latest versions of receipt files.
      if (!contentDocumentIds.isEmpty()) {
        Map<Id, ContentVersion> versionMap = new Map<Id, ContentVersion>();

        for (ContentVersion cv : [
          SELECT Id, ContentDocumentId, FileExtension, VersionData
          FROM ContentVersion
          WHERE ContentDocumentId IN :contentDocumentIds AND IsLatest = TRUE
        ]) {
          versionMap.put(cv.ContentDocumentId, cv);
        }

        // Preserve the order and names supplied by the UI.
        for (Integer i = 0; i < contentDocumentIds.size(); i++) {
          Id documentId = contentDocumentIds[i];

          ContentVersion cv = versionMap.get(documentId);

          if (cv == null) {
            continue;
          }

          String fileName = attachmentNames[i];

          if (String.isNotBlank(cv.FileExtension)) {
            fileName += '.' + cv.FileExtension;
          }

          Messaging.EmailFileAttachment receiptAttachment = new Messaging.EmailFileAttachment();

          receiptAttachment.setFileName(fileName);
          receiptAttachment.setBody(cv.VersionData);

          emailFiles.add(receiptAttachment);
        }
      }

      // Prepare email.
      Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();

      email.setToAddresses(new List<String>{ recipientEmail });
      if (ccAddresses != null && !ccAddresses.isEmpty()) {
        email.setCcAddresses(ccAddresses);
      }

      email.setSubject(
        String.isNotBlank(emailSubject) ? emailSubject : 'Reimbursement Report'
      );

      email.setPlainTextBody(emailBody);
      email.setFileAttachments(emailFiles);
      email.setSaveAsActivity(false);

      // Send email and check the result.
      Messaging.SendEmailResult[] results = Messaging.sendEmail(
        new List<Messaging.SingleEmailMessage>{ email },
        false
      );
      System.debug('EMAIL RESULT COUNT: ' + results.size());
      for (Messaging.SendEmailResult result : results) {
        System.debug('EMAIL SUCCESS: ' + result.isSuccess());

        if (!result.isSuccess()) {
          for (Messaging.SendEmailError err : result.getErrors()) {
            System.debug('EMAIL ERROR: ' + err.getMessage());
            System.debug('EMAIL STATUS CODE: ' + err.getStatusCode());
          }
        }
      }

      if (results.isEmpty() || !results[0].isSuccess()) {
        String errorMessage = 'Unable to send reimbursement email.';

        if (!results.isEmpty() && !results[0].getErrors().isEmpty()) {
          errorMessage = results[0].getErrors()[0].getMessage();
        }

        throw new AuraHandledException(errorMessage);
      }
    } catch (Exception e) {
      throw new AuraHandledException('Email sending failed: ' + e.getMessage());
    }
  }
}
