const express = require("express");
const rabbitmqService = require("../../shared/rabbitmqService");

class NotificationService {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 3004;
    this.serviceName = "notification-service";

    this.setupRoutes();
    this.startConsumer();
  }

  setupRoutes() {
    this.app.get("/health", (req, res) => {
      res.json({
        service: this.serviceName,
        status: "healthy",
        timestamp: new Date().toISOString(),
      });
    });

    this.app.get("/", (req, res) => {
      res.json({
        service: "Notification Service",
        description: "Serviço de notificações assíncronas",
        status: "Consumer ativo para eventos de checkout",
      });
    });
  }

  async startConsumer() {
    try {
      await rabbitmqService.consume(
        "notification_queue",
        "list.checkout.#",
        this.handleCheckoutEvent.bind(this)
      );
    } catch (error) {
      console.error("Erro ao iniciar consumer:", error);
      setTimeout(() => this.startConsumer(), 5000);
    }
  }

  async handleCheckoutEvent(message) {
    console.log(`\n[NOTIFICATION-SERVICE] RECEBENDO COMPROVANTE:`);
    console.log(`   Lista ID: ${message.listId}`);
    console.log(`   Usuário: ${message.userName} (${message.userEmail})`);
    console.log(`   Total: R$ ${message.total}`);
    console.log(`   Itens: ${message.items.length}`);
    console.log(`   Timestamp: ${message.timestamp}`);

    message.items.forEach((item, index) => {
      console.log(
        `   ${index + 1}. ${item.itemName} - R$ ${item.estimatedPrice} x ${
          item.quantity
        }`
      );
    });

    console.log("[NOTIFICATION-SERVICE] Enviando comprovante por email...");
    await this.delay(1000);
    console.log("[NOTIFICATION-SERVICE] Comprovante enviado com sucesso!\n");
  }

  delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  start() {
    this.app.listen(this.port, () => {
      console.log("=====================================");
      console.log(`Notification Service iniciado na porta ${this.port}`);
      console.log(`URL: http://localhost:${this.port}`);
      console.log(`Consumer: list.checkout.#`);
      console.log("=====================================");
    });
  }
}

if (require.main === module) {
  const service = new NotificationService();
  service.start();
}

module.exports = NotificationService;
