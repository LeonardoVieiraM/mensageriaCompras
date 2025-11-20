const axios = require('axios');

async function testRabbitMQCheckout() {
  try {
    console.log('🧪 Testando checkout com RabbitMQ...');
    
    // First, get a token and create a list with items
    const loginResponse = await axios.post('http://localhost:3000/api/auth/login', {
      identifier: 'admin@shopping.com',
      password: 'admin123'
    });

    const token = loginResponse.data.data.token;
    console.log('✅ Token obtido');

    // Create a test list
    const listResponse = await axios.post('http://localhost:3000/api/lists/', {
      name: 'Teste RabbitMQ',
      description: 'Lista para testar checkout'
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });

    const listId = listResponse.data.data.id;
    console.log('✅ Lista criada:', listId);

    // Add an item to the list
    await axios.post(`http://localhost:3000/api/lists/${listId}/items`, {
      itemId: 'b288041e-6c5e-42d3-b635-dc2d1217ee89', // Leite
      quantity: 2
    }, {
      headers: { Authorization: `Bearer ${token}` }
    });

    console.log('✅ Item adicionado à lista');

    // Test checkout
    console.log('🛒 Executando checkout...');
    const checkoutResponse = await axios.post(
      `http://localhost:3000/api/lists/${listId}/checkout`,
      {},
      { headers: { Authorization: `Bearer ${token}` } }
    );

    console.log('✅ Checkout response:', checkoutResponse.data);
    
    if (checkoutResponse.status === 202) {
      console.log('🎉 Checkout iniciado com sucesso!');
      console.log('📤 Verifique os logs do Notification e Analytics Service');
    }

  } catch (error) {
    console.error('❌ Test error:', error.response?.data || error.message);
  }
}

testRabbitMQCheckout();