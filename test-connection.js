// test-connection.js
const axios = require('axios');

async function testConnection() {
  try {
    console.log('🧪 Testando conexão entre serviços...');
    
    // Test Item Service
    console.log('1. Testando Item Service...');
    const itemsResponse = await axios.get('http://localhost:3003/items?limit=1');
    console.log('✅ Item Service OK');
    
    // Test List Service
    console.log('2. Testando List Service...');
    const listsResponse = await axios.get('http://localhost:3002/health');
    console.log('✅ List Service OK');
    
    // Test API Gateway
    console.log('3. Testando API Gateway...');
    const gatewayResponse = await axios.get('http://localhost:3000/health');
    console.log('✅ API Gateway OK');
    
    console.log('🎉 Todos os serviços estão funcionando!');
  } catch (error) {
    console.error('❌ Erro no teste:', error.message);
  }
}

testConnection();