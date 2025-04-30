import { LightningElement, track } from 'lwc';
import sendPrompt from '@salesforce/apex/AgentforceApiClient.sendPrompt';
import endCurrentSession from '@salesforce/apex/AgentforceApiClient.endCurrentSession';

export default class AgentforceChat extends LightningElement {
    @track messages = [];
    @track currentInput = '';
    @track isLoading = false;
    @track isError = false;
    @track errorMessage = '';
    @track sessionId = null;
    @track lastMessageId = null;
    @track chatStarted = false;
    @track hasText = false;
    @track currentAgentId = null;

    startRentChargerChat() {
        this.chatStarted = true;
        this.currentAgentId = '0XxNS000000mbLR0AY'; 
        setTimeout(() => {
            this.currentInput = "Share My Charger";
            this.sendMessage();
        }, 300);
    }

    startFindChargerChat() {
        this.chatStarted = true;
        this.currentAgentId = '0XxNS000000mZxx0AE'; 
        setTimeout(() => {
            this.currentInput = "Find a Charger";
            this.sendMessage();
        }, 300);
    }

    handleTextareaChange(event) {
        const textarea = event.target;
        this.currentInput = textarea.value;
        this.hasText = !!textarea.value.trim();
        
        textarea.style.height = 'auto';
        const newHeight = Math.min(textarea.scrollHeight, 80); 
        textarea.style.height = `${newHeight}px`;
    }

    async sendMessage() {
        if (!this.currentInput.trim()) return;
    
        const userMessage = this.currentInput;
        this.currentInput = '';
        this.hasText = false;
        this.isLoading = true;
        this.isError = false;
    
        // Reset textarea height
        const textarea = this.template.querySelector('.instagram-textarea');
        if (textarea) {
            textarea.value = '';
            textarea.style.height = 'auto';
        }
    
        // Add user message with no special formatting
        this.messages.push({
            id: Date.now().toString(),
            sender: 'user',
            text: userMessage,
            timestamp: new Date().toLocaleTimeString()
        });
    
        try {
            const response = await sendPrompt({
                inputText: userMessage,
                sessionId: this.sessionId,
                agentId: this.currentAgentId
            });
    
            this.sessionId = response.sessionId;
            this.lastMessageId = response.messageId;
            if (response.agentId) {
                this.currentAgentId = response.agentId;
            }
    
            // Format ONLY the agent response to add line breaks after sentence-ending punctuation
          //  const formattedText = response.messageText ? 
           //     response.messageText
                    // Replace sentence-ending punctuation (periods, question marks, exclamation points)
                    // followed by whitespace with the punctuation + newline
            //        .replace(/([.?!])\s+(?=[A-Z])/g, '$1\n') 
           //         .replace(/([.?!])\s*$/gm, '$1\n') : 
            //    'No response received.';
               
            let formattedText = response.messageText || 'No response received.';
        
            if (formattedText !== 'No response received.') {
                formattedText = formattedText.replace(/([.?!])\s+(?=[A-Z])/g, '\n');
                formattedText = formattedText.replace(/:\n(?=\d+\.)/g, ':');
                formattedText = formattedText.replace(/:\n/g, ':');
            }
            
            this.messages.push({
                id: response.messageId || Date.now().toString(),
                sender: 'agent',
                text: formattedText,
                timestamp: new Date().toLocaleTimeString(),
                rawResponse: response.rawResponse
            });
        } catch (error) {
            this.isError = true;
            this.errorMessage = error.message || 'Unknown error occurred';
    
            this.messages.push({
                id: Date.now().toString(),
                sender: 'system',
                text: `Error: ${this.errorMessage}`,
                timestamp: new Date().toLocaleTimeString(),
                isError: true
            });
        } finally {
            this.isLoading = false;
        }
    }

    async endSession() {
        if (!this.sessionId) return;

        this.isLoading = true;
        try {
            const result = await endCurrentSession({
                currentSessionId: this.sessionId
            });

            if (result) {
                this.messages.push({
                    id: Date.now().toString(),
                    sender: 'system',
                    text: 'Session ended successfully.',
                    timestamp: new Date().toLocaleTimeString()
                });

                this.sessionId = null;
                this.lastMessageId = null;
                this.currentAgentId = null;
            } else {
                throw new Error('Failed to end session.');
            }
        } catch (error) {
            this.isError = true;
            this.errorMessage = error.message || 'Unknown error ending session';
        } finally {
            this.isLoading = false;
        }
    }

    handleKeyPress(event) {
        if (event.key === 'Enter' && !event.shiftKey) {
            event.preventDefault();
            this.sendMessage();
        }
    }

    newConversation() {
        if (this.sessionId) {
            endCurrentSession({ currentSessionId: this.sessionId })
                .catch(error => console.error('Error ending session:', error));
        }

        this.messages = [];
        this.sessionId = null;
        this.lastMessageId = null;
        this.currentAgentId = null;
        this.isError = false;
        this.errorMessage = '';
        this.chatStarted = false;
        this.hasText = false;
    }
}