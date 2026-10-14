enum TableState { available, occupied, billing }
enum KotState { newTicket, preparing, ready, served }
enum PaymentType { cash, upi, credit }
enum LedgerType { debit, credit } // debit: bill owes; credit: payment cleared

class RestaurantTable {
  final String id;
  final String tableNumber; // 'T01'..'T10'
  final int capacity;
  final TableState status;
  final String? activeOrderId;
  final int guestCount;

  RestaurantTable({
    required this.id,
    required this.tableNumber,
    this.capacity = 6,
    this.status = TableState.available,
    this.activeOrderId,
    this.guestCount = 0,
  });

  RestaurantTable copyWith({
    TableState? status,
    String? activeOrderId,
    int? guestCount,
  }) {
    return RestaurantTable(
      id: id,
      tableNumber: tableNumber,
      capacity: capacity,
      status: status ?? this.status,
      activeOrderId: activeOrderId ?? this.activeOrderId,
      guestCount: guestCount ?? this.guestCount,
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

  MenuItem({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.category,
    this.isPackaged = false,
    this.isVeg = true,
    this.isAvailable = true,
  });
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
    this.taxRate = 0.0,
    this.customerName,
    this.customerPhone,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get taxAmount => (subtotal - discount) * (taxRate / 100.0);
  double get grandTotal => (subtotal - discount) + (taxAmount > 0 ? taxAmount : 0);

  Order copyWith({
    List<OrderItem>? items,
    double? discount,
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

  KitchenTicket({
    required this.id,
    required this.kotNumber,
    required this.orderId,
    required this.tableNumber,
    required this.items,
    this.status = KotState.newTicket,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
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
  }) : issuedAt = issuedAt ?? DateTime.now();

  double get totalPaid => cashPaid + upiPaid;
  double get balanceDue => creditAmount;
}

class RestaurantSettings {
  final String restaurantName;
  final String address;
  final String phone;
  final bool gstEnabled;
  final String gstin;
  final double taxRate;
  final String invoicePrefix;
  final int nextInvoiceNumber;

  RestaurantSettings({
    this.restaurantName = 'Mehta Restaurant',
    this.address = 'Main Market Road, Ground Floor',
    this.phone = '+91 98765 43210',
    this.gstEnabled = false,
    this.gstin = '',
    this.taxRate = 5.0,
    this.invoicePrefix = 'MR-',
    this.nextInvoiceNumber = 1001,
  });

  RestaurantSettings copyWith({
    String? restaurantName,
    String? address,
    String? phone,
    bool? gstEnabled,
    String? gstin,
    double? taxRate,
    String? invoicePrefix,
    int? nextInvoiceNumber,
  }) {
    return RestaurantSettings(
      restaurantName: restaurantName ?? this.restaurantName,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      gstEnabled: gstEnabled ?? this.gstEnabled,
      gstin: gstin ?? this.gstin,
      taxRate: taxRate ?? this.taxRate,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      nextInvoiceNumber: nextInvoiceNumber ?? this.nextInvoiceNumber,
    );
  }
}
