const axios = require('axios');

async function testListService() {
  try {
    console.log('🧪 Testando List Service...');
    
    // First, get a token
    const loginResponse = await axios.post('http://localhost:3000/api/auth/login', {
      identifier: 'admin@shopping.com',
      password: 'admin123'
    });

    const token = loginResponse.data.data.token;
    console.log('✅ Token obtido:', token.substring(0, 20) + '...');

    // Test List Service directly
    const listsResponse = await axios.get('http://localhost:3002/user-lists', {
      headers: {
        'Authorization': `Bearer ${token}`
      }
    });

    console.log('✅ List Service response:', {
      success: listsResponse.data.success,
      count: listsResponse.data.data?.length,
      lists: listsResponse.data.data?.map(list => ({
        id: list.id,
        name: list.name,
        items: list.items?.length
      }))
    });

    return listsResponse.data;
  } catch (error) {
    console.error('❌ List Service test error:', error.response?.data || error.message);
  }
}

testListService();