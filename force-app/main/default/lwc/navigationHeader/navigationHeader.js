import { LightningElement, api } from 'lwc';
import {log, logError, toString, isValidValue} from 'c/utilityClass';
import { NavigationMixin } from 'lightning/navigation';

export default class NavigationHeader extends NavigationMixin(LightningElement) {
    @api landingPage;
    isLoaded = false;

    renderedCallback() {
        log('inside rendered callback page.... : '+this.landingPage);
        if(isValidValue(this.landingPage && !this.isLoaded)) {
            let component;
            switch(this.landingPage) {
                case 'Declaration': 
                    component = this.refs.Declaration;
                    break;
                case 'Earning': 
                    component = this.refs.Earning;
                    break;
                case 'Investment' : 
                    component = this.refs.Investment;
                    break;
            }
            component.disabled = true;
            this.isLoaded = true;
        }
    }

    getComponentName() {
        switch(this.landingPage) {
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

    navigate() {
        let componentName = this.getComponentName();
        if(componentName != null) {
            //event.preventDefault();
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

    navigateToPage(event) {
        let buttonname = event.target.label;
        log('inside naviagte to page click....  : '+buttonname);
        this.landingPage = buttonname;
        this.navigate();
    }
}