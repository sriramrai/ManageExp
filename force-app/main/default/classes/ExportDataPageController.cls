public with sharing class ExportDataPageController {
    String objectName;
    String groupedField;
    Date fromDate;
    Date toDate;
    String filter;
    public ExportDataPageController() {
        objectName = ApexPages.currentPage().getParameters().get('objectName');
        groupedField = ApexPages.currentPage().getParameters().get('groupedField');
        fromDate = Date.valueOf(ApexPages.currentPage().getParameters().get('fromDate'));
        toDate = Date.valueOf(ApexPages.currentPage().getParameters().get('toDate'));
        filter = ApexPages.currentPage().getParameters().get('filterField');
    }
}