import { LightningElement } from "lwc";
import { api, track } from "lwc";
import { toString, log, logError, isValidValue } from "c/utilityClass";

const MAX_OCR_ATTEMPTS = 5;

export default class OcrReader extends LightningElement {
  selectedFile = null;
  previewUrl = null;
  selectedFileSize = "";
  isProcessingOCR = false;
  ocrError = "";
  scrollToOCR = false;
  ocrAttempts = 0;
  ocrProgress = 0;

  /**
   * Reflects real progress based on attempt count rather than a
   * simulated animation, e.g. with MAX_OCR_ATTEMPTS = 5:
   * attempt 1 in flight -> 20%, attempt 3 in flight -> 60%, etc.
   * On success this is overridden to 100% regardless of which
   * attempt it succeeded on.
   */
  updateOcrProgressForAttempt() {
    this.ocrProgress = Math.min(
      100,
      Math.round((this.ocrAttempts / MAX_OCR_ATTEMPTS) * 100)
    );
  }

  renderedCallback() {
    if (!this.scrollToOCR) {
      return;
    }

    const element = this.template.querySelector('[data-id="ocrResult"]');

    if (element) {
      element.scrollIntoView({
        behavior: "smooth",
        block: "start"
      });

      this.scrollToOCR = false;
    }
  }

  openFilePicker() {
    const input = this.template.querySelector("[data-file-input]");

    if (input) {
      input.click();
    }
  }

  handleReceiptUpload(event) {
    const file = event.target.files?.[0];

    if (!file) {
      return;
    }
    this.autoCreate = true;

    // Validate image
    if (!file.type.startsWith("image/")) {
      this.ocrError = "Please select an image file.";

      return;
    }

    if (!file) {
      return;
    }

    console.log("Original size:", this.formatFileSize(file.size));

    if (file.type.startsWith("image/")) {
      this.compressImage(file).then((compressedFile) => {
        console.log(
          "Compressed size:",
          this.formatFileSize(compressedFile.size)
        );

        this.selectedFile = compressedFile;
        this.fileName = compressedFile.name;
        this.selectedFileSize = this.formatFileSize(compressedFile.size);
        this.previewUrl = URL.createObjectURL(compressedFile);
      });
    } else {
      this.selectedFile = file;
      this.fileName = file.name;
      this.selectedFileSize = this.formatFileSize(file.size);
      this.previewUrl = URL.createObjectURL(file);
    }
  }

