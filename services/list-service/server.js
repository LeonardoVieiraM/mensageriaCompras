require("dotenv").config({ path: "../../.env" });
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const { v4: uuidv4 } = require("uuid");
const path = require("path");
const axios = require("axios");

// Importar banco NoSQL e service registry
const JsonDatabase = require("../../shared/JsonDatabase");
const serviceRegistry = require("../../shared/serviceRegistry");

class ListService {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 3002;
    this.serviceName = "list-service";
    this.serviceUrl = `http://localhost:${this.port}`;

    this.setupDatabase();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
    this.setupRabbitMQ();
  }

  setupDatabase() {
    const dbPath = path.join(__dirname, "database");
    this.listsDb = new JsonDatabase(dbPath, "lists");
    console.log("List Service: Banco NoSQL inicializado");
  }

  setupMiddleware() {
    this.app.use(helmet());
    this.app.use(cors());
    this.app.use(morgan("combined"));
    this.app.use(express.json());
    this.app.use(express.urlencoded({ extended: true }));

    // Service info headers
    this.app.use((req, res, next) => {
      res.setHeader("X-Service", this.serviceName);
      res.setHeader("X-Service-Version", "1.0.0");
      res.setHeader("X-Database", "JSON-NoSQL");
      next();
    });
  }

  setupRoutes() {
    // Health check
    this.app.get("/health", async (req, res) => {
      try {
        const listCount = await this.listsDb.count();
        const activeLists = await this.listsDb.count({ status: "active" });

        res.json({
          service: this.serviceName,
          status: "healthy",
          timestamp: new Date().toISOString(),
          uptime: process.uptime(),
          version: "1.0.0",
          database: {
            type: "JSON-NoSQL",
            listCount: listCount,
            activeLists: activeLists,
          },
        });
      } catch (error) {
        res.status(503).json({
          service: this.serviceName,
          status: "unhealthy",
          error: error.message,
        });
      }
    });

    // Service info (rota pública)
    this.app.get("/", (req, res) => {
      res.json({
        service: "List Service",
        version: "1.0.0",
        description: "Microsserviço para gerenciamento de listas de compras",
        database: "JSON-NoSQL",
        endpoints: [
          "POST /lists",
          "GET /lists",
          "GET /lists/:id",
          "PUT /lists/:id",
          "DELETE /lists/:id",
          "POST /lists/:id/items",
          "PUT /lists/:id/items/:itemId",
          "DELETE /lists/:id/items/:itemId",
          "GET /lists/:id/summary",
        ],
      });
    });

    // MIDDLEWARE DE AUTH PARA TODAS AS ROTAS SEGUINTES
    this.app.use(this.authMiddleware.bind(this));

    // Rotas de Listas
    this.app.post("/", this.createList.bind(this)); // POST / - Criar lista
    this.app.get("/user-lists", this.getLists.bind(this)); // GET /user-lists - Buscar TODAS as listas do usuário
    this.app.get("/:id", this.getList.bind(this)); // GET /:id - Buscar lista específica
    this.app.put("/:id", this.updateList.bind(this)); // PUT /:id - Atualizar lista
    this.app.delete("/:id", this.deleteList.bind(this)); // DELETE /:id - Excluir lista

    // Rotas de Itens
    this.app.post("/:id/items", this.addItemToList.bind(this)); // POST /:id/items - Adicionar item
    this.app.put("/:id/items/:itemId", this.updateItemInList.bind(this)); // PUT /:id/items/:itemId - Atualizar item
    this.app.delete("/:id/items/:itemId", this.removeItemFromList.bind(this)); // DELETE /:id/items/:itemId - Remover item

    // Rotas de Resumo e Checkout
    this.app.get("/:id/summary", this.getListSummary.bind(this)); // GET /:id/summary - Resumo da lista
    this.app.post("/:id/checkout", this.checkoutList.bind(this)); // POST /:id/checkout - Finalizar compra
  }

  setupErrorHandling() {
    this.app.use("*", (req, res) => {
      res.status(404).json({
        success: false,
        message: "Endpoint não encontrado",
        service: this.serviceName,
      });
    });

    this.app.use((error, req, res, next) => {
      console.error("List Service Error:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do serviço",
        service: this.serviceName,
      });
    });
  }

  // Auth middleware (valida token com User Service)
  async authMiddleware(req, res, next) {
    const authHeader = req.header("Authorization");

    if (!authHeader?.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Token obrigatório",
      });
    }

    try {
      const userServiceUrl = "http://localhost:3001";

      // Validar token com User Service
      const response = await axios.post(
        `${userServiceUrl}/auth/validate`,
        {
          token: authHeader.replace("Bearer ", ""),
        },
        {
          timeout: 5000,
          headers: {
            "Content-Type": "application/json",
          },
        }
      );

      if (response.data.success) {
        req.user = response.data.data.user;
        next();
      } else {
        res.status(401).json({
          success: false,
          message: "Token inválido",
        });
      }
    } catch (error) {
      console.error("Erro na validação do token:", error.message);
      res.status(503).json({
        success: false,
        message: "Serviço de autenticação indisponível",
      });
    }
  }

  async setupRabbitMQ() {
    try {
      const rabbitmqService = require("../../shared/rabbitmqService");
      await rabbitmqService.connect();
      console.log("✅ List Service conectado ao RabbitMQ");
    } catch (error) {
      console.error("❌ Erro ao conectar RabbitMQ:", error.message);
    }
  }

  // Create list
  async createList(req, res) {
    try {
      const { name, description } = req.body;

      if (!name) {
        return res.status(400).json({
          success: false,
          message: "Nome da lista é obrigatório",
        });
      }

      // Criar lista
      const newList = await this.listsDb.create({
        id: uuidv4(),
        userId: req.user.id,
        name,
        description: description || "",
        status: "active",
        items: [],
        summary: {
          totalItems: 0,
          purchasedItems: 0,
          estimatedTotal: 0,
        },
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });

      res.status(201).json({
        success: true,
        message: "Lista criada com sucesso",
        data: newList,
      });
    } catch (error) {
      console.error("Erro ao criar lista:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Get user's lists
  async getLists(req, res) {
    try {
      const { status } = req.query;
      const userId = req.user.id;

      console.log("🔍 [LIST-SERVICE] Buscando listas para usuário:", userId);

      const filter = { userId: userId };

      if (status) {
        filter.status = status;
      }

      const lists = await this.listsDb.find(filter, {
        sort: { updatedAt: -1 },
      });

      console.log(
        `✅ [LIST-SERVICE] Encontradas ${lists.length} listas para usuário ${userId}`
      );

      res.json({
        success: true,
        data: lists,
      });
    } catch (error) {
      console.error("Erro ao buscar listas:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Get specific list
  async getList(req, res) {
    try {
      const { id } = req.params;
      const list = await this.listsDb.findById(id);

      if (!list) {
        return res.status(404).json({
          success: false,
          message: "Lista não encontrada",
        });
      }

      // Verificar se o usuário tem acesso à lista
      if (list.userId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: "Acesso negado a esta lista",
        });
      }

      res.json({
        success: true,
        data: list,
      });
    } catch (error) {
      console.error("Erro ao buscar lista:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Update list
  async updateList(req, res) {
    try {
      const { id } = req.params;
      const { name, description, status } = req.body;

      const list = await this.listsDb.findById(id);
      if (!list) {
        return res.status(404).json({
          success: false,
          message: "Lista não encontrada",
        });
      }

      // Verificar se o usuário tem acesso à lista
      if (list.userId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: "Acesso negado a esta lista",
        });
      }

      // Preparar atualizações
      const updates = {};
      if (name) updates.name = name;
      if (description !== undefined) updates.description = description;
      if (status) updates.status = status;

      updates.updatedAt = new Date().toISOString();

      const updatedList = await this.listsDb.update(id, updates);

      res.json({
        success: true,
        message: "Lista atualizada com sucesso",
        data: updatedList,
      });
    } catch (error) {
      console.error("Erro ao atualizar lista:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Delete list
  async deleteList(req, res) {
    try {
      const { id } = req.params;

      const list = await this.listsDb.findById(id);
      if (!list) {
        return res.status(404).json({
          success: false,
          message: "Lista não encontrada",
        });
      }

      // Verificar se o usuário tem acesso à lista
      if (list.userId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: "Acesso negado a esta lista",
        });
      }

      await this.listsDb.delete(id);

      res.json({
        success: true,
        message: "Lista excluída com sucesso",
      });
    } catch (error) {
      console.error("Erro ao excluir lista:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Add item to list
  async addItemToList(req, res) {
    try {
      const { id } = req.params;
      const { itemId, quantity, notes } = req.body;

      if (!itemId) {
        return res.status(400).json({
          success: false,
          message: "ID do item é obrigatório",
        });
      }

      const list = await this.listsDb.findById(id);
      if (!list) {
        return res.status(404).json({
          success: false,
          message: "Lista não encontrada",
        });
      }

      // Verificar se o usuário tem acesso à lista
      if (list.userId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: "Acesso negado a esta lista",
        });
      }

      // Buscar informações do item no Item Service
      let itemInfo;
      try {
        const itemServiceUrl = "http://localhost:3003";
        const response = await axios.get(`${itemServiceUrl}/items/${itemId}`, {
          timeout: 5000,
        });

        if (response.data.success) {
          itemInfo = response.data.data;
        } else {
          return res.status(404).json({
            success: false,
            message: "Item não encontrado no catálogo",
          });
        }
      } catch (error) {
        console.error("Erro ao buscar item:", error.message);
        return res.status(503).json({
          success: false,
          message: "Serviço de itens indisponível",
        });
      }

      // Verificar se o item já está na lista
      const existingItemIndex = list.items.findIndex(
        (item) => item.itemId === itemId
      );

      if (existingItemIndex >= 0) {
        // Atualizar item existente
        list.items[existingItemIndex].quantity += parseFloat(quantity) || 1;
        list.items[existingItemIndex].updatedAt = new Date().toISOString();

        if (notes) {
          list.items[existingItemIndex].notes = notes;
        }
      } else {
        // Adicionar novo item
        list.items.push({
          itemId: itemInfo.id,
          itemName: itemInfo.name,
          quantity: parseFloat(quantity) || 1,
          unit: itemInfo.unit,
          estimatedPrice: itemInfo.averagePrice,
          purchased: false,
          notes: notes || "",
          addedAt: new Date().toISOString(),
          updatedAt: new Date().toISOString(),
        });
      }

      // Atualizar sumário
      list.summary = this.calculateSummary(list.items);
      list.updatedAt = new Date().toISOString();

      const updatedList = await this.listsDb.update(id, list);

      res.status(201).json({
        success: true,
        message: "Item adicionado à lista",
        data: updatedList,
      });
    } catch (error) {
      console.error("Erro ao adicionar item à lista:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Update item in list
  async updateItemInList(req, res) {
    try {
      const { id, itemId } = req.params;
      const { quantity, purchased, notes } = req.body;

      const list = await this.listsDb.findById(id);
      if (!list) {
        return res.status(404).json({
          success: false,
          message: "Lista não encontrada",
        });
      }

      // Verificar se o usuário tem acesso à lista
      if (list.userId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: "Acesso negado a esta lista",
        });
      }

      // Encontrar o item na lista
      const itemIndex = list.items.findIndex((item) => item.itemId === itemId);
      if (itemIndex === -1) {
        return res.status(404).json({
          success: false,
          message: "Item não encontrado na lista",
        });
      }

      // Atualizar o item
      if (quantity !== undefined)
        list.items[itemIndex].quantity = parseFloat(quantity);
      if (purchased !== undefined) list.items[itemIndex].purchased = purchased;
      if (notes !== undefined) list.items[itemIndex].notes = notes;

      list.items[itemIndex].updatedAt = new Date().toISOString();

      // Atualizar sumário
      list.summary = this.calculateSummary(list.items);
      list.updatedAt = new Date().toISOString();

      const updatedList = await this.listsDb.update(id, list);

      res.json({
        success: true,
        message: "Item atualizado na lista",
        data: updatedList,
      });
    } catch (error) {
      console.error("Erro ao atualizar item na lista:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Remove item from list
  async removeItemFromList(req, res) {
    try {
      const { id, itemId } = req.params;

      const list = await this.listsDb.findById(id);
      if (!list) {
        return res.status(404).json({
          success: false,
          message: "Lista não encontrada",
        });
      }

      // Verificar se o usuário tem acesso à lista
      if (list.userId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: "Acesso negado a esta lista",
        });
      }

      // Filtrar o item a ser removido
      list.items = list.items.filter((item) => item.itemId !== itemId);

      // Atualizar sumário
      list.summary = this.calculateSummary(list.items);
      list.updatedAt = new Date().toISOString();

      const updatedList = await this.listsDb.update(id, list);

      res.json({
        success: true,
        message: "Item removido da lista",
        data: updatedList,
      });
    } catch (error) {
      console.error("Erro ao remover item da lista:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Get list summary
  async getListSummary(req, res) {
    try {
      const { id } = req.params;

      const list = await this.listsDb.findById(id);
      if (!list) {
        return res.status(404).json({
          success: false,
          message: "Lista não encontrada",
        });
      }

      // Verificar se o usuário tem acesso à lista
      if (list.userId !== req.user.id) {
        return res.status(403).json({
          success: false,
          message: "Acesso negado a esta lista",
        });
      }

      res.json({
        success: true,
        data: {
          summary: list.summary,
          items: list.items,
        },
      });
    } catch (error) {
      console.error("Erro ao buscar sumário da lista:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  async checkoutList(req, res) {
    try {
      const { id } = req.params;
      const userId = req.user.id;

      console.log("🛒 [LIST-SERVICE] Iniciando checkout para lista:", id);

      // Buscar lista
      const list = await this.listsDb.findById(id);
      if (!list || list.userId !== userId) {
        return res.status(404).json({
          success: false,
          message: "Lista não encontrada",
        });
      }

      if (list.items.length === 0) {
        return res.status(400).json({
          success: false,
          message: "Lista vazia - adicione itens antes do checkout",
        });
      }

      const message = {
        listId: id,
        userId: userId,
        userEmail: req.user.email,
        userName: `${req.user.firstName} ${req.user.lastName}`,
        items: list.items,
        total: list.summary?.estimatedTotal || 0,
        timestamp: new Date().toISOString(),
      };

      console.log(
        "📤 [LIST-SERVICE] Publicando evento de checkout no RabbitMQ:",
        {
          listId: id,
          items: list.items.length,
          total: message.total,
        }
      );

      // Publicar mensagem no RabbitMQ
      await this.publishCheckoutEvent(message);

      // Atualizar status da lista para "completed"
      const updatedList = await this.listsDb.update(id, {
        status: "completed",
        completedAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });

      console.log("✅ [LIST-SERVICE] Checkout concluído para lista:", id);

      // Retornar 202 Accepted imediatamente
      res.status(202).json({
        success: true,
        message: "Checkout iniciado. Processando em background...",
        data: {
          listId: id,
          status: "completed",
          itemsProcessed: list.items.length,
          total: message.total,
        },
      });
    } catch (error) {
      console.error("❌ [LIST-SERVICE] Erro no checkout:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Adicionar método para publicar no RabbitMQ
  async publishCheckoutEvent(message) {
    try {
      const rabbitmqService = require("../../shared/rabbitmqService");

      console.log("🐰 [LIST-SERVICE] Conectando ao RabbitMQ...");

      // Garantir que está conectado
      if (!rabbitmqService.isConnected) {
        await rabbitmqService.connect();
      }

      console.log("📤 [LIST-SERVICE] Publicando mensagem...");

      await rabbitmqService.publish(
        "shopping_events",
        "list.checkout.completed",
        message
      );

      console.log(
        "✅ [LIST-SERVICE] Evento de checkout publicado com sucesso!"
      );
      console.log("   Lista ID:", message.listId);
      console.log("   Itens:", message.items.length);
      console.log("   Total: R$", message.total);
    } catch (error) {
      console.error("❌ [LIST-SERVICE] Erro ao publicar evento:", error);
      console.log("⚠️ [LIST-SERVICE] Checkout concluído sem RabbitMQ");
    }
  }

  // Helper: Calculate list summary
  calculateSummary(items) {
    const totalItems = items.length;
    const purchasedItems = items.filter((item) => item.purchased).length;
    const estimatedTotal = items.reduce((total, item) => {
      return total + item.estimatedPrice * item.quantity;
    }, 0);

    return {
      totalItems,
      purchasedItems,
      estimatedTotal: parseFloat(estimatedTotal.toFixed(2)),
    };
  }

  // Register with service registry
  registerWithRegistry() {
    serviceRegistry.register(this.serviceName, {
      url: this.serviceUrl,
      version: "1.0.0",
      database: "JSON-NoSQL",
      endpoints: [
        "/health",
        "/lists",
        "/lists/:id",
        "/lists/:id/items/:itemId",
      ],
    });
  }

  // Start health check reporting
  startHealthReporting() {
    setInterval(() => {
      serviceRegistry.updateHealth(this.serviceName, true);
    }, 30000);
  }

  start() {
    this.app.listen(this.port, () => {
      console.log("=====================================");
      console.log(`List Service iniciado na porta ${this.port}`);
      console.log(`URL: ${this.serviceUrl}`);
      console.log(`Health: ${this.serviceUrl}/health`);
      console.log(`Database: JSON-NoSQL`);
      console.log("=====================================");

      // Register with service registry
      this.registerWithRegistry();
      this.startHealthReporting();
    });
  }
}

// Start service
if (require.main === module) {
  const listService = new ListService();
  listService.start();

  // Graceful shutdown
  process.on("SIGTERM", async () => {
    console.log(`🛑 Encerrando ${this.serviceName}...`);
    if (serviceRegistry.unregister) {
      serviceRegistry.unregister(this.serviceName);
    }
    process.exit(0);
  });

  process.on("SIGINT", async () => {
    console.log(`🛑 Encerrando ${this.serviceName}...`);
    if (serviceRegistry.unregister) {
      serviceRegistry.unregister(this.serviceName);
    }
    process.exit(0);
  });
}

module.exports = ListService;
