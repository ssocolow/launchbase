const express = require('express');
const _sodium = require('libsodium-wrappers');
const base64url = require("base64url");
const crypto = require('crypto');

// Prefer native fetch (Node 18+), fallback to node-fetch
const fetchFn = globalThis.fetch || ((...args) => import('node-fetch').then(({ default: fetch }) => fetch(...args)));

const app = express();
const PORT = process.env.PORT || 3007;

// Basic CORS setup for local dev
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', 'http://localhost:3000');
    res.header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
    if (req.method === 'OPTIONS') {
        return res.sendStatus(204);
    }
    next();
});

app.use(express.json());

// JWT configuration
const key_name = "c1faf930-d338-4cc6-b416-a239b8a5d0d5"
const key_secret = "P3IoPSPX8nOU8bxUqHSXOqo0Yw6Rn3X2zUVNDLA9sRUzpfrkIonMu+h+Efo5wPJGO8tgJvNmvA3esAJyaEGpmg=="
const request_method = 'POST';
const url = "https://api.developer.coinbase.com"
const request_path   = "/onramp/v1/token"
// The JWT 'uri' claim should include the full URL
const uri = `${request_method} ${url}${request_path}`;

// JWT generation function
const getJWT = async () => {  
    await _sodium.ready;
    const sodium = _sodium;
    const privateKey = key_secret;
    const payload = {
        iss: 'cdp',
        nbf: Math.floor(Date.now() / 1000),
        exp: Math.floor(Date.now() / 1000) + 120,
        sub: key_name,
        uri,
     };  
     
     console.log('JWT Payload:', JSON.stringify(payload, null, 2));
     console.log('JWT URI:', uri);
     
     const {headerAndPayloadBase64URL, keyBuf} = encode(payload, privateKey, "EdDSA");
     const signature = sodium.crypto_sign_detached(headerAndPayloadBase64URL, keyBuf); 
     const signatureBase64url = base64url(Buffer.from(signature));
     const jwt = `${headerAndPayloadBase64URL}.${signatureBase64url}`;
     
     console.log('Generated JWT:', jwt);
     return jwt;
};
const encode = (payload, key, alg) => {
    const header = {
        typ: "JWT",
        alg,
        kid: key_name,
        nonce: crypto.randomBytes(16).toString('hex'),
    };
    const headerBase64URL = base64url(JSON.stringify(header));
    const payloadBase64URL = base64url(JSON.stringify(payload));
    const headerAndPayloadBase64URL = `${headerBase64URL}.${payloadBase64URL}`;
    const keyBuf = Buffer.from(key, "base64");
    return {headerAndPayloadBase64URL, keyBuf};
};


// Routes
app.get('/', async (req, res) => {
    try {
        const jwt = await getJWT();
        res.json({
            success: true,
            jwt: jwt,
            message: 'JWT generated successfully'
        });
    } catch (error) {
        console.error('Error generating JWT:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to generate JWT',
            message: error.message
        });
    }
});

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'OK',
        timestamp: new Date().toISOString(),
        uptime: process.uptime()
    });
});

// coinbase hooks
app.post('/hook', (req, res) => {
    console.log(req);
})

