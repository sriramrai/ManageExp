import { LightningElement, api, track } from 'lwc';
import analyzeData from '@salesforce/apex/SyncDataController.analyzeData';
import checkSyncStatus from '@salesforce/apex/SyncDataController.checkSyncStatus';

export default class SyncAnalyzer extends LightningElement {
    // Record Id is provided automatically when used as a record action
    @api recordId;
    
    @track l1Size = 0;
    @track l2Size = 0;
    @track l3Size = 0;
    @track isLoading = false;
    @track error = null;
    @track progressValue = 0; // 0 - 100
    @track progressMessage = 'Retriving sriram...';
    pollTimerId;

    connectedCallback() {
        // Call analyzeData when component loads
        this.callAnalyzeData();
    }

    callAnalyzeData() {
        this.isLoading = true;
        this.error = null;
        
        analyzeData({ syncDataId: this.recordId })
            .then(result => {
                console.log('API Response:', result);
                this.parseResponse(result);
                this.isLoading = false;
            })
            .catch(error => {
                console.log('API Error:', error);
                // Format error properly for display
                if (error.body && error.body.message) {
                    this.error = error.body.message;
                } else if (error.message) {
                    this.error = error.message;
                } else {
                    this.error = 'An unknown error occurred';
                }
                this.isLoading = false;
            });
    }

    parseResponse(response) {
        try {
            // Try to parse as JSON
            let parsedResponse;
            if (typeof response === 'string') {
                parsedResponse = JSON.parse(response);
            } else {
                parsedResponse = response;
            }
            
            // Extract l1Size, l2Size, l3Size if they exist and are greater than 0
            if (parsedResponse && typeof parsedResponse === 'object') {
                if (parsedResponse.l1Size !== undefined && parsedResponse.l1Size > 0) {
                    this.l1Size = parsedResponse.l1Size;
                }
                if (parsedResponse.l2Size !== undefined && parsedResponse.l2Size > 0) {
                    this.l2Size = parsedResponse.l2Size;
                }
                if (parsedResponse.l3Size !== undefined && parsedResponse.l3Size > 0) {
                    this.l3Size = parsedResponse.l3Size;
                }
            }
        } catch (e) {
            console.error('Error parsing response:', e);
            // If parsing fails, just set the raw response
            this.l1Size = 0;
            this.l2Size = 0;
            this.l3Size = 0;
        }
    }

    handleRetrieve() {
        // Guard against duplicate clicks
        if (this.isLoading) {
            return;
        }
        console.log('Retrieve button clicked');
        this.error = null;

        // Reset and show determinate progress
        this.progressValue = 0;
        this.isLoading = true;

        // Clear any prior poller
        if (this.pollTimerId) {
            window.clearInterval(this.pollTimerId);
            this.pollTimerId = undefined;
        }

        // Start polling Apex for status repeatedly
        const intervalMs = 800; // adjust as needed
        const doPoll = async () => {
            try {
                // Expect Apex to return something like { progress: number(0-100), done: boolean, l1Size, l2Size, l3Size, message }
                const res = await checkSyncStatus({ syncDataId: this.recordId, isFetch: true });
                // Normalize both stringified JSON or object
                const payload = typeof res === 'string' ? JSON.parse(res) : res;

                // Map progress
                if (payload && typeof payload.progress === 'number') {
                    this.progressValue = Math.max(0, Math.min(100, Math.floor(payload.progress)));
                }

                this.progressMessage = payload.message;
                //this.progressMessage = 'payload.message';

                // Optional sizes/status from server
                if (payload && typeof payload.l1Size === 'number') this.l1Size = payload.l1Size;
                if (payload && typeof payload.l2Size === 'number') this.l2Size = payload.l2Size;
                if (payload && typeof payload.l3Size === 'number') this.l3Size = payload.l3Size;

                // Completion
                if (payload && (payload.done === true || this.progressValue >= 100)) {
                    if (this.pollTimerId) {
                        window.clearInterval(this.pollTimerId);
                        this.pollTimerId = undefined;
                    }
                    this.progressValue = 100;
                    this.isLoading = false;
                }
            } catch (e) {
                // Stop polling on error and surface message
                if (this.pollTimerId) {
                    window.clearInterval(this.pollTimerId);
                    this.pollTimerId = undefined;
                }
                this.isLoading = false;
                if (e && e.body && e.body.message) {
                    this.error = e.body.message;
                } else if (e && e.message) {
                    this.error = e.message;
                } else {
                    this.error = 'Failed to check sync status';
                }
            }
        };

        // Kickoff immediately then set interval
        doPoll();
        this.pollTimerId = window.setInterval(doPoll, intervalMs);
    }

    handleCommit() {
        if (this.isLoading) {
            return;
        }
        console.log('Commit button clicked');
        this.error = null;

        // Use same determinate UI; server may or may not update progress for commit
        this.progressValue = 0;
        this.isLoading = true;

        // Stop any previous poller
        if (this.pollTimerId) {
            window.clearInterval(this.pollTimerId);
            this.pollTimerId = undefined;
        }

        // For now, simulate brief commit completion; hook to Apex if needed
        const intervalMs = 800; // adjust as needed
        const doPoll = async () => {
            try {
                // Expect Apex to return something like { progress: number(0-100), done: boolean, l1Size, l2Size, l3Size, message }
                const res = await checkSyncStatus({ syncDataId: this.recordId, isFetch: false});
                // Normalize both stringified JSON or object
                const payload = typeof res === 'string' ? JSON.parse(res) : res;

                // Map progress
                if (payload && typeof payload.progress === 'number') {
                    this.progressValue = Math.max(0, Math.min(100, Math.floor(payload.progress)));
                }

                this.progressMessage = payload.message;
                //this.progressMessage = 'payload.message';

                // Optional sizes/status from server
                if (payload && typeof payload.l1Size === 'number') this.l1Size = payload.l1Size;
                if (payload && typeof payload.l2Size === 'number') this.l2Size = payload.l2Size;
                if (payload && typeof payload.l3Size === 'number') this.l3Size = payload.l3Size;

                // Completion
                if (payload && (payload.done === true || this.progressValue >= 100)) {
                    if (this.pollTimerId) {
                        window.clearInterval(this.pollTimerId);
                        this.pollTimerId = undefined;
                    }
                    this.progressValue = 100;
                    this.isLoading = false;
                }
            } catch (e) {
                // Stop polling on error and surface message
                if (this.pollTimerId) {
                    window.clearInterval(this.pollTimerId);
                    this.pollTimerId = undefined;
                }
                this.isLoading = false;
                if (e && e.body && e.body.message) {
                    this.error = e.body.message;
                } else if (e && e.message) {
                    this.error = e.message;
                } else {
                    this.error = 'Failed to check sync status';
                }
            }
        };

        // Kickoff immediately then set interval
        doPoll();
        this.pollTimerId = window.setInterval(doPoll, intervalMs);
    }
    // Ensure timers are cleared when component is destroyed
    disconnectedCallback() {
        if (this.pollTimerId) {
            window.clearInterval(this.pollTimerId);
            this.pollTimerId = undefined;
        }
    }
}
