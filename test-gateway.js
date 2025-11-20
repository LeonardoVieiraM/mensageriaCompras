const axios = require('axios');

async function testGateway() {
  try {
    console.log('🧪 Testando API Gateway...');
    
    // Test health endpoint
    const healthResponse = await axios.get('http://127.0.0.1:3000/health');
    console.log('✅ Health check:', healthResponse.data);
    
    // Test registry
    const registryResponse = await axios.get('http://127.0.0.1:3000/registry');
    console.log('✅ Registry:', registryResponse.data);
    
    // Test login endpoint directly
    console.log('🔐 Testando login endpoint...');
    const loginResponse = await axios.post('http://127.0.0.1:3000/api/auth/login', {
      identifier: 'admin@shopping.com',
      password: 'admin123'
    }, {
      headers: {
        'Content-Type': 'application/json'
      },
      timeout: 5000
    });

    console.log('✅ Login bem-sucedido!');
    console.log('Token:', loginResponse.data.data.token.substring(0, 20) + '...');
    
    return loginResponse.data.data.token;
  } catch (error) {
    console.error('❌ Gateway test error:', error.response?.data || error.message);
    if (error.code) {
      console.error('Error code:', error.code);
    }
  }
}

testGateway();