// Quote endpoint that executes the cdpcurl command
app.post('/quote', async (req, res) => {
    try {
        const {
            destination_address,
            payment_amount,
            payment_currency,
            payment_method,
            country,
            purchase_currency,
        } = req.body || {};
        // Build request payload from inputs with sensible defaults
        const formatAmount = (value) => {
            const num = typeof value === 'string' ? parseFloat(value) : value;
            if (!Number.isFinite(num) || num <= 0) return undefined;
            return num.toFixed(2);
        };

        const payload = {
            purchase_currency: purchase_currency || 'USDC',
            payment_amount: formatAmount(payment_amount) || '5.00',
            payment_currency: payment_currency || 'USD',
            payment_method: payment_method || 'CARD',
            country: country || 'US',
            destination_address: destination_address,
        };

        console.log('Quote request payload:', payload);

        const payloadStr = JSON.stringify(payload);

        if (!destination_address) {
            return res.status(400).json({
                success: false,
                error: 'destination_address is required'
            });
        }
        
        // Build the cdpcurl command
        const curlCommand = `cdpcurl -X POST 'https://api.developer.coinbase.com/onramp/v1/buy/quote' \
  -k ~/Downloads/cdp_api_key.json \
  -d '${payloadStr}'`;
        console.log('Executing curl command:', curlCommand);
// -H 'Authorization: Bearer ${jwt}' \
        // Execute the curl command
        const { exec } = require('child_process');
        
        exec(curlCommand, (error, stdout, stderr) => {
            if (error) {
                console.error('Curl command error:', error);
                return res.status(500).json({
                    success: false,
                    error: 'Failed to execute curl command',
                    message: error.message,
                    stderr: stderr
                });
            }

            if (stderr) {
                console.warn('Curl stderr:', stderr);
            }

            console.log('Curl output:', stdout);

            let result;
            try {
                // Extract JSON from curl output (remove HTTP status line if present)
                let jsonString = stdout.trim();
                if (jsonString.includes('{')) {
                    // Find the first '{' and parse from there
                    const jsonStart = jsonString.indexOf('{');
                    jsonString = jsonString.substring(jsonStart);
                }
                result = JSON.parse(jsonString);
            } catch (parseError) {
                console.error('Failed to parse curl response:', parseError);
                return res.status(500).json({
                    success: false,
                    error: 'Failed to parse curl response',
                    raw_output: stdout
                });
            }

            res.json({
                success: true,
                result: result
            });
        });

    } catch (error) {
        console.error('Error in quote endpoint:', error);
        res.status(500).json({
            success: false,
            error: 'Failed to get quote',
            message: error.message
        });
    }
});

// Token balances via CDP Platform API (uses cdpcurl with your API key)
// GET /balances?chain=base-sepolia&address=0x...
app.get('/balances', async (req, res) => {
    try {
        const chain = (req.query.chain || 'base-sepolia').toString();
        const address = (req.query.address || '').toString();
        if (!address) {
            return res.status(400).json({ success: false, error: 'address is required' });
        }

        const path = `https://api.cdp.coinbase.com/platform/v2/data/evm/token-balances/${encodeURIComponent(chain)}/${address}`;
        const keyPath = process.env.CDP_KEY_PATH || `${process.env.HOME}/Downloads/cdp_api_key.json`;

        const curlCommand = `cdpcurl -k ${keyPath} "${path}"`;
        console.log('Executing balances command:', curlCommand);

        const { exec } = require('child_process');
        exec(curlCommand, (error, stdout, stderr) => {
            if (error) {
                console.error('Balances command error:', error);
                return res.status(500).json({ success: false, error: 'Failed to execute balances command', message: error.message, stderr });
            }
            if (stderr) {
                console.warn('Balances stderr:', stderr);
            }
            console.log('Balances output:', stdout);

            try {
                let jsonString = stdout.trim();
                if (jsonString.includes('{')) {
                    const jsonStart = jsonString.indexOf('{');
                    jsonString = jsonString.substring(jsonStart);
                }
                const result = JSON.parse(jsonString);
                return res.json({ success: true, result });
            } catch (parseError) {
                console.error('Failed to parse balances response:', parseError);
                return res.status(500).json({ success: false, error: 'Failed to parse balances response', raw_output: stdout });
            }
        });
    } catch (error) {
        console.error('Error in balances endpoint:', error);
        res.status(500).json({ success: false, error: 'Failed to get balances', message: error.message });
    }
});

