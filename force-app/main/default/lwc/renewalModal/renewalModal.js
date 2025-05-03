import { api } from 'lwc';
import {log} from 'c/utilityClass';
import LightningModal from 'lightning/modal';

export default class RenewalModal extends LightningModal {
    @api content;
    @api desc;
    
    get recordId() {
        if(this.content != null) {
            let infos = this.content.split("#");
            return infos[0];
        }
    }

    get headerLabel() {
        if(this.content != null) {
            console.log('Header Label******* : '+this.content);
            let infos = this.content.split("#");
            return 'Renewal / Closure - '+infos[1];
        }
    }

    handleOkay(message) {
        let closeMessage = message == null ? 'ok' : message;
        this.content = null;
        this.close(closeMessage);
    }

    handleSave() {
        log('inside handle save****');
        let renewalComponent = this.template.querySelector("c-operatefds");
        renewalComponent.handleSave();
    }
    
    successHandler(event) {
        this.handleOkay('refresh');
    }
}