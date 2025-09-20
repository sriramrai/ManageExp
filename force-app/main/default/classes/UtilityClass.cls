public with sharing class UtilityClass {
    public static void debug(String message, List<sObject> objs) {
        System.debug(message+'***** :'+JSON.serialize(objs));
    }
}