// -------------------------------------------------------------
// Smart contract interaction endpoints (Foundry cast wrappers)
// -------------------------------------------------------------
// Requirements:
// - Foundry installed and `cast` available in PATH
// - `BASE_SEPOLIA_RPC_URL` and `PRIVATE_KEY` exported in the environment
// - Optionally addresses in env: USDC_ADDRESS, WETH_ADDRESS, USDC_PRICE_FEED, WETH_PRICE_FEED, FACTORY

const { exec } = require('child_process');

const runShellCommand = (command) => {
    return new Promise((resolve, reject) => {
        exec(command, (error, stdout, stderr) => {
            if (error) {
                return reject({ error, stdout, stderr });
            }
            resolve({ stdout, stderr });
        });
    });
};

const isAddress = (value) => /^0x[a-fA-F0-9]{40}$/.test((value || '').toString());

// Redact sensitive args like private keys from logged commands
const redactSensitive = (command) => {
    try {
        return command
            .replace(/--private-key\s+\S+/g, '--private-key [REDACTED]')
            .replace(/-k\s+\S*cdp_api_key\.json/g, '-k [REDACTED]');
    } catch {
        return command;
    }
};

const parseDecimalToUnits = (amount, decimals = 6) => {
    if (amount === undefined || amount === null) return undefined;
    const dec = Number(decimals);
    if (!Number.isInteger(dec) || dec < 0 || dec > 36) return undefined;
    if (typeof amount === 'number') {
        if (!Number.isFinite(amount)) return undefined;
        const scaled = Math.floor(amount * Math.pow(10, dec));
        return String(scaled);
    }
    if (typeof amount === 'string') {
        const trimmed = amount.trim();
        if (!trimmed) return undefined;
        if (/^\d+$/.test(trimmed)) return trimmed; // already in units
        const num = Number(trimmed);
        if (!Number.isFinite(num)) return undefined;
        const scaled = Math.floor(num * Math.pow(10, dec));
        return String(scaled);
    }
    return undefined;
};

// GET /portfolio/by-user/:userAddress -> user portfolio contract address from factory
app.get('/portfolio/by-user/:userAddress', async (req, res) => {
    try {
        console.log('[api][by-user] request', { userAddress: req.params?.userAddress, factory: req.query?.factory, rpcUrl: req.query?.rpcUrl });
        const rpcUrl = (req.query?.rpcUrl || process.env.BASE_SEPOLIA_RPC_URL || '').toString();
        const factoryAddress = ((req.query?.factory || process.env.FACTORY || process.env.FACTORY_CONTRACT || '')).toString();
        const userAddress = req.params.userAddress;

        if (!rpcUrl) {
            console.warn('[api][by-user] missing env BASE_SEPOLIA_RPC_URL');
            return res.status(400).json({ success: false, error: 'BASE_SEPOLIA_RPC_URL env var is required' });
        }
        if (!isAddress(factoryAddress)) {
            console.warn('[api][by-user] missing/invalid env FACTORY/FACTORY_CONTRACT');
            return res.status(400).json({ success: false, error: 'FACTORY address env var is required' });
        }
        if (!isAddress(userAddress)) {
            console.warn('[api][by-user] invalid userAddress');
            return res.status(400).json({ success: false, error: 'Invalid user address' });
        }

        const cmd = `cast call ${factoryAddress} "getUserPortfolio(address)(address)" ${userAddress} --rpc-url ${rpcUrl} | cat`;
        const startedAt = Date.now();
        console.log('[cast][by-user] executing', { cmd: redactSensitive(cmd), params: { factoryAddress, userAddress, rpcUrl } });
        const { stdout, stderr } = await runShellCommand(cmd);
        const durationMs = Date.now() - startedAt;
        if (stderr) console.warn('getUserPortfolio stderr:', stderr);
        const portfolioAddress = stdout.trim();
        console.log('[cast][by-user] completed', { durationMs, portfolioAddress });
        return res.json({ success: true, result: { portfolioAddress } });
    } catch (err) {
        console.error('Error in /portfolio/by-user:', { message: err?.message, stderr: err?.stderr });
        return res.status(500).json({ success: false, error: 'Failed to fetch user portfolio', details: err.stderr || err.message });
    }
});

