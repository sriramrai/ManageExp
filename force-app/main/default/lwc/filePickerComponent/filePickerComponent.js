import { LightningElement, api } from "lwc";

export default class FilePickerComponent extends LightningElement {
  @api label = "Upload File";
  @api accept = ".jpg,.jpeg,.png,.pdf";
  @api maxFileSize = 1572864; // 1.5 MB

  @api fileName;
  contentType = "";
  base64Data = "";
  @api fileSize;
  errorMessage = "";

  async handleFileChange(event) {
    const file = event.target.files[0];

    if (!file) {
      return;
    }

    this.errorMessage = "";

    if (file.size > this.maxFileSize) {
      this.errorMessage = "File size must not exceed 1.5 MB.";
      event.target.value = null;
      return;
    }

    try {
      const base64Data = await this.readFileAsBase64(file);

      this.fileName = file.name;
      this.contentType = file.type;
      this.base64Data = base64Data;
      this.fileSize = this.formatFileSize(file.size);

      this.dispatchEvent(
        new CustomEvent("filechange", {
          detail: {
            fileName: this.fileName,
            contentType: this.contentType,
            base64Data: this.base64Data
          },
          bubbles: true,
          composed: true
        })
      );
    } catch (error) {
      this.errorMessage = "Unable to read the selected file.";
      this.clearFile();
    }
  }

  readFileAsBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();

      reader.onload = () => {
        const result = reader.result;
        resolve(result.split(",")[1]);
      };

      reader.onerror = () => {
        reject(new Error("File reading failed."));
      };

      reader.readAsDataURL(file);
    });
  }

  formatFileSize(bytes) {
    return bytes < 1024 * 1024
      ? `${(bytes / 1024).toFixed(1)} KB`
      : `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
  }

  handleRemove() {
    this.clearFile();

    const input = this.template.querySelector('input[type="file"]');

    if (input) {
      input.value = null;
    }

    this.dispatchEvent(
      new CustomEvent("filechange", {
        detail: {
          fileName: null,
          contentType: null,
          base64Data: null
        },
        bubbles: true,
        composed: true
      })
    );
  }

  clearFile() {
    this.fileName = "";
    this.contentType = "";
    this.base64Data = "";
    this.fileSize = "";
  }
}
