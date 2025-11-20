const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const axios = require("axios");
const path = require("path");

// Importar service registry
const serviceRegistry = require("../shared/serviceRegistry");

class ApiGateway {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 3000;
    this.serviceName = "api-gateway";
    this.serviceUrl = `http://localhost:${this.port}`;

    // Circuit breaker state
    this.circuitBreakers = {
      "user-service": { failures: 0, state: "CLOSED", lastFailure: 0 },
      "item-service": { failures: 0, state: "CLOSED", lastFailure: 0 },
      "list-service": { failures: 0, state: "CLOSED", lastFailure: 0 },
    };

    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
    this.startHealthChecks();
    this.initializeGateway();
  }

  async initializeGateway() {
    console.log("API Gateway inicializando...");

    // Aguarda os serviços se registrarem
    await this.delay(5000);

    console.log("API Gateway pronto para receber requisições");
    this.startHealthChecks();
  }

  delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  setupMiddleware() {
    this.app.use(helmet());

    // ✅ CORREÇÃO CRÍTICA: CORS melhorado para Flutter Web
    this.app.use((req, res, next) => {
      const allowedOrigins = [
        "http://localhost:3000",
        "http://localhost:5000",
        "http://localhost:8080",
        "http://localhost:18948",
        "http://localhost:44965",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:5000",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:18948",
        "http://127.0.0.1:44965",
        "http://localhost:65276",
        "http://127.0.0.1:65276",
      ];

      const origin = req.headers.origin;

      // Permite qualquer origem em desenvolvimento
      if (origin) {
        res.header("Access-Control-Allow-Origin", origin);
      } else {
        res.header("Access-Control-Allow-Origin", "*");
      }

      res.header(
        "Access-Control-Allow-Methods",
        "GET, POST, PUT, DELETE, OPTIONS, PATCH"
      );
      res.header(
        "Access-Control-Allow-Headers",
        "Content-Type, Authorization, X-Requested-With, Accept, Origin, Access-Control-Request-Method, Access-Control-Request-Headers, X-Requested-With"
      );
      res.header("Access-Control-Allow-Credentials", "true");
      res.header("Access-Control-Max-Age", "86400");

      // ✅ CORREÇÃO: Handle preflight requests
      if (req.method === "OPTIONS") {
        console.log("✅ Preflight OPTIONS request handled");
        return res.status(200).end();
      }

      next();
    });

    this.app.use(morgan("combined"));
    this.app.use(express.json({ limit: "10mb" }));
    this.app.use(express.urlencoded({ extended: true, limit: "10mb" }));

    // Service info headers
    this.app.use((req, res, next) => {
      res.setHeader("X-Service", this.serviceName);
      res.setHeader("X-Service-Version", "1.0.0");
      res.setHeader("X-Gateway", "Express");
      next();
    });
  }

  getServiceUrl(serviceName) {
    // URLs hardcoded como fallback - IGNORA completamente o registry
    const hardcodedUrls = {
      "user-service": "http://localhost:3001",
      "list-service": "http://localhost:3002",
      "item-service": "http://localhost:3003",
    };

    const url = hardcodedUrls[serviceName];
    if (url) {
      console.log(`Using hardcoded URL for ${serviceName}: ${url}`);
      return url;
    }

    console.error(`No URL found for service: ${serviceName}`);
    return null;
  }

  setupRoutes() {
    // Health check endpoint
    this.app.get("/health", this.healthCheck.bind(this));

    // Service registry endpoint
    this.app.get("/registry", this.getRegistry.bind(this));

    // ✅ CORREÇÃO DAS ROTAS - MAPEAMENTO CORRETO
    this.app.use("/api/auth", this.proxyToService("user-service", "/auth"));
    this.app.use("/api/users", this.proxyToService("user-service", "/users"));

    // ✅ CORREÇÃO CRÍTICA: /api/lists vai para / do list-service
    this.app.use("/api/lists", this.proxyToService("list-service", "/"));

    // ✅ CORREÇÃO: /api/items vai para / do item-service
    this.app.use("/api/items", this.proxyToService("item-service", "/"));

    // Aggregated endpoints
    this.app.get("/api/dashboard", this.getDashboard.bind(this));
    this.app.get("/api/search", this.globalSearch.bind(this));

    // ROTAS CORRIGIDAS - ESPECÍFICAS
    this.app.use("/api/auth", this.proxyToService("user-service", "/auth"));
    this.app.use("/api/users", this.proxyToService("user-service", "/users"));

    // ROTA ESPECÍFICA PARA BUSCAR LISTAS
    this.app.get("/api/lists", this.proxyToService("list-service", "/"));

    // ROTAS RESTANTES PARA LISTAS (com parâmetros)
    this.app.use("/api/lists/:id", this.proxyToService("list-service", "/"));

    // ROTA PARA CRIAR LISTA (já está funcionando)
    this.app.post("/api/lists", this.proxyToService("list-service", "/"));

    // ROTA PARA ADICIONAR ITEM À LISTA
    this.app.post("/api/lists/:id/items", this.proxyToService("list-service"));

    this.app.use("/api/items", this.proxyToService("item-service", "/"));

    // Root endpoint
    this.app.get("/", (req, res) => {
      res.json({
        service: "API Gateway",
        version: "1.0.0",
        description:
          "Gateway para Sistema de Listas de Compras com Microsserviços",
        endpoints: [
          "GET /health - Status dos serviços",
          "GET /registry - Serviços registrados",
          "GET /api/dashboard - Dashboard do usuário",
          "GET /api/search - Busca global",
          "/api/auth/* - User Service",
          "/api/users/* - User Service",
          "/api/items/* - Item Service",
          "/api/lists/* - List Service", // ← ESTA É A ROTA IMPORTANTE
        ],
      });
    });
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
      console.error("API Gateway Error:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do gateway",
        service: this.serviceName,
      });
    });
  }

  // Health check for all services
  async healthCheck(req, res) {
    try {
      let services;
      try {
        services = serviceRegistry.getAllServices();
      } catch (error) {
        console.warn("Erro ao acessar registry:", error.message);
        services = {};
      }

      const healthResults = {};
      const serviceUrls = {
        "user-service": "http://localhost:3001",
        "item-service": "http://localhost:3003",
        "list-service": "http://localhost:3002",
      };

      for (const [serviceName, fallbackUrl] of Object.entries(serviceUrls)) {
        try {
          const serviceUrl = serviceUrls[serviceName];
          const response = await axios.get(`${serviceUrl}/health`, {
            timeout: 3000,
          });

          healthResults[serviceName] = {
            status: "healthy",
            data: response.data,
            source: "direct",
          };

          // Reset circuit breaker on success
          if (this.circuitBreakers[serviceName]) {
            this.circuitBreakers[serviceName].failures = 0;
            this.circuitBreakers[serviceName].state = "CLOSED";
          }
        } catch (error) {
          healthResults[serviceName] = {
            status: "unhealthy",
            error: error.message,
            source: "direct",
          };

          // Update circuit breaker on failure
          if (this.circuitBreakers[serviceName]) {
            this.circuitBreakers[serviceName].failures++;
            this.circuitBreakers[serviceName].lastFailure = Date.now();

            if (this.circuitBreakers[serviceName].failures >= 3) {
              this.circuitBreakers[serviceName].state = "OPEN";
              console.warn(`Circuit breaker OPEN for ${serviceName}`);
            }
          }
        }
      }

      res.json({
        gateway: {
          service: this.serviceName,
          status: "healthy",
          timestamp: new Date().toISOString(),
          uptime: process.uptime(),
        },
        services: healthResults,
        circuitBreakers: this.circuitBreakers,
        registryStatus: Object.keys(services).length > 0 ? "active" : "empty",
      });
    } catch (error) {
      res.status(503).json({
        service: this.serviceName,
        status: "unhealthy",
        error: error.message,
      });
    }
  }

  // Get service registry
  async getRegistry(req, res) {
    try {
      console.log("🔄 Buscando registry...");
      const services = await serviceRegistry.getAllServices();
      console.log("✅ Registry encontrado:", Object.keys(services));

      res.json({
        success: true,
        data: services,
        count: Object.keys(services).length,
      });
    } catch (error) {
      console.error("❌ Erro ao buscar registry:", error.message);
      res.status(500).json({
        success: false,
        message: "Erro ao acessar service registry",
        error: error.message,
      });
    }
  }

  // Proxy requests to services
  proxyToService(serviceName) {
    return async (req, res) => {
      console.log("=== DEBUG PROXY ===");
      console.log("Service Name:", serviceName);
      console.log("Original URL:", req.originalUrl);
      console.log("Method:", req.method);
      console.log("==================");

      // Check circuit breaker
      if (this.circuitBreakers[serviceName]?.state === "OPEN") {
        const timeSinceLastFailure =
          Date.now() - this.circuitBreakers[serviceName].lastFailure;
        if (timeSinceLastFailure > 30000) {
          this.circuitBreakers[serviceName].state = "HALF-OPEN";
        } else {
          return res.status(503).json({
            success: false,
            message: `Serviço ${serviceName} temporariamente indisponível`,
            circuitBreaker: "OPEN",
          });
        }
      }

      try {
        const serviceUrl = this.getServiceUrl(serviceName);

        // ✅ CORREÇÃO: Add debug logs AFTER serviceUrl is defined
        console.log(
          `🔄 [GATEWAY] Proxying ${req.method} ${req.originalUrl} to ${serviceName}`
        );
        console.log(`🔗 Target service URL: ${serviceUrl}`);

        if (!serviceUrl) {
          return res.status(503).json({
            success: false,
            message: `Serviço ${serviceName} não encontrado`,
          });
        }

        // Construir a URL correta
        let targetPath = req.originalUrl;

        // Mapeamento correto dos prefixos
        if (
          serviceName === "user-service" &&
          targetPath.startsWith("/api/auth")
        ) {
          targetPath = targetPath.replace("/api/auth", "/auth");
        } else if (
          serviceName === "user-service" &&
          targetPath.startsWith("/api/users")
        ) {
          targetPath = targetPath.replace("/api/users", "/users");
        } else if (
          serviceName === "item-service" &&
          targetPath.startsWith("/api/items")
        ) {
          targetPath = targetPath.replace("/api/items", "");
        } else if (
          serviceName === "list-service" &&
          targetPath.startsWith("/api/lists")
        ) {
          targetPath = targetPath.replace("/api/lists", "");
        }

        const targetUrl = `${serviceUrl}${targetPath}`;
        console.log(`🎯 Final target URL: ${targetUrl}`);

        const response = await axios({
          method: req.method,
          url: targetUrl,
          data: req.body,
          headers: {
            "Content-Type": "application/json",
            Authorization: req.headers.authorization || "",
          },
          timeout: 10000,
        });

        // Reset circuit breaker on success
        if (this.circuitBreakers[serviceName]?.state === "HALF-OPEN") {
          this.circuitBreakers[serviceName].state = "CLOSED";
          this.circuitBreakers[serviceName].failures = 0;
        }

        res.status(response.status).json(response.data);
      } catch (error) {
        console.error(`Proxy error for ${serviceName}:`, error.message);

        // Update circuit breaker
        if (this.circuitBreakers[serviceName]) {
          this.circuitBreakers[serviceName].failures++;
          this.circuitBreakers[serviceName].lastFailure = Date.now();
          if (this.circuitBreakers[serviceName].failures >= 3) {
            this.circuitBreakers[serviceName].state = "OPEN";
          }
        }

        if (error.response) {
          res.status(error.response.status).json(error.response.data);
        } else {
          res.status(503).json({
            success: false,
            message: `Serviço ${serviceName} indisponível`,
            error: error.message,
          });
        }
      }
    };
  }

  // Dashboard endpoint (aggregates data from multiple services)
  async getDashboard(req, res) {
    try {
      const authHeader = req.header("Authorization");
      if (!authHeader?.startsWith("Bearer ")) {
        return res
          .status(401)
          .json({ success: false, message: "Token obrigatório" });
      }

      const token = authHeader.replace("Bearer ", "");

      // Validar token com URL direta
      const userServiceUrl = "http://localhost:3001";
      const userResponse = await axios.post(
        `${userServiceUrl}/auth/validate`,
        { token },
        { timeout: 5000, headers: { "Content-Type": "application/json" } }
      );

      if (!userResponse.data.success) {
        return res
          .status(401)
          .json({ success: false, message: "Token inválido" });
      }

      const user = userResponse.data.data.user;

      // Buscar listas do usuário
      const listServiceUrl = "http://localhost:3002";
      const listsResponse = await axios.get(`${listServiceUrl}/`, {
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
        },
        timeout: 5000,
      });

      const lists = listsResponse.data.success ? listsResponse.data.data : [];

      // Buscar contagem de itens ativos
      const itemServiceUrl = "http://localhost:3003";
      const itemsResponse = await axios.get(
        `${itemServiceUrl}/?active=true&limit=1`,
        {
          timeout: 5000,
        }
      );

      const totalItems = itemsResponse.data.success
        ? itemsResponse.data.pagination.total
        : 0;

      // Calcular estatísticas do dashboard
      const activeLists = lists.filter(
        (list) => list.status === "active"
      ).length;
      const completedLists = lists.filter(
        (list) => list.status === "completed"
      ).length;
      const totalEstimated = lists.reduce(
        (sum, list) => sum + list.summary.estimatedTotal,
        0
      );

      res.json({
        success: true,
        data: {
          user: {
            id: user.id,
            username: user.username,
            firstName: user.firstName,
            lastName: user.lastName,
            preferences: user.preferences,
          },
          statistics: {
            totalLists: lists.length,
            activeLists,
            completedLists,
            totalItems,
            totalEstimated: parseFloat(totalEstimated.toFixed(2)),
          },
          recentLists: lists.slice(0, 5).map((list) => ({
            id: list.id,
            name: list.name,
            status: list.status,
            itemCount: list.summary.totalItems,
            purchasedCount: list.summary.purchasedItems,
            estimatedTotal: list.summary.estimatedTotal,
            updatedAt: list.updatedAt,
          })),
        },
      });
    } catch (error) {
      console.error("Dashboard error:", error.message);
      res.status(500).json({
        success: false,
        message: "Erro ao carregar dashboard",
        error: error.message,
      });
    }
  }

  // Global search across services
  async globalSearch(req, res) {
    try {
      const { q } = req.query;

      if (!q) {
        return res.status(400).json({
          success: false,
          message: "Parâmetro de busca (q) é obrigatório",
        });
      }

      const results = {};

      // Search items - ✅ CORRIGIDO: Usar URL direta
      try {
        const itemServiceUrl = "http://localhost:3003";
        const response = await axios.get(
          `${itemServiceUrl}/search?q=${encodeURIComponent(q)}&limit=10`,
          { timeout: 5000 }
        );

        if (response.data.success) {
          results.items = response.data.data;
        }
      } catch (error) {
        console.error("Item search error:", error.message);
        results.itemsError = error.message;
      }

      // If authenticated, search lists too
      const authHeader = req.header("Authorization");
      if (authHeader?.startsWith("Bearer ")) {
        try {
          const token = authHeader.replace("Bearer ", "");
          const listService = serviceRegistry.discover("list-service");

          // Get all user's lists and filter by name
          const response = await axios.get(`${listService.url}/lists`, {
            headers: { Authorization: `Bearer ${token}` },
            timeout: 5000,
          });

          if (response.data.success) {
            const lists = response.data.data;
            results.lists = lists
              .filter((list) =>
                list.name.toLowerCase().includes(q.toLowerCase())
              )
              .slice(0, 5);
          }
        } catch (error) {
          console.error("List search error:", error.message);
          results.listsError = error.message;
        }
      }

      res.json({
        success: true,
        data: results,
        search: {
          query: q,
          timestamp: new Date().toISOString(),
        },
      });
    } catch (error) {
      console.error("Global search error:", error);
      res.status(500).json({
        success: false,
        message: "Erro na busca global",
        error: error.message,
      });
    }
  }

  // Start periodic health checks
  startHealthChecks() {
    setInterval(async () => {
      try {
        const serviceUrls = {
          "user-service": "http://localhost:3001",
          "item-service": "http://localhost:3003",
          "list-service": "http://localhost:3002",
        };

        const healthResults = {};

        // Testar cada serviço diretamente
        for (const [serviceName, serviceUrl] of Object.entries(serviceUrls)) {
          try {
            const response = await axios.get(`${serviceUrl}/health`, {
              timeout: 3000,
            });
            healthResults[serviceName] = {
              status: "healthy",
              data: response.data,
            };
          } catch (error) {
            healthResults[serviceName] = {
              status: "unhealthy",
              error: error.message,
            };
          }
        }
      } catch (error) {
        console.error("Health check interval error:", error);
      }
    }, 30000); // Check every 30 seconds
  }

  start() {
    this.app.listen(this.port, () => {
      console.log("=====================================");
      console.log(`API Gateway iniciado na porta ${this.port}`);
      console.log(`URL: ${this.serviceUrl}`);
      console.log(`Health: ${this.serviceUrl}/health`);
      console.log(`Registry: ${this.serviceUrl}/registry`);
      console.log("=====================================");
    });
  }
}

// Start gateway
if (require.main === module) {
  const apiGateway = new ApiGateway();
  apiGateway.start();
}

module.exports = ApiGateway;
