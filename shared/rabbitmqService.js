const amqp = require('amqplib');
require('dotenv').config();

class RabbitMQService {
    constructor() {
        this.connection = null;
        this.channel = null;
        this.isConnected = false;
        this.url = process.env.CLOUDAMQP_URL;
    }

    async connect() {
        if (this.isConnected) return;

        try {
            this.connection = await amqp.connect(this.url);
            this.channel = await this.connection.createChannel();
            
            await this.channel.assertExchange('shopping_events', 'topic', {
                durable: true
            });

            this.isConnected = true;
            console.log('Conectado ao RabbitMQ');

            this.connection.on('close', () => {
                this.isConnected = false;
                setTimeout(() => this.connect(), 5000);
            });

        } catch (error) {
            console.error('Erro ao conectar RabbitMQ:', error.message);
            setTimeout(() => this.connect(), 5000);
        }
    }

    async publish(exchange, routingKey, message) {
        if (!this.isConnected) {
            await this.connect();
        }

        try {
            const result = await this.channel.publish(
                exchange,
                routingKey,
                Buffer.from(JSON.stringify(message)),
                { persistent: true }
            );
            
            if (result) {
            } else {
                throw new Error('Falha ao publicar mensagem');
            }
        } catch (error) {
            console.error('Erro ao publicar mensagem:', error);
            throw error;
        }
    }

    async consume(queue, routingKey, callback) {
        if (!this.isConnected) {
            await this.connect();
        }

        try {
            const q = await this.channel.assertQueue(queue, {
                durable: true
            });
            await this.channel.bindQueue(q.queue, 'shopping_events', routingKey);

            await this.channel.consume(q.queue, async (msg) => {
                if (msg !== null) {
                    try {
                        const content = JSON.parse(msg.content.toString());
                        
                        await callback(content);
                        
                        this.channel.ack(msg);
                    } catch (error) {
                        console.error('Erro ao processar mensagem:', error);
                        this.channel.nack(msg, false, false);
                    }
                }
            });

        } catch (error) {
            console.error('Erro ao configurar consumer:', error);
            throw error;
        }
    }

    async close() {
        if (this.channel) await this.channel.close();
        if (this.connection) await this.connection.close();
        this.isConnected = false;
    }
}

module.exports = new RabbitMQService();