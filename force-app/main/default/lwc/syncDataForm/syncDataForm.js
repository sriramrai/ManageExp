import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getAvailableObjects from '@salesforce/apex/SyncDataController.getAvailableObjects';
import getChildObjects from '@salesforce/apex/SyncDataController.getChildObjects';
import getReferenceFields from '@salesforce/apex/SyncDataController.getReferenceFields';
import getRelationshipFields from '@salesforce/apex/SyncDataController.getRelationshipFields';
import createSyncDataRecord from '@salesforce/apex/SyncDataController.createSyncDataRecord';

export default class SyncDataForm extends NavigationMixin(LightningElement) {
    @track objectList = [];
    @track l2ObjectList = [];
    @track l3ObjectList = [];
    @track l2RefFields = [];
    @track l3RefFields = [];

    @track selectedL1Object = '';
    @track selectedL2Object = '';
    @track selectedL3Object = '';
    @track selectedL2RefField = '';
    @track selectedL3RefField = '';
    @track dateFilter = null;

    @track isLoading = false;
    @track showToast = false;
    @track toastMessage = '';
    @track toastVariant = 'info';
    
    @track l2Disabled = true;
    @track l3Disabled = true;
    @track l2RefFieldsDisabled = true;
    @track l3RefFieldsDisabled = true;

    // Computed requirements for conditional fields
    get isL2RefRequired() {
        return !!this.selectedL2Object;
    }
    get isL3RefRequired() {
        return !!this.selectedL3Object;
    }

    connectedCallback() {
        this.loadAvailableObjects();
    }

