enum TableState { available, occupied, billing, cleaning }
enum KotState { newTicket, preparing, ready, served }
enum PaymentType { cash, upi, credit }
enum LedgerType { debit, credit } // debit: bill owes; credit: payment cleared

class RestaurantTable {
  final String id;
  final String tableNumber; // 'T01'..'T10', or custom 'G01', 'O01', etc.
  final String name; // Display name / label e.g. "VIP Window", "Family Table"
  final String section; // Section / Floor e.g. "Indoor AC", "Outdoor Lawn", "Rooftop Terrace"
  final int capacity;
  final TableState status;
  final String? activeOrderId;
  final int guestCount;
  final DateTime? openedAt;
  final bool isEnabled;
  final String? mergedInto; // Master tableNumber if this is a secondary merged table
  final List<String> mergedTables; // Secondary table numbers merged into this master table

  RestaurantTable({
    required this.id,
    required this.tableNumber,
    this.name = '',
    this.section = 'Indoor AC',
    this.capacity = 6,
    this.status = TableState.available,
    this.activeOrderId,
    this.guestCount = 0,
    this.openedAt,
    this.isEnabled = true,
    this.mergedInto,
    this.mergedTables = const [],
  });

  bool get isMergedSecondary => mergedInto != null;
  bool get isMergedMaster => mergedTables.isNotEmpty;
  int get totalCapacity => capacity + (mergedTables.length * 6);
  String get displayTableNumber => isMergedMaster ? '$tableNumber + ${mergedTables.join(" + ")}' : tableNumber;
  String get displayName => (name.trim().isNotEmpty && name.trim() != tableNumber) ? name.trim() : 'Table $tableNumber';
  String get fullLabel => (name.trim().isNotEmpty && name.trim() != tableNumber) ? '$tableNumber ($name)' : 'Table $tableNumber';

  RestaurantTable copyWith({
    String? id,
    String? tableNumber,
    String? name,
    String? section,
    int? capacity,
    TableState? status,
    String? activeOrderId,
    bool clearActiveOrderId = false,
    int? guestCount,
    DateTime? openedAt,
    bool clearOpenedAt = false,
    bool? isEnabled,
    String? mergedInto,
    List<String>? mergedTables,
    bool clearMergedInto = false,
  }) {
    return RestaurantTable(
      id: id ?? this.id,
      tableNumber: tableNumber ?? this.tableNumber,
      name: name ?? this.name,
      section: section ?? this.section,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      activeOrderId: clearActiveOrderId ? null : (activeOrderId ?? this.activeOrderId),
      guestCount: guestCount ?? this.guestCount,
      openedAt: clearOpenedAt ? null : (openedAt ?? this.openedAt),
      isEnabled: isEnabled ?? this.isEnabled,
      mergedInto: clearMergedInto ? null : (mergedInto ?? this.mergedInto),
      mergedTables: mergedTables ?? this.mergedTables,
    );
  }
}

class MenuItem {
  final String id;
  final String name;
  final String sku;
  final double price;
  final String category;
  final bool isPackaged;
  final bool isVeg;
  final bool isAvailable;
  final int stockQuantity; // -1 = Unlimited kitchen prep; >= 0 = physical inventory count
  final int lowStockThreshold; // Default 5
  final String? description;
  final String? imageUrl;

  MenuItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.category,
    this.isPackaged = false,
    this.isVeg = true,
    this.isAvailable = true,
    this.stockQuantity = -1,
    this.lowStockThreshold = 5,
    this.description,
    this.imageUrl,
  });

  bool get isStockTracked => isPackaged || stockQuantity >= 0;
  bool get isOutOfStock => isStockTracked && stockQuantity == 0;
  bool get isLowStock => isStockTracked && stockQuantity > 0 && stockQuantity <= lowStockThreshold;

  MenuItem copyWith({
    String? name,
    String? sku,
    double? price,
    String? category,
    bool? isPackaged,
    bool? isVeg,
    bool? isAvailable,
    int? stockQuantity,
    int? lowStockThreshold,
    String? description,
    String? imageUrl,
  }) {
    return MenuItem(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      category: category ?? this.category,
      isPackaged: isPackaged ?? this.isPackaged,
      isVeg: isVeg ?? this.isVeg,
      isAvailable: isAvailable ?? this.isAvailable,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

class OrderItem {
  final String id;
  final String menuItemId;
  final String name;
  final double unitPrice;
  int quantity;
  final String? notes;
  KotState kotStatus;

  OrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.unitPrice,
    this.quantity = 1,
    this.notes,
    this.kotStatus = KotState.newTicket,
  });

  double get totalPrice => unitPrice * quantity;

  OrderItem copyWith({int? quantity, KotState? kotStatus}) {
    return OrderItem(
      id: id,
      menuItemId: menuItemId,
      name: name,
      unitPrice: unitPrice,
      quantity: quantity ?? this.quantity,
      notes: notes,
      kotStatus: kotStatus ?? this.kotStatus,
    );
  }
}

