const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const path = require("path");

// Importar banco NoSQL e service registry
const JsonDatabase = require("../../shared/JsonDatabase");
const serviceRegistry = require("../../shared/serviceRegistry");

class UserService {
  constructor() {
    this.app = express();
    this.port = process.env.PORT || 3001;
    this.serviceName = "user-service";
    this.serviceUrl = `http://localhost:${this.port}`;

    this.setupDatabase();
    this.setupMiddleware();
    this.setupRoutes();
    this.setupErrorHandling();
    this.seedInitialData();
    this.registerWithRegistry();
    this.startHealthReporting();
  }

  setupDatabase() {
    const dbPath = path.join(__dirname, "database");
    this.usersDb = new JsonDatabase(dbPath, "users");
    console.log("User Service: Banco NoSQL inicializado");
  }

  async seedInitialData() {
    // Aguardar inicialização e criar usuário admin se não existir
    setTimeout(async () => {
      try {
        const existingUsers = await this.usersDb.find();

        if (existingUsers.length === 0) {
          const adminPassword = await bcrypt.hash("admin123", 12);

          await this.usersDb.create({
            id: uuidv4(),
            email: "admin@shopping.com",
            username: "admin",
            password: adminPassword,
            firstName: "Administrador",
            lastName: "Sistema",
            preferences: {
              defaultStore: "Mercado Central",
              currency: "BRL",
            },
            role: "admin",
            status: "active",
          });

          console.log(
            "Usuário administrador criado (admin@shopping.com / admin123)"
          );
        }
      } catch (error) {
        console.error("Erro ao criar dados iniciais:", error);
      }
    }, 1000);
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
        const userCount = await this.usersDb.count();
        res.json({
          service: this.serviceName,
          status: "healthy",
          timestamp: new Date().toISOString(),
          uptime: process.uptime(),
          version: "1.0.0",
          database: {
            type: "JSON-NoSQL",
            userCount: userCount,
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

    // Service info
    this.app.get("/", (req, res) => {
      res.json({
        service: "User Service",
        version: "1.0.0",
        description: "Microsserviço para gerenciamento de usuários",
        database: "JSON-NoSQL",
        endpoints: [
          "POST /auth/register",
          "POST /auth/login",
          "POST /auth/validate",
          "GET /users/:id",
          "PUT /users/:id",
        ],
      });
    });

    // Auth routes
    this.app.post("/auth/register", this.register.bind(this));
    this.app.post("/auth/login", this.login.bind(this));
    this.app.post("/auth/validate", this.validateToken.bind(this));

    // User routes - CORRIGIDO: sem /api prefix
    this.app.get(
      "/users/:id",
      this.authMiddleware.bind(this),
      this.getUser.bind(this)
    );
    this.app.put(
      "/users/:id",
      this.authMiddleware.bind(this),
      this.updateUser.bind(this)
    );
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
      console.error("User Service Error:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do serviço",
        service: this.serviceName,
      });
    });
  }

