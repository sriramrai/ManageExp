import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';


export default class ExpenseServices extends NavigationMixin(LightningElement) {
  
    divClickHandler(event) {
        console.log('inside div click handler...');
        let clickedAction = event.target.dataset.id;
        let componentName = this.getComponentName(clickedAction);
        if(componentName != null) {
            event.preventDefault();
            let componentDef = {
                componentDef: componentName,
                attributes: {
                    label: 'Navigated From Another LWC Without Using Aura'
                },
                state: {
                    name: 'test'
                }
            };
            let encodedComponentDef = btoa(JSON.stringify(componentDef));
            this[NavigationMixin.Navigate]({
                type: 'standard__webPage',
                attributes: {
                    url: '/one/one.app#' + encodedComponentDef
                }
            });
        }
    }

    getComponentName(action) {
        switch(action) {
            case 'Declaration' :
                return 'c:declarationComp';
            case 'Earning' : 
                return 'c:manageEarning';
            case 'Investment' :
                return 'c:manageInvestment';
            default:
                return null;
        }
    }

}