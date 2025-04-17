import { api } from 'lwc';
import LightningModal from 'lightning/modal';

export default class EditExpenseForm extends LightningModal {
    @api content;
    @api headerText;

    handleSuccess(event) {
        this.close(true);
    }
}