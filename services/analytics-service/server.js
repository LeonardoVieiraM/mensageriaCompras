const express = require("express");
const rabbitmqService = require("../../shared/rabbitmqService");

class AnalyticsService {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 3005;
    this.serviceName = "analytics-service";
    this.stats = {
      totalCheckouts: 0,
      totalRevenue: 0,
      averageTicket: 0,
      lastCheckout: null,
    };

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
        service: "Analytics Service",
        description: "Serviço de analytics para dashboards",
        stats: this.stats,
      });
    });

    this.app.get("/stats", (req, res) => {
      res.json({
        success: true,
        data: this.stats,
      });
    });
  }

  async startConsumer() {
    try {
      await rabbitmqService.consume(
        "analytics_queue",
        "list.checkout.#",
        this.handleCheckoutEvent.bind(this)
      );
    } catch (error) {
      console.error("Erro ao iniciar consumer:", error);
      setTimeout(() => this.startConsumer(), 5000);
    }
  }

  async handleCheckoutEvent(message) {
    console.log(`\n[ANALYTICS-SERVICE] PROCESSANDO ANALYTICS:`);
    console.log(`   Lista: ${message.listId}`);
    console.log(`   Valor: R$ ${message.total}`);
    console.log(`   Itens: ${message.items.length}`);

    // Atualizar estatísticas
    this.stats.totalCheckouts++;
    this.stats.totalRevenue += message.total;
    this.stats.averageTicket =
      this.stats.totalRevenue / this.stats.totalCheckouts;
    this.stats.lastCheckout = message.timestamp;

    // Simular processamento de analytics
    console.log("[ANALYTICS-SERVICE] Processando analytics...");
    await this.delay(800);

    console.log("[ANALYTICS-SERVICE] Estatísticas atualizadas:");
    console.log(`   - Total de checkouts: ${this.stats.totalCheckouts}`);
    console.log(`   - Receita total: R$ ${this.stats.totalRevenue.toFixed(2)}`);
    console.log(`   - Ticket médio: R$ ${this.stats.averageTicket.toFixed(2)}`);
    console.log("Analytics atualizado!\n");
  }

  delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  start() {
    this.app.listen(this.port, () => {
      console.log("=====================================");
      console.log(`Analytics Service iniciado na porta ${this.port}`);
      console.log(`URL: http://localhost:${this.port}`);
      console.log(`Consumer: list.checkout.#`);
      console.log("=====================================");
    });
  }
}

// Start service
if (require.main === module) {
  const service = new AnalyticsService();
  service.start();
}

module.exports = AnalyticsService;