class Order {
  final String id;
  final String orderNumber;
  final String tableNumber;
  final List<OrderItem> items;
  final double discount;
  final double packagingCharge;
  final bool isTakeaway;
  final double taxRate; // in %
  final String? customerName;
  final String? customerPhone;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.tableNumber,
    required this.items,
    this.discount = 0.0,
    this.packagingCharge = 0.0,
    this.isTakeaway = false,
    this.taxRate = 0.0,
    this.customerName,
    this.customerPhone,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get taxAmount => (subtotal + packagingCharge - discount) * (taxRate / 100.0);
  double get grandTotal => (subtotal + packagingCharge - discount) + (taxAmount > 0 ? taxAmount : 0);

  Order copyWith({
    List<OrderItem>? items,
    double? discount,
    double? packagingCharge,
    bool? isTakeaway,
    double? taxRate,
    String? customerName,
    String? customerPhone,
  }) {
    return Order(
      id: id,
      orderNumber: orderNumber,
      tableNumber: tableNumber,
      items: items ?? this.items,
      discount: discount ?? this.discount,
      packagingCharge: packagingCharge ?? this.packagingCharge,
      isTakeaway: isTakeaway ?? this.isTakeaway,
      taxRate: taxRate ?? this.taxRate,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      createdAt: createdAt,
    );
  }
}

class KitchenTicket {
  final String id;
  final String kotNumber;
  final String orderId;
  final String tableNumber;
  final List<OrderItem> items;
  KotState status;
  final DateTime timestamp;
  bool isRush;

  KitchenTicket({
    required this.id,
    required this.kotNumber,
    required this.orderId,
    required this.tableNumber,
    required this.items,
    this.status = KotState.newTicket,
    DateTime? timestamp,
    this.isRush = false,
  }) : timestamp = timestamp ?? DateTime.now();

  int get elapsedMinutes => DateTime.now().difference(timestamp).inMinutes;
  bool get isDelayed => status != KotState.served && elapsedMinutes >= 15;
  bool get isWarning => status != KotState.served && elapsedMinutes >= 10 && elapsedMinutes < 15;
}

class Customer {
  final String id;
  final String name;
  final String phone;
  final String? notes;

  Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.notes,
  });

  Customer copyWith({
    String? name,
    String? phone,
    String? notes,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
    );
  }
}

class LedgerEntry {
  final String id;
  final String customerId;
  final LedgerType type; // debit = owes more; credit = paid back
  final double amount;
  final String referenceType; // 'INVOICE', 'PAYMENT'
  final String referenceNumber;
  final String description;
  final DateTime date;

  LedgerEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.referenceType,
    required this.referenceNumber,
    required this.description,
    DateTime? date,
  }) : date = date ?? DateTime.now();

  LedgerEntry copyWith({
    LedgerType? type,
    double? amount,
    String? referenceType,
    String? referenceNumber,
    String? description,
    DateTime? date,
  }) {
    return LedgerEntry(
      id: id,
      customerId: customerId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      referenceType: referenceType ?? this.referenceType,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      description: description ?? this.description,
      date: date ?? this.date,
    );
  }
}

class PayerSplit {
  final String id;
  final String label; // 'Payer 1', 'Payer 2', etc.
  final double amount;
  String paymentMode; // 'UPI', 'Cash', 'Credit'
  bool isPaid;
  String? customerName;
  String? customerPhone;

  PayerSplit({
    required this.id,
    required this.label,
    required this.amount,
    this.paymentMode = 'UPI',
    this.isPaid = false,
    this.customerName,
    this.customerPhone,
  });

  PayerSplit copyWith({
    String? label,
    double? amount,
    String? paymentMode,
    bool? isPaid,
    String? customerName,
    String? customerPhone,
  }) {
    return PayerSplit(
      id: id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      isPaid: isPaid ?? this.isPaid,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
    );
  }
}

class Invoice {
  final String id;
  final String invoiceNumber;
  final String tableNumber;
  final String? customerName;
  final String? customerPhone;
  final List<OrderItem> items;
  final double subtotal;
  final double taxAmount;
  final double grandTotal;
  final double cashPaid;
  final double upiPaid;
  final double creditAmount;
  final DateTime issuedAt;
  final List<PayerSplit>? splits;
  final String? splitSummary;
  final bool isVoided;
  final String? voidReason;

  Invoice({
    required this.id,
    required this.invoiceNumber,
    required this.tableNumber,
    this.customerName,
    this.customerPhone,
    required this.items,
    required this.subtotal,
    required this.taxAmount,
    required this.grandTotal,
    required this.cashPaid,
    required this.upiPaid,
    required this.creditAmount,
    DateTime? issuedAt,
    this.splits,
    this.splitSummary,
    this.isVoided = false,
    this.voidReason,
  }) : issuedAt = issuedAt ?? DateTime.now();

