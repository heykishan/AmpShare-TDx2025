public class AgentforceApiClient {
    // API Configuration
    Org_Details__c orgDetails = [SELECT Domain_URL__c, Client_Id__c, Client_Secret_Id__c, SalesforceEndpoints__c FROM Org_Details__c LIMIT 1];
    
    String SF_API_HOST = orgDetails.SalesforceEndpoints__c;
    String Domain_host = orgDetails.Domain_URL__c;
    
    String RENT_CHARGER_AGENT_ID = system.label.Rent_Charger_Agent_ID;
    String FIND_CHARGER_AGENT_ID = system.label.Share_my_charger;
    
    String CLIENT_ID = orgDetails.Client_Id__c;
	String CLIENT_SECRET = orgDetails.Client_Secret_Id__c;
    
    //private static final String SF_API_HOST = 'https://api.salesforce.com';
    // private static final String Domain_host = 'https://ampshare-ryewalk.my.salesforce.com';
     
    // private static final String RENT_CHARGER_AGENT_ID = '0XxNS000000mbLR0AY'; 
    //private static final String FIND_CHARGER_AGENT_ID = '0XxNS000000mZxx0AE '; 
       
    // private static final String CLIENT_ID = '3MVG9VMBZCsTL9hkPPx8Gnt3UeOBoUG6Sp7s2gAM5qefFa4TV0PB40IpCHlA4elVd5TWD6ys.2X0jM_O67_g5';
    //private static final String CLIENT_SECRET = '37288783CAE16F3C498E86057505B33C6BB4111F6048F7D7B4878D2DD90F6E22';
       
    private String accessToken;
    private String sessionId;
    private String currentAgentId;
   
    public class AgentResponse {
        @AuraEnabled public String messageText { get; set; }
        @AuraEnabled public String sessionId { get; set; }
        @AuraEnabled public String messageId { get; set; }
        @AuraEnabled public String rawResponse { get; set; }
        @AuraEnabled public String agentId { get; set; }
    }
    

    @AuraEnabled(cacheable=false)
    public static AgentResponse sendPrompt(String inputText, String sessionId, String agentId) {
        AgentforceApiClient client = new AgentforceApiClient();
        
        if (String.isNotBlank(sessionId)) {
            client.sessionId = sessionId;
        }
        
        client.determineAgent(inputText, agentId);
        
        return client.processPrompt(inputText);
    }
    
    private void determineAgent(String inputText, String agentId) {
        if (String.isNotBlank(agentId)) {
            currentAgentId = agentId;
            return;
        }
        
        if (String.isBlank(sessionId)) {
            String lowercaseInput = inputText.toLowerCase();
            
            if (lowercaseInput.contains('share') || lowercaseInput.equals('Share My Charger')) {
                currentAgentId = RENT_CHARGER_AGENT_ID;
            } else if (lowercaseInput.contains('find') || lowercaseInput.equals('find a charger')) {
                currentAgentId = FIND_CHARGER_AGENT_ID;
            } else {
                currentAgentId = RENT_CHARGER_AGENT_ID;
            }
        }
    }
    
    private AgentResponse processPrompt(String inputText) {
        Http http = new Http();
        AgentResponse response = new AgentResponse();
        
        try {
            accessToken = getOAuthToken(http);
            System.debug('OAuth token obtained successfully');
            
            if (String.isBlank(sessionId)) {
                Map<String, Object> sessionResponse = startSession(http);
                sessionId = (String)sessionResponse.get('sessionId');
                
                String welcomeMessage = extractFirstMessage(sessionResponse);
                System.debug('Session started: ' + sessionId + ', Welcome: ' + welcomeMessage);
            }
            
            Map<String, Object> messageResponse = sendSynchronousMessage(http, inputText);

            response.messageText = extractFirstMessage(messageResponse);
            response.sessionId = sessionId;
            response.messageId = extractLastMessageId(messageResponse);
            response.rawResponse = JSON.serialize(messageResponse);
            response.agentId = currentAgentId;
            
            return response;
        } catch(Exception e) {
            System.debug('Error in processing prompt: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            
            response.messageText = 'Error: ' + e.getMessage();
            response.rawResponse = e.getStackTraceString();
            
            return response;
        }
    }
    
    @AuraEnabled(cacheable=false)
    public static Boolean endCurrentSession(String currentSessionId) {
        if (String.isBlank(currentSessionId)) {
            return false;
        }
        
        try {
            AgentforceApiClient client = new AgentforceApiClient();
            client.sessionId = currentSessionId;
            client.accessToken = client.getOAuthToken(new Http());
            client.endSession(new Http());
            return true;
        } catch(Exception e) {
            System.debug('Error ending session: ' + e.getMessage());
            return false;
        }
    }
    
    // Method to get the current Agent ID associated with a session
    @AuraEnabled(cacheable=false)
    public static String getCurrentAgentId(String sessionId) {
        return null;
    }
    
    // 1. OAuth Authentication
    private String getOAuthToken(Http http) {
        HttpRequest tokenReq = new HttpRequest();
        tokenReq.setEndpoint(Domain_host + '/services/oauth2/token');
        tokenReq.setMethod('POST');
        tokenReq.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        // Build OAuth request body
        String requestBody = 'grant_type=client_credentials' +
                           '&client_id=' +  EncodingUtil.urlEncode(CLIENT_ID, 'UTF-8') +
                           '&client_secret=' + EncodingUtil.urlEncode(CLIENT_SECRET, 'UTF-8');
        tokenReq.setBody(requestBody);
        
        HttpResponse tokenRes = http.send(tokenReq);
        if (tokenRes.getStatusCode() != 200) {
            throw new AgentApiException('OAuth authentication failed: ' + tokenRes.getStatusCode() + ' ' + tokenRes.getBody());
        }
        
        Map<String, Object> tokenData = (Map<String, Object>)JSON.deserializeUntyped(tokenRes.getBody());
        return (String)tokenData.get('access_token');
    }
    
    // 2. Start Session
    private Map<String, Object> startSession(Http http) {
        HttpRequest startReq = new HttpRequest();
        startReq.setEndpoint(SF_API_HOST + '/einstein/ai-agent/v1/agents/' + currentAgentId + '/sessions');
        startReq.setMethod('POST');
        startReq.setHeader('Content-Type', 'application/json');
        startReq.setHeader('Authorization', 'Bearer ' + accessToken);
        
        String orgDomain = URL.getOrgDomainUrl().toExternalForm();
        
        // Prepare session request body
        Map<String, Object> requestBody = new Map<String, Object>{
            'externalSessionKey' => generateGuid(),
            'instanceConfig' => new Map<String, String>{
                'endpoint' => orgDomain
            },
            'tz' => UserInfo.getTimeZone().getID(),
            'variables' => new List<Map<String, Object>>{
                new Map<String, Object>{
                    'name' => '$Context.EndUserLanguage',
                    'type' => 'Text',
                    'value' => UserInfo.getLanguage()
                }
            },
            'bypassUser' => true
        };
        startReq.setBody(JSON.serialize(requestBody));
        
        HttpResponse startRes = http.send(startReq);
        if (startRes.getStatusCode() != 200) {
            throw new AgentApiException('Failed to start session: ' + startRes.getStatusCode() + ' ' + startRes.getBody());
        }
        
        return (Map<String, Object>)JSON.deserializeUntyped(startRes.getBody());
    }
    
    // 3. Send Synchronous Message
    private Map<String, Object> sendSynchronousMessage(Http http, String inputText) {
        HttpRequest msgReq = new HttpRequest();
        msgReq.setEndpoint(SF_API_HOST + '/einstein/ai-agent/v1/sessions/' + sessionId + '/messages');
        msgReq.setMethod('POST');
        msgReq.setHeader('Content-Type', 'application/json');
        msgReq.setHeader('Accept', 'application/json');
        msgReq.setHeader('Authorization', 'Bearer ' + accessToken);
        
        Map<String, Object> payload = new Map<String, Object>{
            'message' => new Map<String, Object>{
                'sequenceId' => System.now().getTime(),
                'type' => 'Text',
                'text' => inputText
            },
            'variables' => new List<Object>()
        };
        
        msgReq.setBody(JSON.serialize(payload));
        HttpResponse msgRes = http.send(msgReq);
        
        if (msgRes.getStatusCode() != 200) {
            throw new AgentApiException('Agent response failed: ' + msgRes.getStatusCode() + ' ' + msgRes.getBody());
        }
        
        return (Map<String, Object>)JSON.deserializeUntyped(msgRes.getBody());
    }
    
    // 4. End Session
    private void endSession(Http http) {
        if (String.isBlank(sessionId)) {
            return;
        }
        
        HttpRequest endReq = new HttpRequest();
        endReq.setEndpoint(SF_API_HOST + '/einstein/ai-agent/v1/sessions/' + sessionId);
        endReq.setMethod('DELETE');
        endReq.setHeader('Authorization', 'Bearer ' + accessToken);
        endReq.setHeader('x-session-end-reason', 'UserRequest');
        
        try {
            HttpResponse endRes = http.send(endReq);
            // Log result but don't throw exception on failure
            if (endRes.getStatusCode() != 200) {
                System.debug('Warning: Session end returned status ' + endRes.getStatusCode());
            }
        } catch(Exception e) {
            System.debug('Warning: Error ending session: ' + e.getMessage());
        }
    }
        
    // Helper methods
    private String extractFirstMessage(Map<String, Object> response) {
        try {
            List<Object> messages = (List<Object>)response.get('messages');
            if (messages != null && !messages.isEmpty()) {
                Map<String, Object> messageObj = (Map<String, Object>)messages[0];
                if (messageObj.containsKey('message')) {
                    return (String)messageObj.get('message');
                }
            }
        } catch (Exception e) {
            System.debug('Error extracting message: ' + e.getMessage());
        }
        return '';
    }
    
    private String extractLastMessageId(Map<String, Object> response) {
        try {
            List<Object> messages = (List<Object>)response.get('messages');
            if (messages != null && !messages.isEmpty()) {
                Map<String, Object> messageObj = (Map<String, Object>)messages[messages.size() - 1];
                if (messageObj.containsKey('id')) {
                    return (String)messageObj.get('id');
                }
                if (messageObj.containsKey('feedbackId')) {
                    return (String)messageObj.get('feedbackId');
                }
            }
        } catch (Exception e) {
            System.debug('Error extracting message ID: ' + e.getMessage());
        }
        return '';
    }
    
    private static String generateGuid() {
        String hex = EncodingUtil.convertToHex(Crypto.generateAesKey(128));
        return hex.substring(0,8) + '-' + hex.substring(8,12) + '-' + 
               hex.substring(12,16) + '-' + hex.substring(16,20) + '-' + hex.substring(20);
    }
    
    public class AgentApiException extends Exception {}
}