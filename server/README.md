# JWT Express Server

A Node.js Express server that generates and responds with a JWT token when accessed.

## Features

- Express server with JWT generation endpoint
- Health check endpoint
- EdDSA signature using libsodium
- Base64URL encoding for JWT components

## Installation

1. Install dependencies:
```bash
npm install
```

2. Configure your JWT settings in `server.js`:
   - Update `key_name` with your actual key ID
   - Update `key_secret` with your actual private key (base64 encoded)

## Usage

### Start the server:
```bash
npm start
```

Or for development with auto-restart:
```bash
npm run dev
```

### Access the JWT:
- **Main endpoint**: `GET http://localhost:3000/`
- **Health check**: `GET http://localhost:3000/health`

### Example Response:
```json
{
  "success": true,
  "jwt": "eyJ0eXAiOiJKV1QiLCJhbGciOiJFZERTQSIsImtpZCI6IktFWV9JRCIsIm5vbmNlIjoiMTIzNDU2Nzg5MGFiY2RlZiJ9.eyJpc3MiOiJjZHAiLCJuYmYiOjE2MzQ1Njc4OTAsImV4cCI6MTYzNDU2ODAxMCwic3ViIjoiS0VZX0lEIiwidXJpIjoiR0VUIGFwaS5jb2luYmFzZS5jb20gL2FwaS92My9icm9rZXJhZ2UvcHJvZHVjdHMifQ.signature_here",
  "message": "JWT generated successfully"
}
```

## Configuration

The JWT is configured for Coinbase API with the following settings:
- **Issuer**: `cdp`
- **Subject**: Your key ID
- **Algorithm**: EdDSA
- **Expiration**: 120 seconds from generation
- **URI**: `GET api.coinbase.com /api/v3/brokerage/products`

## Dependencies

- `express`: Web framework
- `libsodium-wrappers`: Cryptographic library for EdDSA signatures
- `base64url`: Base64URL encoding utility
- `crypto`: Node.js built-in crypto module

## Environment Variables

- `PORT`: Server port (default: 3000)

## Security Notes

- Update the `key_name` and `key_secret` variables with your actual credentials
- Consider using environment variables for sensitive data in production
- The JWT expires after 120 seconds for security