// POST /portfolio/approve
// body: { userContract: string, usdcAddress?: string, rpcUrl?: string }
app.post('/portfolio/approve', async (req, res) => {
    try {
        console.log('[api][approve] request', { body: { userContract: req.body?.userContract, usdcAddress: req.body?.usdcAddress } });
        const rpcUrl = (req.body?.rpcUrl || process.env.BASE_SEPOLIA_RPC_URL || '').toString();
        const privateKey = (process.env.PRIVATE_KEY || '').toString();
        const userContract = (req.body?.userContract || '').toString();
        const usdcAddress = (req.body?.usdcAddress || process.env.USDC_ADDRESS || '').toString();

        if (!rpcUrl) {
            console.warn('[api][approve] missing rpcUrl');
            return res.status(400).json({ success: false, error: 'rpcUrl (or BASE_SEPOLIA_RPC_URL env) is required' });
        }
        if (!privateKey) {
            console.warn('[api][approve] missing PRIVATE_KEY');
            return res.status(400).json({ success: false, error: 'PRIVATE_KEY env var is required' });
        }
        if (!isAddress(userContract)) {
            console.warn('[api][approve] invalid userContract');
            return res.status(400).json({ success: false, error: 'Invalid userContract address' });
        }
        if (!isAddress(usdcAddress)) {
            console.warn('[api][approve] invalid usdcAddress');
            return res.status(400).json({ success: false, error: 'Invalid usdcAddress' });
        }

        const maxUint256 = '0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
        const cmd = `cast send ${usdcAddress} "approve(address,uint256)" ${userContract} ${maxUint256} --rpc-url ${rpcUrl} --private-key ${privateKey} | cat`;
        const startedAt = Date.now();
        console.log('[cast][approve] executing', { cmd: redactSensitive(cmd), params: { userContract, usdcAddress, rpcUrl } });
        const { stdout, stderr } = await runShellCommand(cmd);
        const durationMs = Date.now() - startedAt;
        if (stderr) console.warn('approve stderr:', stderr);
        console.log('[cast][approve] completed', { durationMs, txOutput: stdout.trim() });
        return res.json({ success: true, result: { output: stdout } });
    } catch (err) {
        console.error('Error in /portfolio/approve:', { message: err?.message, stderr: err?.stderr });
        return res.status(500).json({ success: false, error: 'Approval failed', details: err.stderr || err.message });
    }
});

// POST /portfolio/deposit
// body: { userContract: string, amount: string|number, decimals?: number (default 6), rpcUrl?: string }
app.post('/portfolio/deposit', async (req, res) => {
    try {
        console.log('[api][deposit] request', { body: { userContract: req.body?.userContract, amount: req.body?.amount, decimals: req.body?.decimals } });
        const rpcUrl = (req.body?.rpcUrl || process.env.BASE_SEPOLIA_RPC_URL || '').toString();
        const privateKey = (process.env.PRIVATE_KEY || '').toString();
        const userContract = (req.body?.userContract || '').toString();
        const decimals = req.body?.decimals ?? 6;
        const amountParam = req.body?.amount;

        if (!rpcUrl) {
            console.warn('[api][deposit] missing rpcUrl');
            return res.status(400).json({ success: false, error: 'rpcUrl (or BASE_SEPOLIA_RPC_URL env) is required' });
        }
        if (!privateKey) {
            console.warn('[api][deposit] missing PRIVATE_KEY');
            return res.status(400).json({ success: false, error: 'PRIVATE_KEY env var is required' });
        }
        if (!isAddress(userContract)) {
            console.warn('[api][deposit] invalid userContract');
            return res.status(400).json({ success: false, error: 'Invalid userContract address' });
        }
        const amountUnits = parseDecimalToUnits(amountParam, decimals);
        if (!amountUnits) return res.status(400).json({ success: false, error: 'Invalid amount' });

        const cmd = `cast send ${userContract} "depositUsdc(uint256)" ${amountUnits} --rpc-url ${rpcUrl} --private-key ${privateKey} | cat`;
        const startedAt = Date.now();
        console.log('[cast][deposit] executing', { cmd: redactSensitive(cmd), params: { userContract, amount: amountParam, decimals, rpcUrl } });
        const { stdout, stderr } = await runShellCommand(cmd);
        const durationMs = Date.now() - startedAt;
        if (stderr) console.warn('deposit stderr:', stderr);
        console.log('[cast][deposit] completed', { durationMs, txOutput: stdout.trim() });
        return res.json({ success: true, result: { output: stdout } });
    } catch (err) {
        console.error('Error in /portfolio/deposit:', { message: err?.message, stderr: err?.stderr });
        return res.status(500).json({ success: false, error: 'Deposit failed', details: err.stderr || err.message });
    }
});