  compressImage(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = (event) => {
        const img = new Image();

        img.onload = () => {
          const canvas = document.createElement("canvas");

          // Maximum dimensions
          const maxWidth = 1600;
          const maxHeight = 1600;

          let width = img.width;
          let height = img.height;

          // Resize while maintaining aspect ratio
          if (width > maxWidth || height > maxHeight) {
            const ratio = Math.min(maxWidth / width, maxHeight / height);

            width = Math.round(width * ratio);
            height = Math.round(height * ratio);
          }

          canvas.width = width;
          canvas.height = height;

          const ctx = canvas.getContext("2d");

          ctx.drawImage(img, 0, 0, width, height);

          // JPEG quality: 0.7 = good compression
          canvas.toBlob(
            (blob) => {
              if (!blob) {
                reject(new Error("Image compression failed"));
                return;
              }

              const compressedFile = new File(
                [blob],
                file.name.replace(/\.[^/.]+$/, "") + ".jpg",
                {
                  type: "image/jpeg",
                  lastModified: Date.now()
                }
              );

              resolve(compressedFile);
            },
            "image/jpeg",
            0.7
          );
        };

        img.onerror = () => {
          reject(new Error("Unable to load image"));
        };

        img.src = event.target.result;
      };

      reader.onerror = () => {
        reject(new Error("Unable to read file"));
      };

      reader.readAsDataURL(file);
    });
  }

  formatFileSize(bytes) {
    if (bytes === 0) {
      return "0 Bytes";
    }

    const units = ["Bytes", "KB", "MB", "GB"];

    const index = Math.floor(Math.log(bytes) / Math.log(1024));

    return (
      parseFloat((bytes / Math.pow(1024, index)).toFixed(2)) +
      " " +
      units[index]
    );
  }

  removeSelectedFile() {
    if (this.previewUrl) {
      URL.revokeObjectURL(this.previewUrl);
    }

    this.selectedFile = null;
    this.previewUrl = null;
    this.selectedFileSize = "";
    this.ocrError = "";

    const input = this.template.querySelector("[data-file-input]");

    if (input) {
      input.value = "";
    }
  }
  base64;
  async handleReadReceipt() {
    if (!this.selectedFile) {
      this.ocrError = "Please select an FD receipt first.";

      return;
    }

    this.isProcessingOCR = true;
    this.isLoading = true;
    this.ocrError = "";
    this.ocrAttempts = 0;
    this.ocrProgress = 0;

    try {
      this.base64 = await this.fileToBase64(this.selectedFile);

      await this.callFDReceiptOCR(this.base64, this.selectedFile.type);
    } catch (error) {
      console.error("OCR error:", error);

      this.ocrError = error?.message || "Unable to read FD receipt.";
      this.isProcessingOCR = false;
      this.isLoading = false;
      this.ocrProgress = 0;
    } finally {
      //this.isProcessingOCR = false;
    }
  }

  fileToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = () => {
        const result = reader.result;

        const base64 = result.split(",")[1];

        resolve(base64);
      };

      reader.onerror = () => {
        reject(new Error("Unable to read image."));
      };

      reader.readAsDataURL(file);
    });
  }

  async callFDReceiptOCR(base64, mimeType) {
    const WORKER_URL = "https://square-shape-db5a.raidipu55.workers.dev/ocr";

    this.ocrAttempts++;
    this.updateOcrProgressForAttempt();

    console.log("OCR Attempt:", this.ocrAttempts);

    try {
      const response = await fetch(WORKER_URL, {
        method: "POST",

        headers: {
          "Content-Type": "application/json"
        },

        body: JSON.stringify({
          image: base64,
          mimeType: mimeType
        })
      });

      const result = await response.json();

      /* const result = {
        success: true,
        data: {
          bank_name: "Axis Bank",
          account_number: "922040057066225",
          account_number_label: "",
          investment_date: "01/08/2026",
          interest_rate: "7.1%",
          principal_amount: "67668.0",
          duration: "555 days"
        }
      };
 */
      console.log("OCR Response:", JSON.stringify(result, null, 2));

      if (!response.ok || !result.success) {
        //throw new Error(result?.error || "OCR failed");

        if (this.ocrAttempts < MAX_OCR_ATTEMPTS) {
          await this.callFDReceiptOCR(this.base64, this.selectedFile.type);
        } else {
          throw new Error(
            result?.error || `OCR failed after ${MAX_OCR_ATTEMPTS} attempts.`
          );
        }

        return;
      }

      await this.populateFDFields(result.data);
    } catch (error) {
      if (this.ocrAttempts >= MAX_OCR_ATTEMPTS) {
        this.isProcessingOCR = false;
        this.isLoading = false;
        this.ocrProgress = 0;
        throw error;
      }

      throw error;
    }
  }

  readObj = {};
  async populateFDFields(data) {
    this.ocrSuccess = true;
    this.scrollToOCR = true;
    this.isProcessingOCR = false;
    this.bankName = data.bank_name || "";

    this.accountNumber = data.account_number || "";

    this.accountNumberLabel = data.account_number_label || "Account Number";

    this.investmentDate = data.investment_date || "";

    this.interestRate = data.interest_rate || "";

    this.principalAmount = data.principal_amount || "";

    this.duration = data.duration || "";

    if (
      this.accountNumber == "" ||
      this.bankName == "" ||
      this.investmentDate == "" ||
      this.interestRate == "" ||
      this.principalAmount == "" ||
      this.duration == ""
    ) {
      if (this.ocrAttempts < MAX_OCR_ATTEMPTS) {
        await this.callFDReceiptOCR(this.base64, this.selectedFile.type);
        return;
      } else {
        this.ocrError = `Unable to extract all FD receipt details after ${MAX_OCR_ATTEMPTS} attempts.`;
        this.isProcessingOCR = false;
        this.isLoading = false;
        this.ocrProgress = 0;
        return;
      }
    }

    // Success - regardless of which attempt it took, show full progress.
    this.ocrProgress = 100;
    this.isLoading = false;
    this.accountNumber = this.accountNumber.slice(-5);
    this.interestRate = this.interestRate.replace("%", "");
    this.investmentDate = this.convertToSalesforceDate(this.investmentDate);

    let durationArray = this.getDurationArray(
      this.investmentDate,
      this.duration
    );

    this.duration = durationArray.join("/");
    this.readObj["Amount__c"] = this.principalAmount;
    this.readObj["Rate__c"] = this.interestRate;
    this.readObj["Year__c"] = durationArray[0];
    this.readObj["Month__c"] = durationArray[1];
    this.readObj["Day__c"] = durationArray[2];
    this.readObj["Start_Date__c"] = this.investmentDate;
    this.readObj["Account_Number__c"] = this.accountNumber;
    this.readObj["Bank__c"] = this.bankName;
  }

  getDurationArray(investmentDate, duration) {
    if (!investmentDate || duration === null || duration === undefined) {
      return [0, 0, 0];
    }

    const dateParts = String(investmentDate).trim().split(/[\/-]/);

    if (dateParts.length !== 3) {
      return [0, 0, 0];
    }

    // Accept either "YYYY-MM-DD" (e.g. Salesforce-formatted dates)
    // or "DD/MM/YYYY" (e.g. raw OCR dates) by locating the 4-digit year.
    let day, month, year;

    if (dateParts[0].length === 4) {
      year = Number(dateParts[0]);
      month = Number(dateParts[1]);
      day = Number(dateParts[2]);
    } else {
      day = Number(dateParts[0]);
      month = Number(dateParts[1]);
      year = Number(dateParts[2]);
    }

    /*
     * Always create dates at UTC midnight.
     * This avoids timezone/DST problems.
     */
    const startDate = new Date(Date.UTC(year, month - 1, day));

    const durationText = String(duration).trim().toLowerCase();

    // ==================================================
    // CASE 1: Duration is a plain DAYS tenure (no explicit
    // "year"/"month" component), e.g.:
    // 555
    // "555 days"
    // "555 days."
    // "Duration: 555 days"
    //
    // Use word-boundary matching (no ^/$ anchors) so extra
    // leading/trailing text or punctuation from OCR/LLM output
    // doesn't cause this to be misread as CASE 2 below.
    // ==================================================

    const hasYearOrMonth = /\byears?\b|\bmonths?\b/.test(durationText);

    if (!hasYearOrMonth) {
      const daysMatch =
        durationText.match(/(\d+)\s*days?\b/) || durationText.match(/(\d+)/);

      if (daysMatch) {
        return this.convertTotalDaysToCalendarDuration(
          startDate,
          Number(daysMatch[1])
        );
      }
    }

    // ==================================================
    // CASE 2: Duration already contains
    // Years / Months / Days
    //
    // "1 year 2 months 14 days"
    // "2 years 5 months"
    // "0 Months 555 Days"
    // ==================================================

    const yearMatch = durationText.match(/(\d+)\s*years?/);
    const monthMatch = durationText.match(/(\d+)\s*months?/);
    const dayMatch = durationText.match(/(\d+)\s*days?/);

    const years = yearMatch ? Number(yearMatch[1]) : 0;
    const months = monthMatch ? Number(monthMatch[1]) : 0;
    const days = dayMatch ? Number(dayMatch[1]) : 0;

    // Some sources report e.g. "0 Months 555 Days" where "days" is
    // actually a *total* day count in disguise - no real calendar
    // month has more than 31 days as a remainder. When years/months
    // are both 0 but days is unrealistically large, re-derive the
    // calendar-accurate split from that total instead of saving the
    // raw (misleading) day count as-is.
    if (years === 0 && months === 0 && days > 31) {
      return this.convertTotalDaysToCalendarDuration(startDate, days);
    }

    return [years, months, days];
  }

  convertTotalDaysToCalendarDuration(startDate, totalDays) {
    const maturityDate = new Date(startDate);

    maturityDate.setUTCDate(maturityDate.getUTCDate() + totalDays);

    console.log("START DATE:", startDate.toISOString());

    console.log("TOTAL DAYS:", totalDays);

    console.log("MATURITY DATE:", maturityDate.toISOString());

    return this.calculateCalendarDuration(startDate, maturityDate);
  }

  calculateCalendarDifference(startDate, maturityDate) {
    let years = maturityDate.getFullYear() - startDate.getFullYear();

    let tempDate = new Date(startDate);
    tempDate.setFullYear(tempDate.getFullYear() + years);

    if (tempDate > maturityDate) {
      years--;

      tempDate = new Date(startDate);
      tempDate.setFullYear(tempDate.getFullYear() + years);
    }

    let months = 0;

    while (true) {
      const nextDate = new Date(tempDate);
      nextDate.setMonth(nextDate.getMonth() + 1);

      if (nextDate <= maturityDate) {
        months++;
        tempDate = nextDate;
      } else {
        break;
      }
    }

    const days = Math.round((maturityDate - tempDate) / (1000 * 60 * 60 * 24));

    return [years, months, days];
  }

  calculateCalendarDuration(startDate, maturityDate) {
    let years = maturityDate.getUTCFullYear() - startDate.getUTCFullYear();

    let tempDate = new Date(startDate);

    tempDate.setUTCFullYear(tempDate.getUTCFullYear() + years);

    // If anniversary is after maturity,
    // the last year was not complete.
    if (tempDate > maturityDate) {
      years--;

      tempDate = new Date(startDate);

      tempDate.setUTCFullYear(tempDate.getUTCFullYear() + years);
    }

    let months = 0;

    while (true) {
      const nextDate = new Date(tempDate);

      nextDate.setUTCMonth(nextDate.getUTCMonth() + 1);

      if (nextDate <= maturityDate) {
        months++;
        tempDate = nextDate;
      } else {
        break;
      }
    }

    const days = Math.round(
      (maturityDate.getTime() - tempDate.getTime()) / (24 * 60 * 60 * 1000)
    );

    console.log("FINAL:", years, months, days);

    return [years, months, days];
  }

  convertToSalesforceDate(dateString) {
    if (!dateString) {
      return null;
    }

    // Support both "/" and "-"
    const parts = dateString.trim().split(/[\/-]/);

    if (parts.length !== 3) {
      return null;
    }

    const day = parts[0].trim().padStart(2, "0");
    const month = parts[1].trim().padStart(2, "0");
    const year = parts[2].trim();

    return `${year}-${month}-${day}`;
  }

  handleSubmit(event) {
    const submitHandler = new CustomEvent("handlesubmit", {
      detail: {
        data: this.readObj
      }
    });
    this.dispatchEvent(submitHandler);
  }
}
