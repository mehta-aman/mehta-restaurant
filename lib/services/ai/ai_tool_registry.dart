import '../../models/models.dart';
import 'ai_models.dart';

class AiToolRegistry {
  static final Map<String, AiToolDefinition> _registry = {};

  static bool _initialized = false;

  static void initialize() {
    if (_initialized) return;

    // ==========================================
    // 1. READ-ONLY TOOLS
    // ==========================================

    _register(
      AiToolDefinition(
        name: 'search_menu',
        description: 'Searches the restaurant menu items by name, category, or vegetarian flag.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.low,
        allowedRoles: StaffRole.values.toSet(), // All staff
        parameterSchema: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Search query to match against dish names or description',
            },
            'category': {
              'type': 'string',
              'description': 'Optional category filter (e.g. Starters, Main Course, Breads, Beverages, Desserts)',
            },
            'is_veg': {
              'type': 'boolean',
              'description': 'Filter by vegetarian dishes',
            },
            'available_only': {
              'type': 'boolean',
              'description': 'Whether to return only currently available dishes',
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'list_categories',
        description: 'Lists all available menu categories in Mehta Restaurant.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.low,
        allowedRoles: StaffRole.values.toSet(),
        parameterSchema: {
          'type': 'object',
          'properties': {},
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'search_customers',
        description: 'Searches customer directory by name or phone number.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.low,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier},
        parameterSchema: {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'Name or partial name of the customer',
            },
            'phone': {
              'type': 'string',
              'description': 'Phone number digits to match',
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'get_table_status',
        description: 'Retrieves current dining floor occupancy, table states, guest counts, and active order IDs.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.low,
        allowedRoles: StaffRole.values.toSet(),
        parameterSchema: {
          'type': 'object',
          'properties': {
            'table_number': {
              'type': 'string',
              'description': 'Optional specific table (e.g. T01, T02, T03)',
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'get_active_orders',
        description: 'Retrieves active in-flight dining orders and parcel orders.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.low,
        allowedRoles: StaffRole.values.toSet(),
        parameterSchema: {
          'type': 'object',
          'properties': {
            'table_number': {
              'type': 'string',
              'description': 'Optional specific table or parcel number',
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'get_kitchen_tickets',
        description: 'Retrieves active Kitchen Order Tickets (KOT) with item preparation states and rush indicators.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.low,
        allowedRoles: StaffRole.values.toSet(),
        parameterSchema: {
          'type': 'object',
          'properties': {
            'status': {
              'type': 'string',
              'enum': ['newTicket', 'preparing', 'ready', 'served'],
              'description': 'Optional status filter',
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'get_invoice_summary',
        description: 'Retrieves summary of issued bills and invoices with payment breakdown.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.medium,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier},
        parameterSchema: {
          'type': 'object',
          'properties': {
            'invoice_number': {
              'type': 'string',
              'description': 'Specific invoice number (e.g. MR-001001)',
            },
            'limit': {
              'type': 'integer',
              'description': 'Number of recent invoices to return (default 10)',
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'get_sales_report',
        description: 'Calculates authoritative restaurant sales analytics (gross sales, cash/UPI collected, credit given).',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.medium,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier},
        parameterSchema: {
          'type': 'object',
          'properties': {
            'period': {
              'type': 'string',
              'enum': ['today', 'yesterday', 'this_week', 'all_time'],
              'description': 'Time period for the sales report',
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'get_customer_balances',
        description: 'Retrieves outstanding customer Khata (credit) balances and settlement history.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.medium,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier},
        parameterSchema: {
          'type': 'object',
          'properties': {
            'customer_id': {
              'type': 'string',
              'description': 'Optional specific customer ID',
            },
            'customer_name': {
              'type': 'string',
              'description': 'Optional customer name search',
            },
            'min_balance': {
              'type': 'number',
              'description': 'Filter customers with pending credit balance greater than or equal to this amount',
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'get_restaurant_settings',
        description: 'Retrieves non-sensitive restaurant settings such as restaurant name, tagline, address, phone, and print configurations.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.low,
        allowedRoles: StaffRole.values.toSet(),
        parameterSchema: {
          'type': 'object',
          'properties': {},
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'get_item_sales_performance',
        description: 'Analyzes most ordered and highest revenue generating menu items.',
        category: AiToolCategory.readOnly,
        riskLevel: AiRiskLevel.low,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier},
        parameterSchema: {
          'type': 'object',
          'properties': {
            'limit': {
              'type': 'integer',
              'description': 'Top N dishes to return (default 5)',
            },
          },
        },
      ),
    );

    // ==========================================
    // 2. ACTION PREPARATION TOOLS (Requires Preview & Confirmation)
    // ==========================================

    _register(
      AiToolDefinition(
        name: 'prepare_menu_item_create',
        description: 'Prepares adding a new menu item to the restaurant catalog. Generates a preview for user confirmation.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.medium,
        allowedRoles: {StaffRole.owner, StaffRole.manager},
        parameterSchema: {
          'type': 'object',
          'required': ['name', 'category', 'price'],
          'properties': {
            'name': {'type': 'string', 'description': 'Dish name (e.g. Paneer Butter Masala)'},
            'category': {'type': 'string', 'description': 'Category (e.g. Main Course, Starters, Breads)'},
            'price': {'type': 'number', 'minimum': 0.0, 'description': 'Selling price in INR'},
            'is_veg': {'type': 'boolean', 'default': true, 'description': 'Whether the dish is vegetarian'},
            'is_packaged': {'type': 'boolean', 'default': false, 'description': 'Whether it is a packaged good with inventory'},
            'stock_quantity': {'type': 'integer', 'default': 0, 'description': 'Initial stock quantity if packaged'},
            'sku': {'type': 'string', 'description': 'Optional unique SKU code'},
            'description': {'type': 'string', 'description': 'Optional dish description'},
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_menu_item_update',
        description: 'Prepares updating an existing dish price, stock, or availability. Generates a preview showing old vs new values.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.high,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.kitchen},
        parameterSchema: {
          'type': 'object',
          'required': ['name_or_id'],
          'properties': {
            'name_or_id': {'type': 'string', 'description': 'Dish name or unique ID to update'},
            'new_price': {'type': 'number', 'minimum': 0.0, 'description': 'New price in INR'},
            'is_available': {'type': 'boolean', 'description': 'Toggle availability (in stock vs out of stock)'},
            'new_category': {'type': 'string', 'description': 'Change category'},
            'stock_quantity': {'type': 'integer', 'description': 'Update stock count'},
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_bulk_menu_import',
        description: 'Validates and prepares a batch or CSV import of multiple menu items with row-by-row validation.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.critical,
        allowedRoles: {StaffRole.owner, StaffRole.manager},
        parameterSchema: {
          'type': 'object',
          'required': ['raw_content'],
          'properties': {
            'raw_content': {
              'type': 'string',
              'description': 'Multi-line text or CSV formatted menu data (Name, Category, Price, Veg/Non-Veg)',
            },
            'mode': {
              'type': 'string',
              'enum': ['create_only', 'upsert'],
              'default': 'upsert',
              'description': 'Import mode: create_only rejects existing names; upsert updates existing prices',
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_customer_create',
        description: 'Prepares creating a new customer record with name and phone number for Khata ledger tracking.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.medium,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier},
        parameterSchema: {
          'type': 'object',
          'required': ['name', 'phone'],
          'properties': {
            'name': {'type': 'string', 'description': 'Customer full name'},
            'phone': {'type': 'string', 'description': '10-digit mobile number'},
            'notes': {'type': 'string', 'description': 'Optional customer notes or address'},
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_customer_balance_entry',
        description: 'Prepares recording an opening balance or manual debit adjustment for a customer Khata.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.high,
        allowedRoles: {StaffRole.owner, StaffRole.manager},
        parameterSchema: {
          'type': 'object',
          'required': ['customer_name_or_id', 'amount'],
          'properties': {
            'customer_name_or_id': {'type': 'string', 'description': 'Customer identifier or name'},
            'amount': {'type': 'number', 'minimum': 1.0, 'description': 'Debit amount in INR'},
            'description': {'type': 'string', 'default': 'Opening Balance', 'description': 'Reason / description'},
            'reference_number': {'type': 'string', 'description': 'Optional reference code'},
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_table_status_change',
        description: 'Prepares occupying, seating guests, vacating, or cleaning a dining table.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.low,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier, StaffRole.waiter},
        parameterSchema: {
          'type': 'object',
          'required': ['table_number', 'action'],
          'properties': {
            'table_number': {'type': 'string', 'description': 'Table code (e.g. T01, T02)'},
            'action': {
              'type': 'string',
              'enum': ['occupy', 'vacate', 'clean'],
              'description': 'Target state change',
            },
            'guests': {'type': 'integer', 'minimum': 1, 'description': 'Number of guests if occupying'},
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_order_change',
        description: 'Prepares adding or removing menu items from a table or parcel order with live subtotal calculation.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.low,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier, StaffRole.waiter},
        parameterSchema: {
          'type': 'object',
          'required': ['table_number'],
          'properties': {
            'table_number': {'type': 'string', 'description': 'Target table or parcel code'},
            'items_to_add': {
              'type': 'array',
              'items': {
                'type': 'object',
                'required': ['name', 'quantity'],
                'properties': {
                  'name': {'type': 'string'},
                  'quantity': {'type': 'integer', 'minimum': 1},
                  'notes': {'type': 'string'},
                },
              },
            },
            'items_to_remove': {
              'type': 'array',
              'items': {
                'type': 'object',
                'required': ['name'],
                'properties': {
                  'name': {'type': 'string'},
                  'quantity': {'type': 'integer', 'minimum': 1},
                },
              },
            },
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_payment',
        description: 'Prepares recording a Khata repayment settlement with amount, payment mode (cash/upi), and remaining balance calculation.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.high,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier},
        parameterSchema: {
          'type': 'object',
          'required': ['customer_name_or_id', 'amount'],
          'properties': {
            'customer_name_or_id': {'type': 'string', 'description': 'Customer name or ID'},
            'amount': {'type': 'number', 'minimum': 1.0, 'description': 'Payment amount in INR'},
            'payment_mode': {
              'type': 'string',
              'enum': ['cash', 'upi'],
              'default': 'cash',
              'description': 'Payment method received',
            },
            'reference_number': {'type': 'string', 'description': 'Optional UPI transaction reference or receipt number'},
            'note': {'type': 'string', 'description': 'Optional payment note'},
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_invoice',
        description: 'Prepares billing and finalizing an invoice for a table with cash, UPI, or Khata credit split.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.critical,
        allowedRoles: {StaffRole.owner, StaffRole.manager, StaffRole.cashier},
        parameterSchema: {
          'type': 'object',
          'required': ['table_number'],
          'properties': {
            'table_number': {'type': 'string', 'description': 'Table to bill'},
            'cash_paid': {'type': 'number', 'default': 0.0, 'description': 'Cash tender amount'},
            'upi_paid': {'type': 'number', 'default': 0.0, 'description': 'UPI tender amount'},
            'credit_amount': {'type': 'number', 'default': 0.0, 'description': 'Khata credit amount'},
            'customer_name': {'type': 'string', 'description': 'Customer name (required if credit > 0)'},
            'customer_phone': {'type': 'string', 'description': 'Customer phone (required if credit > 0)'},
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_invoice_void',
        description: 'Prepares voiding an existing finalized invoice with mandatory reason and Khata reversal.',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.critical,
        allowedRoles: {StaffRole.owner, StaffRole.manager},
        parameterSchema: {
          'type': 'object',
          'required': ['invoice_number', 'reason'],
          'properties': {
            'invoice_number': {'type': 'string', 'description': 'Invoice number to void (e.g. MR-001001)'},
            'reason': {'type': 'string', 'description': 'Audit reason for voiding this invoice'},
          },
        },
      ),
    );

    _register(
      AiToolDefinition(
        name: 'prepare_settings_update',
        description: 'Prepares updating restaurant profile settings (tagline, address, phone, receipt notes).',
        category: AiToolCategory.actionPreparation,
        riskLevel: AiRiskLevel.high,
        allowedRoles: {StaffRole.owner, StaffRole.manager},
        parameterSchema: {
          'type': 'object',
          'properties': {
            'restaurant_name': {'type': 'string'},
            'tagline': {'type': 'string'},
            'address': {'type': 'string'},
            'phone': {'type': 'string'},
            'receipt_footer_note': {'type': 'string'},
          },
        },
      ),
    );

    // ==========================================
    // 3. ACTION EXECUTION TOOLS
    // ==========================================

    _register(
      AiToolDefinition(
        name: 'execute_confirmed_action',
        description: 'Executes a previously prepared and validated action using its signed confirmation token.',
        category: AiToolCategory.actionExecution,
        riskLevel: AiRiskLevel.high,
        allowedRoles: StaffRole.values.toSet(),
        parameterSchema: {
          'type': 'object',
          'required': ['confirmation_token'],
          'properties': {
            'confirmation_token': {
              'type': 'string',
              'description': 'The valid, non-expired confirmation token issued during preparation',
            },
          },
        },
      ),
    );

    _initialized = true;
  }

  static void _register(AiToolDefinition tool) {
    _registry[tool.name] = tool;
  }

  /// Retrieves a tool definition by name
  static AiToolDefinition? getTool(String name) {
    initialize();
    return _registry[name];
  }

  /// Returns all registered tools
  static List<AiToolDefinition> get allTools {
    initialize();
    return _registry.values.toList();
  }

  /// Returns tools filtered by permitted role
  static List<AiToolDefinition> toolsForRole(StaffRole role) {
    initialize();
    return _registry.values.where((t) => t.isAuthorizedFor(role)).toList();
  }

  /// Generates tool calling JSON Schema array for OpenAI / Gemini function declarations
  static List<Map<String, dynamic>> exportToolSchemasForRole(StaffRole role) {
    return toolsForRole(role).map((t) => {
      'name': t.name,
      'description': t.description,
      'parameters': t.parameterSchema,
    }).toList();
  }
}
