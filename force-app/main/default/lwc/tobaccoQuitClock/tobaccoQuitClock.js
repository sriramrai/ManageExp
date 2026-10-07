import { LightningElement } from "lwc";

export default class TobaccoQuitClock extends LightningElement {
  // Store your quit date/time here
  quitDateTime = "07/10/2026 17:15:00";

  elapsedTime = "0D 00H 00M 00S";

  intervalId;

  connectedCallback() {
    this.updateClock();

    // Update every second
    this.intervalId = setInterval(() => {
      this.updateClock();
    }, 1000);
  }

  disconnectedCallback() {
    if (this.intervalId) {
      clearInterval(this.intervalId);
    }
  }

  updateClock() {
    const quitTime = this.parseDateTime(this.quitDateTime);
    const currentTime = new Date();

    if (!quitTime || isNaN(quitTime.getTime())) {
      this.elapsedTime = "Invalid Date";
      return;
    }

    let difference = currentTime.getTime() - quitTime.getTime();

    // If quit time is in the future
    if (difference < 0) {
      difference = 0;
    }

    const totalSeconds = Math.floor(difference / 1000);

    const days = Math.floor(totalSeconds / (24 * 60 * 60));
    const hours = Math.floor((totalSeconds % (24 * 60 * 60)) / (60 * 60));
    const minutes = Math.floor((totalSeconds % (60 * 60)) / 60);
    const seconds = totalSeconds % 60;

    this.elapsedTime =
      `${days}D ` +
      `${this.pad(hours)}H ` +
      `${this.pad(minutes)}M ` +
      `${this.pad(seconds)}S`;
  }

  parseDateTime(dateTimeString) {
    // Expected format:
    // DD/MM/YYYY HH:mm:ss

    const [datePart, timePart] = dateTimeString.split(" ");

    if (!datePart || !timePart) {
      return null;
    }

    const [day, month, year] = datePart.split("/").map(Number);
    const [hours, minutes, seconds] = timePart.split(":").map(Number);

    return new Date(year, month - 1, day, hours, minutes, seconds);
  }

  pad(value) {
    return String(value).padStart(2, "0");
  }
}