  Invoice copyWith({
    bool? isVoided,
    String? voidReason,
  }) {
    return Invoice(
      id: id,
      invoiceNumber: invoiceNumber,
      tableNumber: tableNumber,
      customerName: customerName,
      customerPhone: customerPhone,
      items: items,
      subtotal: subtotal,
      taxAmount: taxAmount,
      grandTotal: grandTotal,
      cashPaid: cashPaid,
      upiPaid: upiPaid,
      creditAmount: creditAmount,
      issuedAt: issuedAt,
      splits: splits,
      splitSummary: splitSummary,
      isVoided: isVoided ?? this.isVoided,
      voidReason: voidReason ?? this.voidReason,
    );
  }

  double get totalPaid => cashPaid + upiPaid;
  double get balanceDue => creditAmount;
  bool get isSplitBill => splits != null && splits!.isNotEmpty;
}

class RestaurantSettings {
  final String id;
  final String restaurantName;
  final String tagline;
  final String address;
  final String phone;
  final String email;
  final bool gstEnabled;
  final String gstin;
  final double taxRate;
  final double serviceChargeRate;
  final String invoicePrefix;
  final int nextInvoiceNumber;
  final String upiId;
  final String upiPayeeName;
  final bool inventoryTrackingEnabled;
  final String receiptFooterNote;
  final int thermalPaperWidth; // 80 or 58 mm
  final bool autoPrintReceipt;

  RestaurantSettings({
    this.id = '',
    this.restaurantName = 'Mehta Restaurant',
    this.tagline = 'Pure Veg Restaurant & Sweets',
    this.address = 'Main Road, Station Road Market',
    this.phone = '+91 98290 12345',
    this.email = '',
    this.gstEnabled = false,
    this.gstin = '',
    this.taxRate = 5.0,
    this.serviceChargeRate = 0.0,
    this.invoicePrefix = 'MR-',
    this.nextInvoiceNumber = 1001,
    this.upiId = 'mehtarestaurant@okhdfcbank',
    this.upiPayeeName = 'Mehta Restaurant',
    this.inventoryTrackingEnabled = false,
    this.receiptFooterNote = 'Thank you! Visit Again.',
    this.thermalPaperWidth = 80,
    this.autoPrintReceipt = false,
  });

  String generateUpiUri({
    required double amount,
    required String note,
  }) {
    final encodedPn = Uri.encodeComponent(upiPayeeName);
    final encodedNote = Uri.encodeComponent(note);
    final formattedAmt = amount.toStringAsFixed(2);
    return 'upi://pay?pa=$upiId&pn=$encodedPn&am=$formattedAmt&cu=INR&tn=$encodedNote';
  }

  RestaurantSettings copyWith({
    String? id,
    String? restaurantName,
    String? tagline,
    String? address,
    String? phone,
    String? email,
    bool? gstEnabled,
    String? gstin,
    double? taxRate,
    double? serviceChargeRate,
    String? invoicePrefix,
    int? nextInvoiceNumber,
    String? upiId,
    String? upiPayeeName,
    bool? inventoryTrackingEnabled,
    String? receiptFooterNote,
    int? thermalPaperWidth,
    bool? autoPrintReceipt,
  }) {
    return RestaurantSettings(
      id: id ?? this.id,
      restaurantName: restaurantName ?? this.restaurantName,
      tagline: tagline ?? this.tagline,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      gstEnabled: gstEnabled ?? this.gstEnabled,
      gstin: gstin ?? this.gstin,
      taxRate: taxRate ?? this.taxRate,
      serviceChargeRate: serviceChargeRate ?? this.serviceChargeRate,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
      upiId: upiId ?? this.upiId,
      upiPayeeName: upiPayeeName ?? this.upiPayeeName,
      inventoryTrackingEnabled: inventoryTrackingEnabled ?? this.inventoryTrackingEnabled,
      receiptFooterNote: receiptFooterNote ?? this.receiptFooterNote,
      thermalPaperWidth: thermalPaperWidth ?? this.thermalPaperWidth,
      autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
    );
  }
}

enum StaffRole {
  owner,
  manager,
  cashier,
  waiter,
  kitchen,
}

class StaffMember {
  final String id;
  final String name;
  final StaffRole role;
  final String pin; // 4 digits
  final String avatarIcon;

  const StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.pin,
    this.avatarIcon = '👤',
  });

  String get roleDisplayName {
    switch (role) {
      case StaffRole.owner:
        return 'Owner';
      case StaffRole.manager:
        return 'Manager (Father)';
      case StaffRole.cashier:
        return 'Cashier';
      case StaffRole.waiter:
        return 'Waiter';
      case StaffRole.kitchen:
        return 'Kitchen Chef';
    }
  }

  bool get canEditMenu => role == StaffRole.owner || role == StaffRole.manager;
  bool get canManageSettings => role == StaffRole.owner || role == StaffRole.manager;
  bool get canManageAccounts => role == StaffRole.owner || role == StaffRole.manager || role == StaffRole.cashier;
  bool get canBill => role != StaffRole.kitchen;
  bool get canTakeOrders => true;
}