// POST /portfolio/allocate
// body: {
//   userContract: string,
//   tokens?: string[],               // default [USDC, WETH]
//   bps?: number[],                  // allocations, sum to 10000
//   decimals?: number[],             // default [6, 18]
//   priceFeeds?: string[],           // default [USDC_PRICE_FEED, WETH_PRICE_FEED]
//   rpcUrl?: string
// }
app.post('/portfolio/allocate', async (req, res) => {
    try {
        console.log('[api][allocate] request', { body: { userContract: req.body?.userContract, bps: req.body?.bps, tokens: req.body?.tokens, decimals: req.body?.decimals, priceFeeds: req.body?.priceFeeds } });
        const rpcUrl = (req.body?.rpcUrl || process.env.BASE_SEPOLIA_RPC_URL || '').toString();
        const privateKey = (process.env.PRIVATE_KEY || '').toString();
        const userContract = (req.body?.userContract || '').toString();

        const defaultTokens = [process.env.USDC_ADDRESS, process.env.WETH_ADDRESS].filter(Boolean);
        const defaultFeeds = [process.env.USDC_PRICE_FEED, process.env.WETH_PRICE_FEED].filter(Boolean);

        const tokens = Array.isArray(req.body?.tokens) ? req.body.tokens : defaultTokens;
        const bps = Array.isArray(req.body?.bps) ? req.body.bps : [6000, 4000];
        const decimals = Array.isArray(req.body?.decimals) ? req.body.decimals : [6, 18];
        const priceFeeds = Array.isArray(req.body?.priceFeeds) ? req.body.priceFeeds : defaultFeeds;

        if (!rpcUrl) {
            console.warn('[api][allocate] missing rpcUrl');
            return res.status(400).json({ success: false, error: 'rpcUrl (or BASE_SEPOLIA_RPC_URL env) is required' });
        }
        if (!privateKey) {
            console.warn('[api][allocate] missing PRIVATE_KEY');
            return res.status(400).json({ success: false, error: 'PRIVATE_KEY env var is required' });
        }
        if (!isAddress(userContract)) {
            console.warn('[api][allocate] invalid userContract');
            return res.status(400).json({ success: false, error: 'Invalid userContract address' });
        }

        const n = tokens?.length || 0;
        if (!(n && bps?.length === n && decimals?.length === n && priceFeeds?.length === n)) {
            return res.status(400).json({ success: false, error: 'tokens, bps, decimals, priceFeeds must be equal-length arrays' });
        }
        if (!tokens.every(isAddress)) return res.status(400).json({ success: false, error: 'Invalid token address in tokens' });
        if (!priceFeeds.every(isAddress)) return res.status(400).json({ success: false, error: 'Invalid address in priceFeeds' });
        if (!bps.every((x) => Number.isInteger(Number(x)) && Number(x) >= 0)) return res.status(400).json({ success: false, error: 'Invalid bps entries' });
        const totalBps = bps.map(Number).reduce((a, b) => a + b, 0);
        if (totalBps !== 10000) return res.status(400).json({ success: false, error: 'bps must sum to 10000' });

        const tokensArg = `"[${tokens.join(',')}]"`;
        const bpsArg = `"[${bps.join(',')}]"`;
        const decimalsArg = `"[${decimals.join(',')}]"`;
        const priceFeedsArg = `"[${priceFeeds.join(',')}]"`;

        const cmd = `cast send ${userContract} "setPortfolioAllocation(address[],uint16[],uint8[],address[])" ${tokensArg} ${bpsArg} ${decimalsArg} ${priceFeedsArg} --rpc-url ${rpcUrl} --private-key ${privateKey} | cat`;
        const startedAt = Date.now();
        console.log('[cast][allocate] executing', { cmd: redactSensitive(cmd), params: { userContract, tokens, bps, decimals, priceFeeds, rpcUrl } });
        const { stdout, stderr } = await runShellCommand(cmd);
        const durationMs = Date.now() - startedAt;
        if (stderr) console.warn('allocate stderr:', stderr);
        console.log('[cast][allocate] completed', { durationMs, txOutput: stdout.trim() });
        return res.json({ success: true, result: { output: stdout } });
    } catch (err) {
        console.error('Error in /portfolio/allocate:', { message: err?.message, stderr: err?.stderr });
        return res.status(500).json({ success: false, error: 'Allocation failed', details: err.stderr || err.message });
    }
});

