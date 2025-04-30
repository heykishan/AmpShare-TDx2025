public class FlowHTTPCalloutHandler {
    
    // Invocable method that can be called from Flow
    @InvocableMethod(label='Make HTTP Callout' description='Makes an HTTP request with customizable parameters')
    public static List<Result> makeCallout(List<Request> requests) {
        List<Result> results = new List<Result>();
        
        for (Request req : requests) {
            Result res = new Result();
            try {
                // Perform the callout
                HttpResponse response = sendHTTPRequest(
                    req.method,
                    req.endpoint,
                    req.requestBody,
                    req.headerKeys,
                    req.headerValues
                );
                
                // Process the response
                res.statusCode = response.getStatusCode();
                res.responseBody = response.getBody();
                res.success = (res.statusCode >= 200 && res.statusCode < 300);
                res.errorMessage = res.success ? '' : 'HTTP request failed with status: ' + res.statusCode;
            } catch (Exception e) {
                res.success = false;
                res.statusCode = 0;
                res.responseBody = '';
                res.errorMessage = e.getMessage();
            }
            results.add(res);
        }
        
        return results;
    }
    
    // Helper method to make the actual HTTP callout
    private static HttpResponse sendHTTPRequest(
        String method, 
        String endpoint, 
        String requestBody, 
        List<String> headerKeys, 
        List<String> headerValues
    ) {
        // Validate inputs
        if (String.isBlank(method)) {
            method = 'GET';
        }
        
        if (String.isBlank(endpoint)) {
            throw new CalloutException('Endpoint URL is required');
        }
        
        // Set up HTTP request
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod(method.toUpperCase());
        
        // Set timeout (default 120 seconds)
        req.setTimeout(120000);
        
        // Set body for POST, PUT, PATCH requests
        if ((method.equalsIgnoreCase('POST') || method.equalsIgnoreCase('PUT') || method.equalsIgnoreCase('PATCH')) 
            && !String.isBlank(requestBody)) {
            req.setBody(requestBody);
        }
        
        // Set headers from the parallel lists
        boolean hasContentType = false;
        if (headerKeys != null && headerValues != null && headerKeys.size() == headerValues.size()) {
            for (Integer i = 0; i < headerKeys.size(); i++) {
                if (headerKeys[i] != null && headerValues[i] != null) {
                    req.setHeader(headerKeys[i], headerValues[i]);
                    if (headerKeys[i].equalsIgnoreCase('Content-Type')) {
                        hasContentType = true;
                    }
                }
            }
        }
        
        // Add default content-type if not specified and we have a body
        if (!String.isBlank(requestBody) && !hasContentType) {
            req.setHeader('Content-Type', 'application/json');
        }
        
        // Send the request
        Http http = new Http();
        return http.send(req);
    }
    
    // Inner classes for request and response
    public class Request {
        @InvocableVariable(required=true label='Method' description='HTTP method (GET, POST, PUT, PATCH, DELETE)')
        public String method;
        
        @InvocableVariable(required=true label='Endpoint' description='Full endpoint URL')
        public String endpoint;
        
        @InvocableVariable(required=false label='Request Body' description='JSON body for POST, PUT, PATCH requests')
        public String requestBody;
        
        @InvocableVariable(required=false label='Header Keys' description='List of HTTP header names')
        public List<String> headerKeys;
        
        @InvocableVariable(required=false label='Header Values' description='List of HTTP header values (must match order of Header Keys)')
        public List<String> headerValues;
    }
    
    public class Result {
        @InvocableVariable(label='Success' description='Whether the request was successful (status 200-299)')
        public Boolean success;
        
        @InvocableVariable(label='Status Code' description='HTTP status code')
        public Integer statusCode;
        
        @InvocableVariable(label='Response Body' description='Response body as string')
        public String responseBody;
        
        @InvocableVariable(label='Error Message' description='Error message if the request failed')
        public String errorMessage;
    }
}