  // Auth middleware
  async authMiddleware(req, res, next) {
    const authHeader = req.header("Authorization");

    if (!authHeader?.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Token obrigatório",
      });
    }

    try {
      const token = authHeader.replace("Bearer ", "");

      console.log("🔐 [USER-SERVICE] Validando token...");

      const decoded = jwt.verify(
        token,
        process.env.JWT_SECRET || "user-secret"
      );

      console.log("✅ [USER-SERVICE] Token válido para usuário:", decoded.id);

      req.user = decoded;
      next();
    } catch (error) {
      console.error(
        "❌ [USER-SERVICE] Erro na validação do token:",
        error.message
      );
      res.status(401).json({
        success: false,
        message: "Token inválido",
      });
    }
  }

  // Register user
  async register(req, res) {
    try {
      const { email, username, password, firstName, lastName, preferences } =
        req.body;

      // Validações básicas
      if (!email || !username || !password || !firstName || !lastName) {
        return res.status(400).json({
          success: false,
          message:
            "Email, username, password, firstName e lastName são obrigatórios",
        });
      }

      // Verificar se usuário já existe
      const existingEmail = await this.usersDb.findOne({
        email: email.toLowerCase(),
      });
      const existingUsername = await this.usersDb.findOne({
        username: username.toLowerCase(),
      });

      if (existingEmail) {
        return res.status(409).json({
          success: false,
          message: "Email já está em uso",
        });
      }

      if (existingUsername) {
        return res.status(409).json({
          success: false,
          message: "Username já está em uso",
        });
      }

      // Hash password
      const hashedPassword = await bcrypt.hash(password, 12);

      // Criar usuário
      const newUser = await this.usersDb.create({
        id: uuidv4(),
        email: email.toLowerCase(),
        username: username.toLowerCase(),
        password: hashedPassword,
        firstName,
        lastName,
        preferences: preferences || {
          defaultStore: "Mercado",
          currency: "BRL",
        },
        role: "user",
        status: "active",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });

      const { password: _, ...userWithoutPassword } = newUser;

      const token = jwt.sign(
        {
          id: newUser.id,
          email: newUser.email,
          username: newUser.username,
          role: newUser.role,
        },
        process.env.JWT_SECRET || "user-secret",
        { expiresIn: "24h" }
      );

      res.status(201).json({
        success: true,
        message: "Usuário criado com sucesso",
        data: { user: userWithoutPassword, token },
      });
    } catch (error) {
      console.error("Erro no registro:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Login user
  async login(req, res) {
    try {
      const { identifier, password } = req.body;

      if (!identifier || !password) {
        return res.status(400).json({
          success: false,
          message: "Identificador e senha obrigatórios",
        });
      }

      const user = await this.usersDb.findOne({
        $or: [
          { email: identifier.toLowerCase() },
          { username: identifier.toLowerCase() },
        ],
      });

      if (!user || !(await bcrypt.compare(password, user.password))) {
        return res.status(401).json({
          success: false,
          message: "Credenciais inválidas",
        });
      }

      // Verificar se usuário está ativo
      if (user.status !== "active") {
        return res.status(403).json({
          success: false,
          message: "Conta desativada",
        });
      }

      // Atualizar dados de login
      await this.usersDb.update(user.id, {
        updatedAt: new Date().toISOString(),
      });

      const { password: _, ...userWithoutPassword } = user;

      const token = jwt.sign(
        {
          id: user.id,
          email: user.email,
          username: user.username,
          role: user.role,
        },
        process.env.JWT_SECRET || "user-secret",
        { expiresIn: "24h" }
      );

      res.json({
        success: true,
        message: "Login realizado com sucesso",
        data: { user: userWithoutPassword, token },
      });
    } catch (error) {
      console.error("Erro no login:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Validate token
  async validateToken(req, res) {
    try {
      const { token } = req.body;

      if (!token) {
        return res.status(400).json({
          success: false,
          message: "Token obrigatório",
        });
      }

      const decoded = jwt.verify(
        token,
        process.env.JWT_SECRET || "user-secret"
      );
      const user = await this.usersDb.findById(decoded.id);

      if (!user || user.status !== "active") {
        return res.status(401).json({
          success: false,
          message: "Usuário não encontrado ou inativo",
        });
      }

      const { password: _, ...userWithoutPassword } = user;

      res.json({
        success: true,
        message: "Token válido",
        data: { user: userWithoutPassword },
      });
    } catch (error) {
      res.status(401).json({
        success: false,
        message: "Token inválido",
      });
    }
  }

  // Get user by ID
  async getUser(req, res) {
    try {
      const { id } = req.params;
      const user = await this.usersDb.findById(id);

      if (!user) {
        return res.status(404).json({
          success: false,
          message: "Usuário não encontrado",
        });
      }

      // Verificar permissão (usuário só vê próprio perfil ou admin vê tudo)
      if (req.user.id !== id && req.user.role !== "admin") {
        return res.status(403).json({
          success: false,
          message: "Acesso negado",
        });
      }

      const { password, ...userWithoutPassword } = user;

      res.json({
        success: true,
        data: userWithoutPassword,
      });
    } catch (error) {
      console.error("Erro ao buscar usuário:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Update user
  async updateUser(req, res) {
    try {
      const { id } = req.params;
      const { firstName, lastName, email, preferences } = req.body;

      // Verificar permissão
      if (req.user.id !== id && req.user.role !== "admin") {
        return res.status(403).json({
          success: false,
          message: "Acesso negado",
        });
      }

      const user = await this.usersDb.findById(id);
      if (!user) {
        return res.status(404).json({
          success: false,
          message: "Usuário não encontrado",
        });
      }

      // Updates
      const updates = {};
      if (firstName) updates.firstName = firstName;
      if (lastName) updates.lastName = lastName;
      if (email) updates.email = email.toLowerCase();
      if (preferences)
        updates.preferences = { ...user.preferences, ...preferences };

      updates.updatedAt = new Date().toISOString();

      const updatedUser = await this.usersDb.update(id, updates);
      const { password, ...userWithoutPassword } = updatedUser;

      res.json({
        success: true,
        message: "Usuário atualizado com sucesso",
        data: userWithoutPassword,
      });
    } catch (error) {
      console.error("Erro ao atualizar usuário:", error);
      res.status(500).json({
        success: false,
        message: "Erro interno do servidor",
      });
    }
  }

  // Register with service registry
  registerWithRegistry() {
    serviceRegistry.register(this.serviceName, {
      url: this.serviceUrl,
      version: "1.0.0",
      database: "JSON-NoSQL",
      endpoints: ["/health", "/auth/register", "/auth/login", "/users/:id"],
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
      console.log(`User Service iniciado na porta ${this.port}`);
      console.log(`URL: ${this.serviceUrl}`);
      console.log(`Health: ${this.serviceUrl}/health`);
      console.log(`Database: JSON-NoSQL`);
      console.log("=====================================");

      // Register with service registry
      setTimeout(() => {
        this.registerWithRegistry();
        this.startHealthReporting();
      }, 1000);
    });
  }
}

// Start service
if (require.main === module) {
  const userService = new UserService();
  userService.start();

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

module.exports = UserService;
