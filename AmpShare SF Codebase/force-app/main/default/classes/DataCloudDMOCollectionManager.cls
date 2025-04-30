public class DataCloudDMOCollectionManager {
    
    // Invocable method that can be called from Flow
    @InvocableMethod(label='Get DMO Records Collection' 
                    description='Retrieves DMO records as a collection for use in Flow')
    public static List<Result> getDMORecords(List<Request> requests) {
        List<Result> results = new List<Result>();
        
        for (Request req : requests) {
            Result res = new Result();
            try {
                // Call the method to query DMO records
                List<String> recordCollection = queryDataCloudRecords(
                    req.objectApiName, 
                    req.whereClause, 
                    req.fieldList, 
                    req.maxRecords
                );
                
                res.success = true;
                res.recordCollection = recordCollection;
                res.errorMessage = '';
            } catch (Exception e) {
                res.success = false;
                res.recordCollection = new List<String>();
                res.errorMessage = e.getMessage();
            }
            results.add(res);
        }
        
        return results;
    }
    
    // Helper method to query DMO records using HTTP callout
    private static List<String> queryDataCloudRecords(
        String objectApiName, 
        String whereClause, 
        String fieldList, 
        Integer maxRecords
    ) {
        // Ensure object name has the DMO suffix if needed
        if (!objectApiName.endsWith('__dlm')) {
            objectApiName += '__dlm';
        }
        
        // Default field list if none provided
        if (String.isBlank(fieldList)) {
            fieldList = 'Id,Name';
        }
        
        // Build SOQL query
        String soqlQuery = 'SELECT ' + fieldList + ' FROM ' + objectApiName;
        if (!String.isBlank(whereClause)) {
            soqlQuery += ' WHERE ' + whereClause;
        }
        if (maxRecords != null && maxRecords > 0) {
            soqlQuery += ' LIMIT ' + maxRecords;
        }
        /*
        // URL encode the query
        String encodedQuery = EncodingUtil.urlEncode(soqlQuery, 'UTF-8');
        
        // Get org domain URL
        String baseUrl = System.Url.getOrgDomainUrl().toExternalForm();
        String endpoint = baseUrl + '/services/data/v58.0/query/?q=' + encodedQuery;
        
        // Set up HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + UserInfo.getSessionId());
        req.setHeader('Content-Type', 'application/json');
        
        // Send the request
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        // Process the response
        List<String> recordCollection = new List<String>();
        if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
            // Parse the response
            Map<String, Object> responseMap = (Map<String, Object>)JSON.deserializeUntyped(res.getBody());
            List<Object> records = (List<Object>)responseMap.get('records');
            
            if (records != null) {
                for (Object record : records) {
                    // Convert each record to a JSON string
                    String jsonRecord = JSON.serialize(record);
                    recordCollection.add(jsonRecord);
                }
            }
        }
        else {
            // Error
            throw new DMOException('Failed to query DMO records. Status: ' + res.getStatusCode() + ', Response: ' + res.getBody());
        }
        */
                List<String> recordCollection = new List<String>();

                    List<Object> records = database.Query(soqlQuery);
                    if (records != null) {
                for (Object record : records) {
                    // Convert each record to a JSON string
                    String jsonRecord = JSON.serialize(record);
                    recordCollection.add(jsonRecord);
 }
 }
       
        
        return recordCollection;
    }
    
    // Inner classes for request and response
    public class Request {
        @InvocableVariable(required=true label='DMO Object API Name' 
                          description='API Name of the DMO object (with or without __dlm suffix)')
        public String objectApiName;
        
        @InvocableVariable(required=false label='Where Clause' 
                          description='SOQL WHERE clause (without the word WHERE)')
        public String whereClause;
        
        @InvocableVariable(required=false label='Field List' 
                          description='Comma-separated list of fields to retrieve')
        public String fieldList;
        
        @InvocableVariable(required=false label='Max Records' 
                          description='Maximum number of records to retrieve')
        public Integer maxRecords;
    }
    
    public class Result {
        @InvocableVariable(label='Success' 
                          description='Whether the operation succeeded')
        public Boolean success;
        
        @InvocableVariable(label='Record Collection' 
                          description='Collection of DMO records as JSON strings')
        public List<String> recordCollection;
        
        @InvocableVariable(label='Error Message' 
                          description='Error message if the operation failed')
        public String errorMessage;
    }
    
    // Custom exception class
    public class DMOException extends Exception {}
}