const url = 'https://api.developer.coinbase.com/onramp/v1/token';
const options = {
  method: 'POST',
  headers: {Authorization: 'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJFZERTQSIsImtpZCI6ImMxZmFmOTMwLWQzMzgtNGNjNi1iNDE2LWEyMzliOGE1ZDBkNSIsIm5vbmNlIjoiYmU5MDFhZWJkYTIwMTlmZGZjOTZkM2RhYTk5ODExOTkifQ.eyJpc3MiOiJjZHAiLCJuYmYiOjE3NTUzOTk3MzksImV4cCI6MTc1NTM5OTg1OSwic3ViIjoiYzFmYWY5MzAtZDMzOC00Y2M2LWI0MTYtYTIzOWI4YTVkMGQ1IiwidXJpIjoiUE9TVCBodHRwczovL2FwaS5kZXZlbG9wZXIuY29pbmJhc2UuY29tL29ucmFtcC92MS90b2tlbiJ9.zksteCZx1sDskAAI9PkMSdGchDgvbC1IULzSXSCFe7Kze2zOtS7zbZnM4DkoJAoQnL-iNBHrb0FbBGQwMYc1Ag', 'Content-Type': 'application/json'},
  body: '{"addresses":[{"address":"0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6","blockchains":["ethereum"]}],"assets":["USDC"],"destinationWallets":[{"address":"0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6","assets":["USDC"],"blockchains":["ethereum"],"supportedNetworks":["ethereum"]}]}'
};

try {
  const response = await fetch(url, options);
  console.log('Response status:', response.status);
  console.log('Response headers:', Object.fromEntries(response.headers.entries()));
  
  const text = await response.text();
  let data;
  
  if (response.ok) {
    try {
      data = text ? JSON.parse(text) : {};
    } catch (e) {
      data = { raw: text };
    }
    console.log('Success! Response data:', data);
  } else {
    console.error('Error response:', response.status, text);
  }
} catch (error) {
  console.error('Network error:', error);
}