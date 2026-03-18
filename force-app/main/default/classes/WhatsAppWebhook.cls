@RestResource(urlMapping='/whatsapp/webhook')
global without sharing class WhatsAppWebhook {

	@HttpGet
	global static void verifyWebhook() {
		RestRequest req = RestContext.request;
		RestResponse res = RestContext.response;
		String verifyToken = req.params.get('hub.verify_token');
		String challenge = req.params.get('hub.challenge');
		if (verifyToken == 'salesforce123') {
			res.responseBody = Blob.valueOf(challenge);
		} else {
			res.statusCode = 403;
		}
	}

	@HttpPost
	global static void receiveMessage() {

		RestRequest req = RestContext.request;

		String body = req.requestBody.toString();

		parsePayload(body);
	}

	public static ExpenseData parseLine(String line){
		ExpenseData data = new ExpenseData();
		line = line.trim();

		// ✅ Step 1: Extract date at start (dd/MM or dd/MM/yyyy)
		Pattern datePattern = Pattern.compile('^(\\d{2}/\\d{2}(?:/\\d{2,4})?)\\s+');
		Matcher dateMatcher = datePattern.matcher(line);
		if(dateMatcher.find()){
			String dateStr = dateMatcher.group(1);
			try{
				// If only dd/MM, append current year
				if(dateStr.split('/').size() == 2){
					dateStr += '/' + String.valueOf(Date.today().year());
				}
				List<String> parts = dateStr.split('/');
				data.expenseDate = Date.newInstance(Integer.valueOf(parts[2]), Integer.valueOf(parts[1]), Integer.valueOf(parts[0]));
			} catch(Exception e){
				data.expenseDate = Date.today();
			}
			// Remove date from line
			line = line.substring(dateMatcher.end()).trim();
		} else {
			data.expenseDate = Date.today();
		}

		// ✅ Step 2: Extract first number as amount
		Pattern amountPattern = Pattern.compile('^(\\d+)');
		Matcher amountMatcher = amountPattern.matcher(line);
		if(amountMatcher.find()){
			data.amount = Decimal.valueOf(amountMatcher.group(1));
			line = line.substring(amountMatcher.end()).trim();
		} else {
			data.amount = 0;
		}

		// ✅ Step 3: Remaining string is details
		data.details = line;

		return data;
	}

	public static void parsePayload(String jsonPayload){
		Map<String,Object> payload = (Map<String,Object>) JSON.deserializeUntyped(jsonPayload);
		List<Expense_Line_Item__c> expensesToInsert = new List<Expense_Line_Item__c>();
		List<Object> entries = (List<Object>) payload.get('entry');
		for(Object entryObj : entries){
			Map<String,Object> entry = (Map<String,Object>) entryObj;
			List<Object> changes = (List<Object>) entry.get('changes');

			for(Object changeObj : changes){
				Map<String,Object> change = (Map<String,Object>) changeObj;
				Map<String,Object> value = (Map<String,Object>) change.get('value');
				List<Object> messages = (List<Object>) value.get('messages');

				for(Object msgObj : messages){
					Map<String,Object> msg = (Map<String,Object>) msgObj;
					Map<String,Object> textMap = (Map<String,Object>) msg.get('text');
					String body = (String) textMap.get('body');

					// Split by new line (\n) to create multiple records
					List<String> lines = body.split('\\n');
					for(String line : lines){
						line = line.trim();
						if(String.isBlank(line)) continue;
						ExpenseData data = parseLine(line);
						Expense_Line_Item__c expenseLineItem = createExpenseLineItem(data);
						expensesToInsert.add(expenseLineItem);
					}
				}
			}
		}

		if(!expensesToInsert.isEmpty()){
			System.debug('Expense Data List: ' + JSON.serialize(expensesToInsert));
			insert expensesToInsert;
		}
	}

	public static Expense_Line_Item__c createExpenseLineItem(ExpenseData data) {
		Expense_Line_Item__c expenseLineItem = new Expense_Line_Item__c();
		expenseLineItem.debited_by__c = 'Other';
		expenseLineItem.Amount__c = data.amount;
		expenseLineItem.Date__c = data.expenseDate;
		expenseLineItem.Details__c = data.details;
		expenseLineItem.Expense__c = getExpense(data.expenseDate);
		expenseLineItem.Category__c = getExpenseCategory(data.details);
		expenseLineItem.Source__c = getExpenseSource(data.details);
		if(expenseLineItem.Source__c == 'Axis CC' || expenseLineItem.Source__c == 'ICICI CC') {
			expenseLineItem.EMI_Term__c = getEMITerm(data.details);
		}
		return expenseLineItem;
	}

	public static String getEMITerm(String details) {
		details = details.toLowerCase();
		if(details.contains('emi')) {
			Pattern p = Pattern.compile('\\b(\\d{1,2}m)\\b');
			Matcher m = p.matcher(details);
			String emiTenure = null;
			if (m.find()) {
				emiTenure = m.group(1);
			}
			if(String.isNotBlank(emiTenure)) {
				if(emiTenure == '3m') {
					return '3 Months';
				}else if(emiTenure == '6m') {
					return '3 Months';
				}else if(emiTenure == '12m') {
					return '12 Months';
				}else {
					return '1 Time';
				}
			}else {
				return '1 Time';
			}
		}else {
			return '1 Time';
		}
	}

	public static String getExpenseSource(String details) {
		details = details.toLowerCase();
		if(details.contains('axis')) {
			return 'Axis CC';
		}
		if(details.contains('icici')) {
			return 'ICICI CC';
		}
		if(details.contains('phone')) {
			return 'Phone';
		}
		if(details.contains('apay')) {
			return 'Apay';
		}
		if(details.contains('pluxee')) {
			return 'Pluxee';
		}
		if(details.contains('cash')) {
			return 'Cash';
		}
		return 'Gpay';
	}

	public static Id getExpense(Date expenseDate) {
		System.debug('expenseDate*** : '+expenseDate);
		System.debug('Query Result*** '+[SELECT Id, Name, Start_Date__c FROM Expense__c]);
		Expense__c expense = [SELECT Id, Name FROM Expense__c WHERE Start_Date__c <= :expenseDate AND End_Date__c >= :expenseDate ORDER BY Start_Date__c DESC LIMIT 1];
		return expense.Id;
	}

	public static String getExpenseCategory(String details) {
		details = details.toLowerCase();
		if(details.contains('milk')){
			return 'Milk';
		}
		if(details.contains('grocery') || 
			details.contains('dal') || 
			details.contains('ata') || 
			details.contains('besan') || 
			details.contains('market')){
			return 'Grocery';
		}
		if(details.contains('shopping') || 
			details.contains('shop') ||  
			details.contains('suit') || 
			details.contains('zudio') || 
			details.contains('mashala') ||
			details.contains('kirana')){
			return 'Shopping';
		}   
		if(details.contains('travel') || 
			details.contains('ticket') || 
			details.contains('cab') ||
			details.contains('train') ||
			details.contains('ola') ||
			details.contains('uber') ||
			details.contains('bus') ||
			details.contains('hotel')){
			return 'Travel';
		}
		if(details.contains('medical') || 
			details.contains('doctor') || 
			details.contains('vaccine') || 
			details.contains('medicine') || 
			details.contains('hospital') || 
			details.contains('pharmacy')){
			return 'Medical';
		}
		if(details.contains('utility') || 
			details.contains('bill') || 
			details.contains('electricity') || 
			details.contains('mobile') || 
			details.contains('recharge') || 
			details.contains('water') || 
			details.contains('internet') || 
			details.contains('phone') || 
			details.contains('tv') ||
			details.contains('maint') ||
			details.contains('maintenance')){
			return 'Utility & Bill';
		}
		if(details.contains('Other')){
			return 'Other';
		}
		return 'Other';
	}

	public class ExpenseData {
		public Decimal amount;
		public Date expenseDate;
		public String details;
		public String source;
	}
}