const axios = require("axios");

class ShoppingListDemo {
  constructor() {
    this.baseUrl = "http://localhost:3000";
    this.token = null;
    this.user = null;
  }

  async delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  async testHealth() {
    console.log("=== Testando Health Check ===");
    try {
      const response = await axios.get(`${this.baseUrl}/health`);
      console.log("Health Check:", response.data);
      return true;
    } catch (error) {
      console.error("Health Check falhou:", error.message);
      return false;
    }
  }

  async testRegistry() {
    console.log("\n=== Testando Service Registry ===");
    try {
      const response = await axios.get(`${this.baseUrl}/registry`);
      console.log("Service Registry:", response.data);
      return true;
    } catch (error) {
      console.error("Service Registry falhou:", error.message);
      return false;
    }
  }

  async registerUser() {
    console.log("\n=== Registrando Novo Usuário ===");
    try {
      const userData = {
        email: `usuario${Math.floor(Math.random() * 1000)}@exemplo.com`,
        username: `user${Math.floor(Math.random() * 1000)}`,
        password: "senha123",
        firstName: "João",
        lastName: "Silva",
        preferences: {
          defaultStore: "Mercado Central",
          currency: "BRL",
        },
      };

      const response = await axios.post(
        `${this.baseUrl}/api/auth/register`,
        userData
      );
      console.log("Usuário registrado:", response.data);

      this.token = response.data.data.token;
      this.user = response.data.data.user;

      return true;
    } catch (error) {
      console.error("Registro falhou:", error.response?.data || error.message);
      return false;
    }
  }

  async loginUser() {
    console.log("\n=== Fazendo Login ===");
    try {
      // Primeiro tenta fazer login com o admin
      const loginData = {
        identifier: "admin@shopping.com",
        password: "admin123",
      };

      const response = await axios.post(
        `${this.baseUrl}/api/auth/login`,
        loginData
      );
      console.log("Login realizado:", response.data);

      this.token = response.data.data.token;
      this.user = response.data.data.user;

      return true;
    } catch (error) {
      console.error("Login falhou:", error.response?.data || error.message);
      return false;
    }
  }

  async browseItems() {
    try {
      console.log("\n=== Navegando pelos Itens ===");

      // Listar categorias
      const categoriesResponse = await axios.get(
        `${this.baseUrl}/api/items/categories`
      );
      console.log("Categorias disponíveis:", categoriesResponse.data.data);

      // ✅ CORRIGIDO: Buscar itens ativos
      const itemsResponse = await axios.get(
        `${this.baseUrl}/api/items?active=true&limit=5`
      );
      const items = itemsResponse.data.data; // ✅ Agora está correto!
      console.log(`Itens encontrados: ${items.length}`);

      // Buscar um item específico
      if (items.length > 0) {
        const itemId = items[0].id;
        const itemResponse = await axios.get(
          `${this.baseUrl}/api/items/${itemId}`
        );
        console.log("Detalhes do primeiro item:", itemResponse.data.data.name);
      }

      return true;
    } catch (error) {
      console.error(
        "Navegação de itens falhou:",
        error.response?.data || error.message
      );
      return false;
    }
  }

  async addItemsToList() {
    try {
      console.log("\n=== Adicionando Itens à Lista ===");

      // ✅ CORRIGIDO: Buscar itens ativos
      const itemsResponse = await axios.get(
        `${this.baseUrl}/api/items?active=true&limit=3`
      );
      const items = itemsResponse.data.data; // ✅ Agora está correto!

      // Adiciona cada item à lista
      for (const item of items) {
        const addItemData = {
          itemId: item.id,
          quantity: Math.floor(Math.random() * 3) + 1,
          notes: `Notas para ${item.name}`,
        };

        await axios.post(
          `${this.baseUrl}/api/lists/${this.listId}/items`,
          addItemData,
          {
            headers: { Authorization: `Bearer ${this.token}` },
          }
        );

        console.log(`Item adicionado: ${item.name}`);
      }

      return true;
    } catch (error) {
      console.error(
        "Adição de itens falhou:",
        error.response?.data || error.message
      );
      return false;
    }
  }

  async searchItems() {
    console.log("\n=== Buscando Itens ===");
    try {
      const searchResponse = await axios.get(
        `${this.baseUrl}/api/items/search?q=arroz`
      );
      console.log(
        'Resultados da busca por "arroz":',
        searchResponse.data.data.length
      );

      return true;
    } catch (error) {
      console.error("Busca falhou:", error.response?.data || error.message);
      return false;
    }
  }

  async createList() {
    console.log("\n=== Criando Lista de Compras ===");
    try {
      const listData = {
        name: "Minha Lista de Compras",
        description: "Lista de compras da semana",
      };

      const response = await axios.post(`${this.baseUrl}/api/lists`, listData, {
        headers: { Authorization: `Bearer ${this.token}` },
      });

      this.listId = response.data.data.id;
      console.log("Lista criada:", response.data.data.name);

      return true;
    } catch (error) {
      console.error(
        "Criação de lista falhou:",
        error.response?.data || error.message
      );
      return false;
    }
  }

