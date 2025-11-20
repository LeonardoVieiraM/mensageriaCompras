const axios = require('axios');

async function testAuth() {
  try {
    console.log('🧪 Testando autenticação...');
    
    // Test login with admin credentials
    const loginResponse = await axios.post('http://localhost:3000/api/auth/login', {
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
    console.error('❌ Erro no login:', error.response?.data || error.message);
  }
}

testAuth();