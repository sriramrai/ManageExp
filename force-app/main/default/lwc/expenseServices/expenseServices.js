import { LightningElement } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';


export default class ExpenseServices extends NavigationMixin(LightningElement) {
  divClickHandler(event) {
    console.log('inside div click handler...');
    event.preventDefault();
        let componentDef = {
            componentDef: "c:declarationComp",
            attributes: {
                label: 'Navigated From Another LWC Without Using Aura'
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