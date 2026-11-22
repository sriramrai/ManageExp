import { LightningElement, track } from "lwc";
import { ShowToastEvent } from "lightning/platformShowToastEvent";
import sendReimbursementEmail from "@salesforce/apex/ReimbursementController.sendReimbursementEmail";
import createReimbursementRecord from "@salesforce/apex/ReimbursementController.createReimbursement";
import createLineItemRecord from "@salesforce/apex/ReimbursementController.createLineItem";
import getLineItems from "@salesforce/apex/ReimbursementController.getLineItems";
import updateLineItems from "@salesforce/apex/ReimbursementController.updateLineItems";
import deleteLineItemRecord from "@salesforce/apex/ReimbursementController.deleteLineItem";
import getExistingReimbursements from "@salesforce/apex/ReimbursementController.getExistingReimbursements";
import getReimbursementDetails from "@salesforce/apex/ReimbursementController.getReimbursementDetails";
import createReimbursementLineItem from "@salesforce/apex/ReimbursementController.createReimbursementLineItem";
import uploadReceiptFile from "@salesforce/apex/ReimbursementController.uploadReceiptFile";
import { loadScript } from "lightning/platformResourceLoader";
import SHEETJS from "@salesforce/resourceUrl/sheetjs";
import JSZIP from "@salesforce/resourceUrl/JSZip";
import getFilesForExport from "@salesforce/apex/ReimbursementController.getFilesForExport";

export default class ReimbursementManager extends LightningElement {
  reimbursementName = "";
  reimbursementId;
  librariesLoaded = false;
  ccEmails = "";

  @track lineItems = [];

  isSaving = false;
  isEmailModalOpen = false;
  isSendingEmail = false;

  recipientEmail = "raidipu55@gmail.com";
  emailSubject = "";
  emailBody =
    "Hi Accounts Team,\n\n" +
    "Please find attached the reimbursement report, along with the supporting documents.\n\n" +
    "The attached Excel file contains the details of all expenses submitted for reimbursement. " +
    "The corresponding invoice and payment proofs are also attached for your reference and verification.\n\n" +
    "Regards,\n" +
    "Ragini";

  acceptedFormats = [".pdf", ".png", ".jpg", ".jpeg"];
  existingReimbursements = [];
  selectedReimbursementId = "";
  showWorkspace = false;
  selectedMode = "existing";
  get isExportDisabled() {
    return !this.selectedReimbursementId || !this.librariesLoaded;
  }

  async renderedCallback() {
    if (this.librariesLoaded) {
      return;
    }

    this.librariesLoaded = true;

    try {
      await Promise.all([loadScript(this, SHEETJS), loadScript(this, JSZIP)]);

      console.log("SheetJS and JSZip loaded successfully");
    } catch (error) {
      this.librariesLoaded = false;
      console.error("Error loading export libraries:", error);
    }
  }

  showExisting() {
    this.selectedMode = "existing";
  }

  showNew() {
    this.selectedMode = "new";
  }

  get isExistingMode() {
    return this.selectedMode === "existing";
  }

  get isNewMode() {
    return this.selectedMode === "new";
  }

  get existingButtonVariant() {
    return this.isExistingMode ? "brand" : "neutral";
  }

  get newButtonVariant() {
    return this.isNewMode ? "brand" : "neutral";
  }

  get isExistingSelectionDisabled() {
    return !this.selectedReimbursementId;
  }
  connectedCallback() {
    this.loadExistingReimbursements();
  }

  async handleScanFileChange(event) {
    const fileName = event.detail.fileName;
    const contentType = event.detail.contentType;
    const base64Data = event.detail.base64Data;
    const lineItemId = event.currentTarget.dataset.id;

    console.log("File Name:", fileName);
    console.log("Content Type:", contentType);
    console.log("Base64 Data:", base64Data);

    debugger;
    await uploadReceiptFile({
      recordId: lineItemId,
      fileName: fileName,
      base64Data: base64Data,
      contentType: contentType,
      receiptType: "Payment"
    });
  }

