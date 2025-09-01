const https = require('https');
const fs = require('fs');
const path = require('path');

// Configuration
const API_BASE_URL = 'https://api.developer.coinbase.com';
const API_KEY_PATH = '~/Downloads/cdp_api_key.json'; // Update this path to your API key location

class CoinbaseBuyQuote {
    constructor(apiKeyPath = API_KEY_PATH) {
        this.apiKeyPath = apiKeyPath;
        this.apiKey = this.loadApiKey();
    }

    loadApiKey() {
        try {
            const apiKeyData = JSON.parse(fs.readFileSync(this.apiKeyPath, 'utf8'));
            return apiKeyData.key || apiKeyData.api_key || apiKeyData;
        } catch (error) {
            console.error('Error loading API key:', error.message);
            console.log('Please ensure your API key file exists at:', this.apiKeyPath);
            process.exit(1);
        }
    }

    async getBuyQuote(quoteParams) {
        const {
            purchase_currency = 'BTC',
            payment_amount = '100.00',
            payment_currency = 'USD',
            payment_method = 'CARD',
            country = 'US',
            subdivision = 'NY',
            destination_address = null
        } = quoteParams;

        const requestData = {
            purchase_currency,
            payment_amount,
            payment_currency,
            payment_method,
            country,
            subdivision
        };

        // Add destination_address if provided
        if (destination_address) {
            requestData.destination_address = destination_address;
        }

        return new Promise((resolve, reject) => {
            const postData = JSON.stringify(requestData);
            
            const options = {
                hostname: 'api.developer.coinbase.com',
                port: 443,
                path: '/onramp/v1/buy/quote',
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Content-Length': Buffer.byteLength(postData),
                    'Authorization': `Bearer ${this.apiKey}`
                }
            };

            const req = https.request(options, (res) => {
                let data = '';

                res.on('data', (chunk) => {
                    data += chunk;
                });

                res.on('end', () => {
                    try {
                        const response = JSON.parse(data);
                        
                        if (res.statusCode === 200) {
                            resolve(response);
                        } else {
                            reject(new Error(`API Error: ${res.statusCode} - ${response.message || data}`));
                        }
                    } catch (error) {
                        reject(new Error(`Failed to parse response: ${error.message}`));
                    }
                });
            });

            req.on('error', (error) => {
                reject(new Error(`Request failed: ${error.message}`));
            });

            req.write(postData);
            req.end();
        });
    }

    generateOneClickBuyUrl(quoteResponse) {
        if (!quoteResponse || !quoteResponse.data || !quoteResponse.data.quote_id) {
            throw new Error('Invalid quote response - missing quote_id');
        }

        const quoteId = quoteResponse.data.quote_id;
        return `https://pay.coinbase.com/buy/select-asset?appId=YOUR_APP_ID&quoteId=${quoteId}`;
    }

    async createBuyUrl(params = {}) {
        try {
            console.log('Getting buy quote...');
            const quoteResponse = await this.getBuyQuote(params);
            
            console.log('Quote received successfully!');
            console.log('Quote ID:', quoteResponse.data.quote_id);
            console.log('Quote expires at:', quoteResponse.data.expires_at);
            
            const buyUrl = this.generateOneClickBuyUrl(quoteResponse);
            console.log('\nOne-click buy URL:');
            console.log(buyUrl);
            
            return {
                quote: quoteResponse,
                buyUrl: buyUrl
            };
        } catch (error) {
            console.error('Error creating buy URL:', error.message);
            throw error;
        }
    }
}

// Example usage
async function main() {
    const coinbaseBuy = new CoinbaseBuyQuote();
    
    // Example parameters - customize these as needed
    const params = {
        purchase_currency: 'BTC',
        payment_amount: '100.00',
        payment_currency: 'USD',
        payment_method: 'CARD',
        country: 'US',
        subdivision: 'NY',
        destination_address: '0x71C7656EC7ab88b098defB751B7401B5f6d8976F' // Optional
    };

    try {
        const result = await coinbaseBuy.createBuyUrl(params);
        
        // You can also save the URL to a file or use it programmatically
        console.log('\n=== Complete Result ===');
        console.log(JSON.stringify(result, null, 2));
        
    } catch (error) {
        console.error('Failed to create buy URL:', error.message);
    }
}

// Export for use in other modules
module.exports = CoinbaseBuyQuote;

// Run if this file is executed directly
if (require.main === module) {
    main();
}
