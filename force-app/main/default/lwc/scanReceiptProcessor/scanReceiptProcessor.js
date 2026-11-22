import { LightningElement, api } from "lwc";
import extractReceipt from "@salesforce/apex/GeminiReceiptService.extractReceipt";
const MAX_FILE_SIZE = 5 * 1024 * 1024;

export default class ScanReceiptProcessor extends LightningElement {
  @api reimbursementId;
  @api isScanned;

  @api file;
  previewUrl;
  showModal = false;

  expenseDate = "";
  description = "";
  amount = "";
  isScanning = false;
  errorMessage = "";

  get isImage() {
    return this.file && ["image/jpeg", "image/png"].includes(this.file.type);
  }

  get reviewButtonLabel() {
    return this.isScanning ? "Scanning Receipt..." : "Review Details";
  }

  get isPdf() {
    return this.file && this.file.type === "application/pdf";
  }

  get fileIcon() {
    return this.isPdf ? "doctype:pdf" : "doctype:image";
  }

  get fileSize() {
    return this.file ? `${(this.file.size / 1024).toFixed(1)} KB` : "";
  }

  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = () => {
        const base64 = reader.result.split(",")[1];
        resolve(base64);
      };

      reader.onerror = () => {
        reject(new Error("Unable to read the selected file."));
      };

      reader.readAsDataURL(file);
    });
  }

  handleFileSelection(event) {
    const selectedFile = event.target.files?.[0];

    if (!selectedFile) {
      return;
    }

    const allowedTypes = ["image/jpeg", "image/png", "application/pdf"];

    if (!allowedTypes.includes(selectedFile.type)) {
      this.showMessage(
        "Unsupported file",
        "Please select a JPG, PNG or PDF file.",
        "error"
      );
      event.target.value = "";
      return;
    }

    if (selectedFile.size > MAX_FILE_SIZE) {
      this.showMessage(
        "File too large",
        "Please select a file smaller than 5 MB.",
        "error"
      );
      event.target.value = "";
      return;
    }

    this.file = selectedFile;
    this.previewUrl = null;

    if (this.isImage) {
      const reader = new FileReader();

      reader.onload = () => {
        this.previewUrl = reader.result;
      };

      reader.onerror = () => {
        this.showMessage(
          "Preview error",
          "Unable to read the selected image.",
          "error"
        );
      };

      reader.readAsDataURL(selectedFile);
    }

    // Gemini extraction will be connected here.
    // The file is still only in browser memory.
  }

  async handleReview() {
    if (!this.file) {
      this.errorMessage = "Please select a receipt first.";
      return;
    }

    this.isScanning = true;
    this.errorMessage = "";

    try {
      // Convert selected file to Base64
      const fileBase64 = await this.readFileAsBase64(this.file);

      // Call Apex Gemini service
      const result = await extractReceipt({
        fileBase64: fileBase64,
        mimeType: this.file.type
      });

      // Populate extracted values in the review modal
      this.expenseDate = result.expense_date || "";
      this.description = result.description || "";

      this.amount =
        result.amount !== null && result.amount !== undefined
          ? String(result.amount)
          : "";

      // Open the confirmation modal
      this.showModal = true;
    } catch (error) {
      console.error("Receipt scanning error:", error);

      this.errorMessage =
        error?.body?.message ||
        error?.message ||
        "Unable to process the receipt. Please try again.";

      this.dispatchEvent(
        new CustomEvent("scannererror", {
          detail: this.errorMessage,
          bubbles: true,
          composed: true
        })
      );
    } finally {
      this.isScanning = false;
    }
  }

  handleDateChange(event) {
    this.expenseDate = event.target.value;
  }

  handleDescriptionChange(event) {
    this.description = event.target.value;
  }

  handleAmountChange(event) {
    this.amount = event.target.value;
  }

  handleConfirm() {
    const dateInput = this.template.querySelector('[data-id="expenseDate"]');

    const descriptionInput = this.template.querySelector(
      '[data-id="description"]'
    );

    const amountInput = this.template.querySelector('[data-id="amount"]');

    const expenseDate = dateInput.value;
    const description = descriptionInput.value?.trim();
    const amount = amountInput.value;

    if (!description || amount === "" || Number(amount) < 0) {
      this.errorMessage = "Please enter a valid description and amount.";
      return;
    }

    this.dispatchEvent(
      new CustomEvent("receiptconfirm", {
        detail: {
          expenseDate: expenseDate || null,
          description: description,
          amount: Number(amount),
          file: this.file
        },
        bubbles: true,
        composed: true
      })
    );

    this.showModal = false;
  }

  handleCancel() {
    this.showModal = false;
  }

  handleRemoveFile() {
    this.clearSelection();
  }

  clearSelection() {
    this.file = null;
    this.previewUrl = null;
    this.expenseDate = "";
    this.description = "";
    this.amount = "";

    const fileInput = this.template.querySelector(".file-input");

    if (fileInput) {
      fileInput.value = "";
    }
  }

  showMessage(title, message, variant) {
    this.dispatchEvent(
      new CustomEvent("scannererror", {
        detail: { title, message, variant },
        bubbles: true,
        composed: true
      })
    );
  }
}