  async handleReceiptConfirm(event) {
    const { expenseDate, description, amount, file } = event.detail;

    try {
      // Step 1: Create reimbursement line item
      this.lineItemId = await createReimbursementLineItem({
        reimbursementId: this.selectedReimbursementId,
        expenseDate: expenseDate,
        description: description,
        amount: amount
      });

      // Step 2: Convert original receipt to Base64
      const fileBase64 = await this.readFileAsBase64(file);

      // Step 3: Upload original receipt against line item
      await uploadReceiptFile({
        recordId: this.lineItemId,
        fileName: file.name,
        base64Data: fileBase64,
        contentType: file.type,
        receiptType: "Invoice"
      });

      // Step 4: Refresh reimbursement line items
      debugger;
      await this.loadLineItems();
    } catch (error) {
      console.error("Unable to save reimbursement item:", error);
      this.showError(
        error?.body?.message ||
          error?.message ||
          "Unable to save reimbursement item."
      );
    }
  }

  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = () => {
        resolve(reader.result.split(",")[1]);
      };

      reader.onerror = () => {
        reject(new Error("Unable to read the receipt file."));
      };

      reader.readAsDataURL(file);
    });
  }

  async loadExistingReimbursements() {
    try {
      this.existingReimbursements = await getExistingReimbursements();
    } catch (error) {
      this.showError(error);
    }
  }

  get reimbursementOptions() {
    return this.existingReimbursements.map((item) => ({
      label: `${item.Name} - ₹${item.Total_Amount__c || 0}`,
      value: item.Id
    }));
  }

  handleExistingSelection(event) {
    this.selectedReimbursementId = event.detail.value;
  }

  async openExistingReimbursement() {
    if (!this.selectedReimbursementId) {
      this.showToast("Required", "Select a reimbursement first.", "warning");
      return;
    }

    try {
      const reimbursement = await getReimbursementDetails({
        reimbursementId: this.selectedReimbursementId
      });

      this.reimbursementId = reimbursement.Id;
      this.reimbursementName = reimbursement.Name;

      await this.loadLineItems();

      this.showWorkspace = true;
    } catch (error) {
      this.showError(error);
    }
  }

  handleNameChange(event) {
    this.reimbursementName = event.target.value;
  }

  async createReimbursement() {
    if (!this.reimbursementName.trim()) {
      this.showToast("Required", "Enter reimbursement name.", "warning");
      return;
    }

    try {
      this.reimbursementId = await createReimbursementRecord({
        reimbursementName: this.reimbursementName
      });

      this.lineItems = [];
      this.showWorkspace = true;

      await this.loadExistingReimbursements();
    } catch (error) {
      this.showError(error);
    }
  }

  async loadLineItems() {
    const result = await getLineItems({
      reimbursementId: this.selectedReimbursementId
    });
    console.log("Loaded line items:", JSON.stringify(result));

    debugger;
    this.lineItems = result.map((item) => ({
      id: item.id,
      expenseDate: item.expenseDate,
      description: item.description,
      amount: item.amount,
      isScanned: item.isScanned,
      invoiceFile: { name: item.invoiceFileName, size: item.invoiceFileSize },
      invoiceContentDocumentId: item.invoiceContentDocumentId,
      paymentContentDocumentId: item.paymentContentDocumentId,
      //invoiceFileName: item.invoiceFileName,
      paymentFileName: item.paymentFileName,
      //invoiceFileSize: item.invoiceFileSize,
      paymentFileSize: item.paymentFileSize,
      scanStatus: item.scanCount > 0 ? `${item.scanCount} uploaded` : "Missing",
      paymentStatus:
        item.paymentCount > 0 ? `${item.paymentCount} uploaded` : "Missing",
      scanCount: item.scanCount,
      paymentCount: item.paymentCount
    }));
  }

  async addLineItem() {
    try {
      /* const lineId = await createLineItemRecord({
        reimbursementId: this.selectedReimbursementId
      }); */

      this.lineItems = [
        ...this.lineItems,
        {
          id: "lineId",
          expenseDate: null,
          description: "",
          amount: null,
          isScanned: false,
          scanStatus: "Missing",
          paymentStatus: "Missing",
          scanCount: 0,
          paymentCount: 0
        }
      ];
      this.scrollToBottom();
    } catch (error) {
      this.showError(error);
    }
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      const element = this.template.querySelector(
        '[data-id="lineItemsBottom"]'
      );

      if (element) {
        element.scrollIntoView({
          behavior: "smooth",
          block: "end"
        });
      }
    });
  }

  handleFieldChange(event) {
    const lineId = event.target.dataset.id;
    const field = event.target.dataset.field;
    const value = event.detail?.value ?? event.target.value;

    this.lineItems = this.lineItems.map((item) => {
      if (item.id === lineId) {
        return {
          ...item,
          [field]: value
        };
      }
      return item;
    });
  }

  async handleScanUpload(event) {
    const lineId = event.currentTarget.dataset.lineId;
    const files = event.detail.files;

    this.updateAttachmentStatus(lineId, "scan", files.length);

    this.showToast(
      "Receipt uploaded",
      "Scan Receipt uploaded. AI extraction can now be initiated.",
      "success"
    );

    // Next integration:
    // Pass files[0].documentId to the OCR/AI Apex service.
    // Populate date, description and amount from its response.
  }

  handlePaymentUpload(event) {
    const lineId = event.currentTarget.dataset.lineId;
    const files = event.detail.files;

    this.updateAttachmentStatus(lineId, "payment", files.length);

    this.showToast(
      "Payment proof uploaded",
      "Payment Receipt stored successfully.",
      "success"
    );

    // No OCR or AI processing for payment proof.
  }

  updateAttachmentStatus(lineId, type, uploadedCount) {
    this.lineItems = this.lineItems.map((item) => {
      if (item.id !== lineId) {
        return item;
      }

      if (type === "scan") {
        const count = item.scanCount + uploadedCount;

        return {
          ...item,
          scanCount: count,
          scanStatus: `${count} uploaded`
        };
      }

      const count = item.paymentCount + uploadedCount;

      return {
        ...item,
        paymentCount: count,
        paymentStatus: `${count} uploaded`
      };
    });
  }

  async deleteLineItem(event) {
    const lineId = event.currentTarget.dataset.id;

    try {
      await deleteLineItemRecord({ lineItemId: lineId });

      this.lineItems = this.lineItems.filter((item) => item.id !== lineId);

      this.showToast("Deleted", "Line item deleted.", "success");
    } catch (error) {
      this.showError(error);
    }
  }

  async saveChanges() {
    this.isSaving = true;

    try {
      const records = this.lineItems.map((item) => ({
        Id: item.id,
        Expense_Date__c: item.expenseDate,
        Description__c: item.description,
        Amount__c:
          item.amount === "" || item.amount === null
            ? null
            : Number(item.amount)
      }));

      await updateLineItems({ lineItems: records });

      this.showToast("Saved", "Reimbursement line items saved.", "success");
    } catch (error) {
      this.showError(error);
    } finally {
      this.isSaving = false;
    }
  }

  get totalAmount() {
    return this.lineItems.reduce(
      (total, item) => total + (Number(item.amount) || 0),
      0
    );
  }

  get completedItems() {
    return this.lineItems.filter(
      (item) => item.scanCount > 0 && item.paymentCount > 0
    ).length;
  }

  showToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }

  showError(error) {
    this.showToast(
      "Error",
      error?.body?.message || error?.message || "Unexpected error",
      "error"
    );
  }

  async handleExport() {
    try {
      if (!this.lineItems || this.lineItems.length === 0) {
        throw new Error("No reimbursement line items available to export.");
      }

      // Collect Invoice and Payment file IDs.
      const contentDocumentIds = [
        ...new Set(
          this.lineItems
            .flatMap((item) => [
              item.invoiceContentDocumentId,
              item.paymentContentDocumentId
            ])
            .filter(Boolean)
        )
      ];

      // Retrieve actual attachment contents.
      const files = contentDocumentIds.length
        ? await getFilesForExport({ contentDocumentIds })
        : [];

      // Create Excel workbook.
      const rows = this.lineItems.map((item) => {
        let expenseDate = "";

        if (item.expenseDate) {
          const [year, month, day] = item.expenseDate.split("-").map(Number);

          // Create a real JavaScript date using local date components.
          expenseDate = new Date(year, month - 1, day);
        }

        return {
          "Expense Date": expenseDate,
          Description: item.description || "",
          Amount: Number(item.amount) || 0
        };
      });

      const totalAmount = rows.reduce((total, item) => total + item.Amount, 0);

      rows.push({
        "Expense Date": "",
        Description: "Total",
        Amount: totalAmount
      });

      const worksheet = XLSX.utils.json_to_sheet(rows);
      for (let row = 2; row <= rows.length + 1; row++) {
        const dateCell = worksheet[`A${row}`];

        if (dateCell && dateCell.v instanceof Date) {
          dateCell.z = "dd-mmm-yyyy";
        }
      }

      for (let row = 2; row <= rows.length + 1; row++) {
        const amountCell = worksheet[`C${row}`];

        if (amountCell) {
          amountCell.z = "#,##0.00";
        }
      }
      const workbook = XLSX.utils.book_new();

      XLSX.utils.book_append_sheet(workbook, worksheet, "Reimbursement");

      const excelData = XLSX.write(workbook, {
        bookType: "xlsx",
        type: "array"
      });

      // Create ZIP.
      const zip = new JSZip();

      const reimbursementName = this.reimbursementName || "Reimbursement";

      const safeName = reimbursementName.replace(/[\\/:*?"<>|]/g, "_");

      zip.file(`${safeName}.xlsx`, excelData);

      // Add attachments.
      //const attachmentFolder = zip.folder("Attachments");

      // Add attachments directly to the ZIP root.
      // Add attachments directly to the ZIP root.
      files.forEach((file) => {
        const lineItem = this.lineItems.find(
          (item) =>
            item.invoiceContentDocumentId === file.contentDocumentId ||
            item.paymentContentDocumentId === file.contentDocumentId
        );

        if (!lineItem) {
          return;
        }

        // First 15 characters of description.
        let description = (lineItem.description || "Expense")
          .replace(/[\\/:*?"<>|]/g, "_")
          .substring(0, 15)
          .trim();

        // Replace the last character with 'x' if it is a number.
        if (/\d$/.test(description)) {
          description = description.slice(0, -1) + "x";
        }

        // Convert expense date to dd_MM.
        const dateParts = lineItem.expenseDate.split("-");
        const formattedDate = `${dateParts[2]}_${dateParts[1]}`;

        // Identify Invoice or Payment.
        const receiptType =
          lineItem.invoiceContentDocumentId === file.contentDocumentId
            ? "Invoice"
            : "Payment";

        // Preserve original extension.
        const extension = file.fileName.includes(".")
          ? file.fileName.substring(file.fileName.lastIndexOf("."))
          : "";

        const attachmentName = `${description}_${formattedDate}_${receiptType}${extension}`;

        zip.file(attachmentName, file.base64Data, {
          base64: true
        });
      });

      // Generate and download ZIP.
      const zipBlob = await zip.generateAsync({
        type: "blob"
      });

      const downloadUrl = URL.createObjectURL(zipBlob);
      const downloadLink = document.createElement("a");

      downloadLink.href = downloadUrl;
      downloadLink.download = `${safeName}.zip`;
      downloadLink.click();

      URL.revokeObjectURL(downloadUrl);
    } catch (error) {
      console.error("Export error:", error);

      // Use your existing toast/error handling if available.
      this.showToast(
        "Export Failed",
        error.body?.message || error.message,
        "error"
      );
    }
  }
  openEmailModal() {
    this.emailSubject = `Reimbursement - ${this.selectedReimbursementName || "For OCT 26"}`;

    this.isEmailModalOpen = true;
  }

  closeEmailModal() {
    this.isEmailModalOpen = false;
  }

  handleRecipientChange(event) {
    this.recipientEmail = event.target.value;
  }

  handleSubjectChange(event) {
    this.emailSubject = event.target.value;
  }

  handleEmailBodyChange(event) {
    this.emailBody = event.target.value;
  }
  async handleSendEmail() {
    if (!this.recipientEmail) {
      this.showEmailToast(
        "Validation Error",
        "Please enter a recipient email address.",
        "error"
      );
      return;
    }

    if (!this.lineItems || this.lineItems.length === 0) {
      this.showEmailToast(
        "No Data",
        "There are no reimbursement line items to send.",
        "error"
      );
      return;
    }

    this.isSendingEmail = true;

    try {
      // Build Excel rows.
      const rows = this.lineItems.map((item) => {
        let expenseDate = "";

        if (item.expenseDate) {
          const [year, month, day] = item.expenseDate.split("-").map(Number);

          expenseDate = new Date(year, month - 1, day);
        }

        return {
          "Expense Date": expenseDate,
          Description: item.description || "",
          Amount: Number(item.amount) || 0
        };
      });

      // Calculate total.
      const totalAmount = rows.reduce((total, item) => total + item.Amount, 0);

      rows.push({
        "Expense Date": "",
        Description: "Total",
        Amount: totalAmount
      });

      // Generate Excel workbook.
      const worksheet = XLSX.utils.json_to_sheet(rows);

      for (let row = 2; row <= rows.length; row++) {
        const dateCell = worksheet[`A${row}`];

        if (dateCell && dateCell.v) {
          dateCell.z = "dd-mmm-yyyy";
        }

        const amountCell = worksheet[`C${row}`];

        if (amountCell) {
          amountCell.z = "#,##0.00";
        }
      }

      const workbook = XLSX.utils.book_new();

      XLSX.utils.book_append_sheet(workbook, worksheet, "Reimbursement");

      const excelBase64 = XLSX.write(workbook, {
        bookType: "xlsx",
        type: "base64"
      });

      // Prepare individual receipt attachments.
      const emailAttachments = [];

      this.lineItems.forEach((item) => {
        const description = (item.description || "Expense")
          .replace(/[\\/:*?"<>|]/g, "_")
          .substring(0, 15)
          .trim();

        // Replace the last character with x if numeric.
        const safeDescription = /\d$/.test(description)
          ? description.slice(0, -1) + "x"
          : description;

        const dateParts = item.expenseDate ? item.expenseDate.split("-") : [];

        const formattedDate =
          dateParts.length === 3
            ? `${dateParts[2]}_${dateParts[1]}`
            : "No_Date";

        if (item.invoiceContentDocumentId) {
          emailAttachments.push({
            contentDocumentId: item.invoiceContentDocumentId,
            fileName: `${safeDescription}_${formattedDate}_Invoice`
          });
        }

        if (item.paymentContentDocumentId) {
          emailAttachments.push({
            contentDocumentId: item.paymentContentDocumentId,
            fileName: `${safeDescription}_${formattedDate}_Payment`
          });
        }
      });

      const reimbursementName =
        this.selectedReimbursementName || "Reimbursement";

      const safeName = reimbursementName.replace(/[\\/:*?"<>|]/g, "_");
      const ccAddresses = this.ccEmails
        ? this.ccEmails
            .split(/[;,]/)
            .map((email) => email.trim())
            .filter(Boolean)
        : [];

      // Send email through Apex.
      await sendReimbursementEmail({
        recipientEmail: this.recipientEmail,
        ccAddresses: ccAddresses,
        emailSubject: this.emailSubject,
        emailBody: this.emailBody,
        excelFileName: `${safeName}.xlsx`,
        excelBase64,
        contentDocumentIds: emailAttachments.map(
          (item) => item.contentDocumentId
        ),
        attachmentNames: emailAttachments.map((item) => item.fileName)
      });

      this.showEmailToast(
        "Success",
        "Reimbursement email sent successfully.",
        "success"
      );

      this.isEmailModalOpen = false;
    } catch (error) {
      console.error("Email sending error:", error);

      this.showEmailToast(
        "Email Failed",
        error.body?.message || error.message,
        "error"
      );
    } finally {
      this.isSendingEmail = false;
    }
  }

  handleCcChange(event) {
    this.ccEmails = event.target.value;
  }

  showEmailToast(title, message, variant) {
    this.dispatchEvent(
      new ShowToastEvent({
        title,
        message,
        variant
      })
    );
  }
}
