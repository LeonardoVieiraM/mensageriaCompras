require('dotenv').config();
const amqp = require('amqplib');

async function testRabbitMQ() {
    try {
        console.log('Testando conexão com RabbitMQ...');
        console.log('URL:', process.env.CLOUDAMQP_URL.replace(/:[^:]*@/, ':****@')); // Esconde senha
        
        const connection = await amqp.connect(process.env.CLOUDAMQP_URL);
        const channel = await connection.createChannel();
        
        console.log('Conexão RabbitMQ bem-sucedida!');
        
        await channel.close();
        await connection.close();
        console.log('Conexão fechada corretamente');
        
    } catch (error) {
        console.error('Erro na conexão RabbitMQ:', error.message);
    }
}

testRabbitMQ();