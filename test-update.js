// test-update.js
const axios = require('axios');

async function testUpdate() {
  try {
    // First, get a list to test with
    console.log('1. Buscando listas...');
    const listsResponse = await axios.get('http://localhost:3002/user-lists', {
      headers: {
        'Authorization': 'Bearer YOUR_VALID_TOKEN_HERE' // You'll need to get a valid token
      }
    });
    
    if (listsResponse.data.success && listsResponse.data.data.length > 0) {
      const list = listsResponse.data.data[0];
      console.log('Lista encontrada:', list.id);
      
      if (list.items.length > 0) {
        const item = list.items[0];
        console.log('Item para atualizar:', item.itemId);
        
        // Test update
        const updateResponse = await axios.put(
          `http://localhost:3002/${list.id}/items/${item.itemId}`,
          {
            quantity: item.quantity + 1,
            purchased: true
          },
          {
            headers: {
              'Authorization': 'Bearer YOUR_VALID_TOKEN_HERE',
              'Content-Type': 'application/json'
            }
          }
        );
        
        console.log('✅ Update response:', updateResponse.data);
      }
    }
  } catch (error) {
    console.error('❌ Test error:', error.response?.data || error.message);
  }
}

testUpdate();