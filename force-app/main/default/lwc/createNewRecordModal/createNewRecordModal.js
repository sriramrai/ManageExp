import { api, track } from 'lwc';
import LightningModal from 'lightning/modal';
import { toString, log, logError, getCalendarDurationFromDays } from 'c/utilityClass';

// Duration fields where at least one (not just Year__c) must be provided.
const DURATION_FIELDS = ['Year__c', 'Month__c', 'Day__c'];

export default class CreateNewRecordModal extends LightningModal {
    @api content;
    durationError = '';

    get modalObj() {
        let myObj = this.content;
        return myObj;
    }

    handleOkay(message) {
        let closeMessage = message == null ? 'ok' : message;
        this.content = null;
        this.close(closeMessage);
    }

    handleSave(event) {
        log('inside handle save*****');
        let inputForm = this.template.querySelector("lightning-record-edit-form");
        log('inputForm**** : '+inputForm); 
        log('inputForm fields*** : '+inputForm.fields);
        inputForm.submit();
    }

    handleSubmit(event) {
        const fields = event.detail.fields;

        // NOTE: `fields` coming from event.detail can be a null-prototype /
        // sandboxed object, so calling fields.hasOwnProperty(...) directly
        // can throw instead of returning false. Use the `in` operator,
        // which is safe regardless of the object's prototype chain.
        let hasDurationFields = false;

        try {
            hasDurationFields = DURATION_FIELDS.some(
                (fieldName) => fieldName in fields
            );
        } catch (error) {
            logError('Error inspecting submitted fields: ' + error);
        }

        if (!hasDurationFields) {
            return;
        }

        // We own duration validation/derivation here since none of
        // Year__c/Month__c/Day__c is individually marked required.
        // preventDefault is called up-front (before touching field values)
        // so any unexpected error below can never silently fall through
        // to a native submit with the raw, untransformed values.
        event.preventDefault();

        try {
            const yearVal = Number(fields.Year__c) || 0;
            const monthVal = Number(fields.Month__c) || 0;
            const dayVal = Number(fields.Day__c) || 0;

            if (yearVal === 0 && monthVal === 0 && dayVal === 0) {
                this.durationError =
                    'Please provide at least one of Year, Month or Day.';
                return;
            }

            // If only "Day" was provided, treat it as a total tenure in
            // days (e.g. "555") and derive the calendar Year/Month/Day
            // split from the Start Date, instead of saving 555 into
            // Day__c as-is.
            if (yearVal === 0 && monthVal === 0 && dayVal > 0) {
                const [years, months, days] = getCalendarDurationFromDays(
                    fields.Start_Date__c,
                    dayVal
                );

                fields.Year__c = years;
                fields.Month__c = months;
                fields.Day__c = days;
            }

            this.durationError = '';

            const inputForm = this.template.querySelector(
                'lightning-record-edit-form'
            );
            inputForm.submit(fields);
        } catch (error) {
            logError('Error deriving duration fields: ' + error);
            this.durationError =
                'Unable to process the Year/Month/Day duration. Please check the values.';
        }
    }

    handleSuccess(event) {
        console.log('record saved successfully... : '+this.modalObj.fieldList[4].value);
        //let response = "{'STATUS': 'CREATED', 'BANK': this.modalObj.fieldList[4].value)}";
        const responseObj = {'STATUS': 'CREATED', 'BANK': this.modalObj.fieldList[4].value};
        this.handleOkay(responseObj);
    }

    handleError(event) {
        console.log('Error occured while saving record...');
    }
}