public without sharing class ErrorLogger {
  private static List<Error_Logs__c> pendingLogs = new List<Error_Logs__c>();

  /**
   * Collects an exception for later insertion.
   */
  public static void log(
    Exception ex,
    String className,
    String methodName,
    String additionalDetails
  ) {
    if (ex == null) {
      return;
    }

    try {
      String details = '';

      if (!String.isBlank(additionalDetails)) {
        details += additionalDetails + '\n\n';
      }

      details += 'Exception Type: ' + ex.getTypeName() + '\n';
      details += 'Exception Message: ' + ex.getMessage() + '\n';
      details += 'Stack Trace:\n' + ex.getStackTraceString();

      Schema.DescribeFieldResult classNameField = Error_Logs__c.Class_Name__c.getDescribe();

      Schema.DescribeFieldResult methodNameField = Error_Logs__c.Method_name__c.getDescribe();

      Schema.DescribeFieldResult detailsField = Error_Logs__c.Details__c.getDescribe();

      pendingLogs.add(
        new Error_Logs__c(
          Class_Name__c = truncate(className, classNameField.getLength()),
          Method_name__c = truncate(methodName, methodNameField.getLength()),
          Details__c = truncate(details, detailsField.getLength())
        )
      );
    } catch (Exception loggingException) {
      System.debug(
        LoggingLevel.ERROR,
        'ErrorLogger.log failed: ' + loggingException.getMessage()
      );
    }
  }

  /**
   * Inserts all collected error logs in one DML operation.
   */
  public static void saveLog() {
    if (pendingLogs.isEmpty()) {
      return;
    }

    List<Error_Logs__c> logsToSave = pendingLogs;
    pendingLogs = new List<Error_Logs__c>();

    try {
      Database.SaveResult[] results = Database.insert(logsToSave, false);

      for (Integer i = 0; i < results.size(); i++) {
        if (!results[i].isSuccess()) {
          for (Database.Error err : results[i].getErrors()) {
            System.debug(
              LoggingLevel.ERROR,
              'Error log insertion failed: ' + err.getMessage()
            );
          }
        }
      }
    } catch (Exception loggingException) {
      System.debug(
        LoggingLevel.ERROR,
        'ErrorLogger.saveLog failed: ' + loggingException.getMessage()
      );
    }
  }

  /**
   * Clears collected logs without inserting them.
   */
  public static void clearLogs() {
    pendingLogs.clear();
  }

  private static String truncate(String value, Integer maxLength) {
    if (String.isBlank(value) || maxLength == null || maxLength <= 0) {
      return value;
    }

    return value.length() > maxLength ? value.substring(0, maxLength) : value;
  }
}
