const express = require('express');
const cors = require('cors');
const { exec, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');
const { promisify } = require('util');

const app = express();
const PORT = process.env.PORT || 3002;

app.use(cors());
app.use(express.json({ limit: '10mb' }));

const execAsync = promisify(exec);

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    status: 'ok', 
    message: 'Compact Compiler Service for Web3Fast',
    service: 'compact-compiler',
    versions: ['0.23.0', '0.24.0']
  });
});

// Check compiler availability and versions
app.get('/check-compiler', async (req, res) => {
  try {
    const versions = {};
    
    // Check 0.24.0
    try {
      const { stdout } = await execAsync('/usr/local/bin/compact-0.24.0/compactc --version');
      versions['0.24.0'] = stdout.trim();
    } catch (error) {
      versions['0.24.0'] = 'Not available';
    }
    
    // Check 0.23.0
    try {
      const { stdout } = await execAsync('/usr/local/bin/compact-0.23.0/compactc --version');
      versions['0.23.0'] = stdout.trim();
    } catch (error) {
      versions['0.23.0'] = 'Not available';
    }
    
    // Check default
    const { stdout } = await execAsync('compactc --version');
    
    res.json({
      success: true,
      available: true,
      defaultVersion: stdout.trim(),
      versions: versions,
      message: 'Compact compiler service with dual version support'
    });
  } catch (error) {
    res.json({
      success: false,
      available: false,
      error: 'compactc not found in PATH',
      message: 'Please install the Compact compiler'
    });
  }
});

// Get available compiler versions
app.get('/api/compiler-versions', (req, res) => {
  const versions = {
    available: ['0.23.0', '0.24.0'],
    default: '0.24.0',
    recommended: {
      'openzeppelin-examples': '0.23.0',
      'new-development': '0.24.0',
      'assert-statements': '0.23.0',
      'latest-syntax': '0.24.0'
    },
    notes: {
      '0.23.0': 'Compatible with OpenZeppelin examples and assert statements',
      '0.24.0': 'Latest version with breaking syntax changes'
    }
  };
  res.json(versions);
});

// Compilation endpoint with version support
app.post('/compile', async (req, res) => {
  try {
    const { 
      contractCode, 
      contractName = 'contract', 
      compilerVersion = '0.24.0',
      projectFiles = {} 
    } = req.body;

    if (!contractCode) {
      return res.status(400).json({ 
        error: 'Missing required field: contractCode',
        success: false
      });
    }

    // Validate compiler version
    const supportedVersions = ['0.23.0', '0.24.0'];
    if (!supportedVersions.includes(compilerVersion)) {
      return res.status(400).json({
        success: false,
        error: `Unsupported compiler version: ${compilerVersion}. Supported: ${supportedVersions.join(', ')}`
      });
    }

    // Select compiler path based on version
    const compilerPath = `/usr/local/bin/compact-${compilerVersion}/compactc`;
    
    // Verify compiler exists
    if (!fs.existsSync(compilerPath)) {
      return res.status(500).json({
        success: false,
        error: `Compiler not found for version ${compilerVersion}`
      });
    }

    console.log(`\n🌙 Compiling Compact contract: ${contractName} with compactc ${compilerVersion}`);

    // Create temporary directory for compilation
    const tempDir = path.join(__dirname, 'temp', Date.now().toString());
    await fs.promises.mkdir(tempDir, { recursive: true });

    try {
      // Write contract file
      const contractPath = path.join(tempDir, `${contractName}.compact`);
      await fs.promises.writeFile(contractPath, contractCode);

      // Write additional project files if provided
      for (const [filePath, content] of Object.entries(projectFiles)) {
        const fullPath = path.join(tempDir, filePath);
        await fs.promises.mkdir(path.dirname(fullPath), { recursive: true });
        await fs.promises.writeFile(fullPath, content);
      }

      // Output directory for compiled artifacts
      const outputDir = path.join(tempDir, 'managed', contractName);

      // Run compactc compilation with selected version
      console.log(`🔧 Running compactc ${compilerVersion}...`);
      const compileCommand = `"${compilerPath}" "${contractPath}" "${outputDir}"`;
      
      const { stdout, stderr } = await execAsync(compileCommand, {
        cwd: tempDir,
        timeout: 30000 // 30 second timeout
      });

      // Check if compilation succeeded by looking for output files
      const outputExists = fs.existsSync(outputDir);
      
      if (!outputExists) {
        throw new Error('Compilation failed - no output generated');
      }

      // Read generated files
      const artifacts = {};
      
      try {
        // Look for TypeScript bindings
        const files = await fs.promises.readdir(outputDir, { recursive: true });
        
        for (const file of files) {
          if (typeof file === 'string') {
            const filePath = path.join(outputDir, file);
            const stat = await fs.promises.stat(filePath);
            
            if (stat.isFile()) {
              const content = await fs.promises.readFile(filePath, 'utf8');
              artifacts[file] = content;
            }
          }
        }
      } catch (readError) {
        console.warn('Warning: Could not read all generated files:', readError.message);
      }

      console.log(`✅ SUCCESS! Compiled ${contractName} with compactc ${compilerVersion}`);

      res.json({
        success: true,
        contractName,
        compilerVersion,
        artifacts,
        stdout: stdout || '',
        stderr: stderr || '',
        message: `Compact contract compiled successfully with compactc ${compilerVersion}`
      });

    } finally {
      // Cleanup temp directory
      try {
        await fs.promises.rm(tempDir, { recursive: true, force: true });
      } catch (cleanupError) {
        console.warn('Warning: Could not cleanup temp directory:', cleanupError.message);
      }
    }

  } catch (error) {
    console.error('💥 Compilation error:', error);
    
    let errorMessage = error.message;
    let isCompilerError = false;
    
    if (error.code === 'ENOENT') {
      errorMessage = 'compactc not found. Please install the Compact compiler.';
    } else if (error.stderr) {
      errorMessage = error.stderr;
      isCompilerError = true;
    }

    res.status(500).json({
      success: false,
      compilerVersion: req.body.compilerVersion || '0.24.0',
      error: errorMessage,
      isCompilerError,
      stdout: error.stdout || '',
      stderr: error.stderr || ''
    });
  }
});

// API endpoint for compatibility with web3fast patterns
app.post('/api/compile', (req, res) => {
  // Redirect to main compile endpoint
  req.url = '/compile';
  app._router.handle(req, res);
});

app.listen(PORT, () => {
  console.log(`🌙 Compact Compiler Service running on port ${PORT}`);
  console.log(`📦 Dual compiler support: 0.23.0 & 0.24.0`);
  console.log(`🔗 Health check: http://localhost:${PORT}`);
  console.log(`🔧 Compiler check: http://localhost:${PORT}/check-compiler`);
  console.log(`📋 Versions: http://localhost:${PORT}/api/compiler-versions`);
  console.log(`🚀 Test: curl -X POST http://localhost:${PORT}/compile`);
  console.log(`📚 Make sure compactc is installed and in your PATH`);
});