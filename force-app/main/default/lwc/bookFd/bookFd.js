import { api, track } from "lwc";
import LightningModal from "lightning/modal";
import { toString, log, logError } from "c/utilityClass";

export default class BookFd extends LightningModal {
  autoCreate = false;

  buttonClickHandler(event) {
    const clickedButton = event.target.name;
    if (clickedButton === "createManual") {
      this.close("createManual");
    } else if (clickedButton === "autoCreate") {
      this.autoCreate = true;
    }
  }

  submitHandler(event) {
    let data = event.detail.data;
    this.close(JSON.stringify(data));
  }
}