    async loadAvailableObjects() {
        this.isLoading = true;
        try {
            const result = await getAvailableObjects();
            this.objectList = result.map(obj => ({
                label: obj.label,
                value: obj.value
            }));
        } catch (error) {
            console.error('Error fetching objects:', error);
            this.showToastMessage('Error loading objects', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleL1Change(event) {
        this.selectedL1Object = event.detail.value;
        this.selectedL2Object = '';
        this.selectedL3Object = '';
        this.selectedL2RefField = '';
        this.selectedL3RefField = '';
        
        this.l2ObjectList = [];
        this.l3ObjectList = [];
        this.l2RefFields = [];
        this.l3RefFields = [];
        
        this.l2Disabled = true;
        this.l3Disabled = true;
        this.l2RefFieldsDisabled = true;
        this.l3RefFieldsDisabled = true;

        if (this.selectedL1Object) {
            this.loadChildObjectsForL1();
        }
    }

    async loadChildObjectsForL1() {
        this.isLoading = true;
        try {
            const result = await getChildObjects({ parentObjectName: this.selectedL1Object });
            console.log('Child objects for L1:', result); // Debug log
            this.l2ObjectList = result.map(obj => ({
                label: obj.label,
                value: obj.value
            }));
            this.l2Disabled = false;
        } catch (error) {
            console.error('Error fetching child objects for L1:', error);
            this.showToastMessage('Error loading child objects for L1', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async handleL2Change(event) {
        this.selectedL2Object = event.detail.value;
        this.selectedL3Object = '';
        this.selectedL3RefField = '';
        
        this.l3ObjectList = [];
        this.l3RefFields = [];
        
        this.l3Disabled = true;
        this.l3RefFieldsDisabled = true;

        if (this.selectedL2Object) {
            // Load options first so the selected value exists in the combobox options
            await this.loadReferenceFieldsForL2();
            this.loadChildObjectsForL2();

            // Auto-populate L2 Reference Field with field API name from L1 to L2 relationship
            if (this.selectedL1Object) {
                await this.autoPopulateL2RefField(this.selectedL1Object, this.selectedL2Object);
            }
        }
    }

    async loadReferenceFieldsForL2() {
        this.isLoading = true;
        try {
            const result = await getReferenceFields({ objectName: this.selectedL2Object });
            this.l2RefFields = result.map(field => ({
                label: field.label,
                value: field.value
            }));
            this.l2RefFieldsDisabled = false;
        } catch (error) {
            console.error('Error fetching reference fields for L2:', error);
            this.showToastMessage('Error loading reference fields for L2', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    async loadChildObjectsForL2() {
        this.isLoading = true;
        try {
            const result = await getChildObjects({ parentObjectName: this.selectedL2Object });
            console.log('Child objects for L2:', result); // Debug log
            this.l3ObjectList = result.map(obj => ({
                label: obj.label,
                value: obj.value
            }));
            this.l3Disabled = false;
        } catch (error) {
            console.error('Error fetching child objects for L2:', error);
            this.showToastMessage('Error loading child objects for L2', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleL2RefFieldChange(event) {
        this.selectedL2RefField = event.detail.value;
    }

    async handleL3Change(event) {
        this.selectedL3Object = event.detail.value;
        this.selectedL3RefField = '';
        
        if (this.selectedL3Object) {
            // Load options first so the selected value exists in the combobox options
            await this.loadReferenceFieldsForL3();

            // Auto-populate L3 Reference Field with field API name from L2 to L3 relationship
            if (this.selectedL2Object) {
                await this.autoPopulateL3RefField(this.selectedL2Object, this.selectedL3Object);
            }
        }
    }

    async loadReferenceFieldsForL3() {
        this.isLoading = true;
        try {
            const result = await getReferenceFields({ objectName: this.selectedL3Object });
            this.l3RefFields = result.map(field => ({
                label: field.label,
                value: field.value
            }));
            this.l3RefFieldsDisabled = false;
        } catch (error) {
            console.error('Error fetching reference fields for L3:', error);
            this.showToastMessage('Error loading reference fields for L3', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    handleL3RefFieldChange(event) {
        this.selectedL3RefField = event.detail.value;
    }

    handleDateChange(event) {
        // lightning-input type="date" emits value in YYYY-MM-DD
        this.dateFilter = event.target.value || null;
    }


    handleSave() {
        // L1 Object must always be selected
        if (!this.selectedL1Object) {
            this.showToastMessage('Please select an object for L1', 'error');
            return;
        }

        // L2 Object is optional, but if provided then L2 Ref Field is required
        if (this.selectedL2Object && !this.selectedL2RefField) {
            this.showToastMessage('Please select a reference field for L2', 'error');
            return;
        }

        // L3 Object is optional, but if provided then L3 Ref Field is required
        if (this.selectedL3Object && !this.selectedL3RefField) {
            this.showToastMessage('Please select a reference field for L3', 'error');
            return;
        }

        this.isLoading = true;
        createSyncDataRecord({
            l1Object: this.selectedL1Object,
            l2Object: this.selectedL2Object,
            l3Object: this.selectedL3Object,
            l2RefField: this.selectedL2RefField,
            l3RefField: this.selectedL3RefField,
            dateFilter: this.dateFilter ? new Date(this.dateFilter) : null
        })
        .then(result => {
            console.log('Create record result:', result); // Debug log
            
            // Show toast first
            this.showToastMessage('Sync Data configuration saved successfully!', 'success');
            
            // Navigate to the created record detail page after a delay to allow toast to render
            // Using a longer delay to ensure toast is visible
            const self = this;
            setTimeout(function() {
                if (result) {
                    // Ensure navigation happens only after toast is displayed
                    self[NavigationMixin.Navigate]({
                        type: 'standard__recordPage',
                        attributes: {
                            recordId: result,
                            actionName: 'view'
                        }
                    });
                } else {
                    console.error('No record ID returned from createSyncDataRecord');
                    self.showToastMessage('Error: Could not navigate to record', 'error');
                }
                // Reset form
                self.resetForm();
            }, 2000);
        })
        .catch(error => {
            console.error('Error saving record:', error);
            this.showToastMessage('Error saving record: ' + error.body.message, 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    resetForm() {
        this.selectedL1Object = '';
        this.selectedL2Object = '';
        this.selectedL3Object = '';
        this.selectedL2RefField = '';
        this.selectedL3RefField = '';
        this.dateFilter = null;
        
        this.l2ObjectList = [];
        this.l3ObjectList = [];
        this.l2RefFields = [];
        this.l3RefFields = [];
        
        this.l2Disabled = true;
        this.l3Disabled = true;
        this.l2RefFieldsDisabled = true;
        this.l3RefFieldsDisabled = true;
    }

    showToastMessage(message, variant) {
        this.toastMessage = message;
        this.toastVariant = variant;
        this.showToast = true;
        // Make sure toast stays visible for a reasonable amount of time
        setTimeout(() => {
            if (this.showToast) {
                this.showToast = false;
            }
        }, 5000);
    }

    // Helper method to auto-populate L2 Reference Field
    async autoPopulateL2RefField(l1Object, l2Object) {
        try {
            // Use the new Apex method to get relationship fields
            const result = await getRelationshipFields({ 
                parentObjectName: l1Object, 
                childObjectName: l2Object 
            });
            
            if (result && result.length > 0) {
                // Take the first relationship field found
                this.selectedL2RefField = result[0].value;
            } else {
                // Fallback to old approach if no relationship fields found
                const relationshipFieldName = l1Object.replace('__c', '') + '__c';
                if (this.l2RefFields.length > 0) {
                    const matchingField = this.l2RefFields.find(field => 
                        field.value.includes(l1Object.replace('__c', '')) || 
                        field.value.endsWith('__c')
                    );
                    
                    if (matchingField) {
                        this.selectedL2RefField = matchingField.value;
                    }
                }
            }
        } catch (error) {
            console.error('Error auto-populating L2 reference field:', error);
            // Fallback to old approach if there's an error
            const relationshipFieldName = l1Object.replace('__c', '') + '__c';
            if (this.l2RefFields.length > 0) {
                const matchingField = this.l2RefFields.find(field => 
                    field.value.includes(l1Object.replace('__c', '')) || 
                    field.value.endsWith('__c')
                );
                
                if (matchingField) {
                    this.selectedL2RefField = matchingField.value;
                }
            }
        }
    }

    // Helper method to auto-populate L3 Reference Field
    async autoPopulateL3RefField(l2Object, l3Object) {
        try {
            // Use the new Apex method to get relationship fields
            const result = await getRelationshipFields({ 
                parentObjectName: l2Object, 
                childObjectName: l3Object 
            });
            
            if (result && result.length > 0) {
                // Take the first relationship field found
                this.selectedL3RefField = result[0].value;
            } else {
                // Fallback to old approach if no relationship fields found
                const relationshipFieldName = l2Object.replace('__c', '') + '__c';
                if (this.l3RefFields.length > 0) {
                    const matchingField = this.l3RefFields.find(field => 
                        field.value.includes(l2Object.replace('__c', '')) || 
                        field.value.endsWith('__c')
                    );
                    
                    if (matchingField) {
                        this.selectedL3RefField = matchingField.value;
                    }
                }
            }
        } catch (error) {
            console.error('Error auto-populating L3 reference field:', error);
            // Fallback to old approach if there's an error
            const relationshipFieldName = l2Object.replace('__c', '') + '__c';
            if (this.l3RefFields.length > 0) {
                const matchingField = this.l3RefFields.find(field => 
                    field.value.includes(l2Object.replace('__c', '')) || 
                    field.value.endsWith('__c')
                );
                
                if (matchingField) {
                    this.selectedL3RefField = matchingField.value;
                }
            }
        }
    }
}