  async addItemsToList() {
    console.log("\n=== Adicionando Itens à Lista ===");
    try {
      // Primeiro busca alguns itens
      const itemsResponse = await axios.get(
        `${this.baseUrl}/api/items?limit=3`
      );
      const items = itemsResponse.data.data;

      // Adiciona cada item à lista
      for (const item of items) {
        const addItemData = {
          itemId: item.id,
          quantity: Math.floor(Math.random() * 3) + 1,
          notes: `Notas para ${item.name}`,
        };

        await axios.post(
          `${this.baseUrl}/api/lists/${this.listId}/items`,
          addItemData,
          {
            headers: { Authorization: `Bearer ${this.token}` },
          }
        );

        console.log(`Item adicionado: ${item.name}`);
      }

      return true;
    } catch (error) {
      console.error(
        "Adição de itens falhou:",
        error.response?.data || error.message
      );
      return false;
    }
  }

  async viewList() {
    console.log("\n=== Visualizando Lista ===");
    try {
      const response = await axios.get(
        `${this.baseUrl}/api/lists/${this.listId}`,
        {
          headers: { Authorization: `Bearer ${this.token}` },
        }
      );

      console.log("Lista detalhada:");
      console.log(`- Nome: ${response.data.data.name}`);
      console.log(`- Itens: ${response.data.data.items.length}`);
      console.log(
        `- Total estimado: R$ ${response.data.data.summary.estimatedTotal}`
      );

      return true;
    } catch (error) {
      console.error(
        "Visualização de lista falhou:",
        error.response?.data || error.message
      );
      return false;
    }
  }

  async testCheckout(listId) {
    try {
      console.log(`\n🛒 Testando checkout da lista ${listId}...`);

      const response = await this.api.post(`/api/lists/${listId}/checkout`);

      if (response.data.success) {
        console.log("✅ Checkout iniciado com sucesso!");
        console.log("📤 Mensagem publicada no RabbitMQ");
        console.log("⏳ Processamento assíncrono em andamento...");
      }

      return response.data;
    } catch (error) {
      console.log(
        "❌ Erro no checkout:",
        error.response?.data?.message || error.message
      );
      throw error;
    }
  }

  async testDashboard() {
    console.log("\n=== Testando Dashboard ===");
    try {
      const response = await axios.get(`${this.baseUrl}/api/dashboard`, {
        headers: { Authorization: `Bearer ${this.token}` },
      });

      console.log("Dashboard:");
      console.log(
        `- Usuário: ${response.data.data.user.firstName} ${response.data.data.user.lastName}`
      );
      console.log(
        `- Total de listas: ${response.data.data.statistics.totalLists}`
      );
      console.log(
        `- Listas ativas: ${response.data.data.statistics.activeLists}`
      );
      console.log(
        `- Total estimado: R$ ${response.data.data.statistics.totalEstimated}`
      );

      return true;
    } catch (error) {
      console.error("Dashboard falhou:", error.response?.data || error.message);
      return false;
    }
  }

  async testGlobalSearch() {
    console.log("\n=== Testando Busca Global ===");
    try {
      const response = await axios.get(`${this.baseUrl}/api/search?q=arroz`, {
        headers: { Authorization: `Bearer ${this.token}` },
      });

      console.log('Busca global por "arroz":');
      console.log(
        `- Itens encontrados: ${response.data.data.items?.length || 0}`
      );

      if (response.data.data.lists) {
        console.log(`- Listas encontradas: ${response.data.data.lists.length}`);
      }

      return true;
    } catch (error) {
      console.error(
        "Busca global falhou:",
        error.response?.data || error.message
      );
      return false;
    }
  }

  async runAllTests() {
    console.log("Iniciando demonstração do Sistema de Listas de Compras...\n");

    // Aguarda os serviços iniciarem
    console.log("Aguardando inicialização dos serviços...");
    await this.delay(3000);

    // Executa os testes em sequência
    const tests = [
      this.testHealth.bind(this),
      this.testRegistry.bind(this),
      this.loginUser.bind(this),
      this.browseItems.bind(this),
      this.searchItems.bind(this),
      this.createList.bind(this),
      this.addItemsToList.bind(this),
      this.viewList.bind(this),
      this.testDashboard.bind(this),
      this.testGlobalSearch.bind(this),
    ];

    for (const test of tests) {
      const success = await test();
      if (!success) {
        console.log("Teste falhou, continuando com próximo...");
      }
      await this.delay(1000);
    }

    console.log("\n=== Demonstração Concluída ===");
    console.log("Para testar manualmente:");
    console.log(`- Health Check: curl http://localhost:3000/health`);
    console.log(`- Service Registry: curl http://localhost:3000/registry`);
    console.log(`- API Gateway: curl http://localhost:3000/`);
  }
}

// Executa a demonstração
const demo = new ShoppingListDemo();
demo.runAllTests().catch(console.error);