// POST /portfolio/check
// body: { userContract: string, tokenAddress?: string, rpcUrl?: string }
// Returns ERC20 balanceOf(userContract)
app.post('/portfolio/check', async (req, res) => {
    try {
        console.log('[api][check] request', { body: { userContract: req.body?.userContract, tokenAddress: req.body?.tokenAddress } });
        const rpcUrl = (req.body?.rpcUrl || process.env.BASE_SEPOLIA_RPC_URL || '').toString();
        const userContract = (req.body?.userContract || '').toString();
        const tokenAddress = (req.body?.tokenAddress || process.env.USDC_ADDRESS || '').toString();

        if (!rpcUrl) {
            console.warn('[api][check] missing rpcUrl');
            return res.status(400).json({ success: false, error: 'rpcUrl (or BASE_SEPOLIA_RPC_URL env) is required' });
        }
        if (!isAddress(userContract)) {
            console.warn('[api][check] invalid userContract');
            return res.status(400).json({ success: false, error: 'Invalid userContract address' });
        }
        if (!isAddress(tokenAddress)) {
            console.warn('[api][check] invalid tokenAddress');
            return res.status(400).json({ success: false, error: 'Invalid tokenAddress' });
        }

        const cmd = `cast call ${tokenAddress} "balanceOf(address)(uint256)" ${userContract} --rpc-url ${rpcUrl} | cat`;
        const startedAt = Date.now();
        console.log('[cast][check] executing', { cmd: redactSensitive(cmd), params: { tokenAddress, userContract, rpcUrl } });
        const { stdout, stderr } = await runShellCommand(cmd);
        const durationMs = Date.now() - startedAt;
        if (stderr) console.warn('check stderr:', stderr);
        const balance = stdout.trim();
        console.log('[cast][check] completed', { durationMs, balance });
        return res.json({ success: true, result: { balance } });
    } catch (err) {
        console.error('Error in /portfolio/check:', { message: err?.message, stderr: err?.stderr });
        return res.status(500).json({ success: false, error: 'Check failed', details: err.stderr || err.message });
    }
});

// Start server
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
    console.log(`Access the JWT at: http://localhost:${PORT}`);
    console.log(`Health check at: http://localhost:${PORT}/health`);
});
