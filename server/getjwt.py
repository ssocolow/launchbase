import jwt
from cryptography.hazmat.primitives import serialization
import time
import secrets

key_name       = "organizations/05c24e65-3c2a-441a-836f-5efb731a556c/apiKeys/a10cf8fb-1a3b-4aad-9a53-a937d3d73d00"
# key_name = "c1faf930-d338-4cc6-b416-a239b8a5d0d5"
key_secret     = "cUm7zjEI+9LJ/TMOlJ+AoCMN9+IteMG1W+Fdb1scCTdpiyKGQ+2GQbF9FCCqD5UcwaPDN061BIwB4SeBohWN+Q=="
# key_secret = "P3IoPSPX8nOU8bxUqHSXOqo0Yw6Rn3X2zUVNDLA9sRUzpfrkIonMu+h+Efo5wPJGO8tgJvNmvA3esAJyaEGpmg=="
request_method = "POST"
request_host   = "https://api.developer.coinbase.com"
request_path   = "/onramp/v1/token"
def build_jwt(uri):
    private_key_bytes = key_secret.encode('utf-8')
    private_key = serialization.load_pem_private_key(private_key_bytes, password=None)
    jwt_payload = {
        'sub': key_name,
        'iss': "cdp",
        'nbf': int(time.time()),
        'exp': int(time.time()) + 1200,
        'uri': uri,
    }
    jwt_token = jwt.encode(
        jwt_payload,
        private_key,
        algorithm='Ed25519',
        headers={'kid': key_name, 'nonce': secrets.token_hex()},
    )
    return jwt_token
def main():
    uri = f"{request_method} {request_host}{request_path}"
    jwt_token = build_jwt(uri)
    print(jwt_token)
if __name__ == "__main__":
    main()
