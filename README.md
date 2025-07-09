# Compact Compiler Service

A Node.js service that provides Compact smart contract compilation for Web3Fast's WebContainer environment.

## Prerequisites

1. **Install Node.js** (version 18+ recommended)
2. **Install Compact Compiler**:
   - Download from: https://docs.midnight.network/relnotes/compact
   - Extract and add `compactc` to your PATH
   - Verify with: `compactc --version`

## Setup

```bash
cd local-compact-service
npm install
```

## Usage

### Start the service

```bash
npm start
# or for development with auto-reload:
npm run dev
```

The service runs on `http://localhost:3002`

### Test the service

```bash
# Check if compactc is available
curl http://localhost:3002/check-compiler

# Compile a contract
curl -X POST http://localhost:3002/compile \
  -H "Content-Type: application/json" \
  -d '{
    "contractCode": "pragma language_version 0.16;\nimport CompactStandardLibrary;\nexport ledger counter: Counter;\nexport circuit increment(): [] {\n  counter.increment(1);\n}",
    "contractName": "counter"
  }'
```

## API Endpoints

### `GET /check-compiler`
Checks if the Compact compiler is available and returns version info.

### `POST /compile`
Compiles a Compact smart contract.

**Request body:**
```json
{
  "contractCode": "string", // Required: Compact source code
  "contractName": "string", // Optional: contract name (default: "contract")
  "projectFiles": {}        // Optional: additional project files
}
```

**Response:**
```json
{
  "success": true,
  "contractName": "counter",
  "artifacts": {
    "index.ts": "...", // Generated TypeScript bindings
    "types.ts": "...", // Type definitions
    // ... other generated files
  },
  "stdout": "...",
  "stderr": "...",
  "message": "Compact contract compiled successfully"
}
```

## Integration with Web3Fast

This service is designed to work with Web3Fast's WebContainer environment:

1. WebContainer frontend sends Compact code to this service
2. Service compiles using local `compactc` binary
3. Returns generated TypeScript bindings and artifacts
4. Frontend can use the compiled artifacts for deployment and interaction

## Troubleshooting

### "compactc not found" error
- Make sure you've downloaded and installed the Compact compiler
- Verify it's in your PATH: `which compactc`
- Restart the service after installing

### Permission issues
- On Unix systems, ensure `compactc` has execute permissions: `chmod +x compactc`

### Compilation timeouts
- Large contracts may need more time
- Increase timeout in `index.js` if needed

## Development

To modify the service:

1. Edit `index.js` for main logic
2. Use `npm run dev` for auto-reload during development
3. Test with curl or Postman
4. Ensure compatibility with Web3Fast's API patterns 