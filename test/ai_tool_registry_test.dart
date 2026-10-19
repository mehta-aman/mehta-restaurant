import 'package:flutter_test/flutter_test.dart';
import 'package:mehta_restaurant/models/models.dart';
import 'package:mehta_restaurant/services/ai/ai_models.dart';
import 'package:mehta_restaurant/services/ai/ai_tool_registry.dart';
import 'package:mehta_restaurant/services/ai/ai_permission_guard.dart';
import 'package:mehta_restaurant/services/ai/ai_confirmation_manager.dart';

void main() {
  group('Phase 2: AI Tool Registry & Authorization Matrix Tests', () {
    setUp(() {
      AiToolRegistry.initialize();
      AiConfirmationManager.clearAll();
    });

    tearDown(() {
      AiConfirmationManager.clearAll();
    });

    test('Tool registry initializes with required read, prepare, and execute tools', () {
      final allTools = AiToolRegistry.allTools;
      expect(allTools.length, greaterThanOrEqualTo(15));

      final toolNames = allTools.map((t) => t.name).toSet();
      expect(toolNames, contains('search_menu'));
      expect(toolNames, contains('list_categories'));
      expect(toolNames, contains('search_customers'));
      expect(toolNames, contains('get_table_status'));
      expect(toolNames, contains('get_active_orders'));
      expect(toolNames, contains('get_kitchen_tickets'));
      expect(toolNames, contains('get_invoice_summary'));
      expect(toolNames, contains('get_sales_report'));
      expect(toolNames, contains('get_customer_balances'));
      expect(toolNames, contains('get_restaurant_settings'));
      expect(toolNames, contains('get_item_sales_performance'));
      expect(toolNames, contains('prepare_menu_item_create'));
      expect(toolNames, contains('prepare_menu_item_update'));
      expect(toolNames, contains('prepare_bulk_menu_import'));
      expect(toolNames, contains('prepare_customer_create'));
      expect(toolNames, contains('prepare_customer_balance_entry'));
      expect(toolNames, contains('prepare_table_status_change'));
      expect(toolNames, contains('prepare_order_change'));
      expect(toolNames, contains('prepare_payment'));
      expect(toolNames, contains('prepare_invoice'));
      expect(toolNames, contains('prepare_invoice_void'));
      expect(toolNames, contains('prepare_settings_update'));
      expect(toolNames, contains('execute_confirmed_action'));
    });

    test('Critical financial and bulk tools have strict risk levels', () {
      final bulkTool = AiToolRegistry.getTool('prepare_bulk_menu_import')!;
      expect(bulkTool.riskLevel, equals(AiRiskLevel.critical));

      final invoiceTool = AiToolRegistry.getTool('prepare_invoice')!;
      expect(invoiceTool.riskLevel, equals(AiRiskLevel.critical));

      final voidTool = AiToolRegistry.getTool('prepare_invoice_void')!;
      expect(voidTool.riskLevel, equals(AiRiskLevel.critical));

      final paymentTool = AiToolRegistry.getTool('prepare_payment')!;
      expect(paymentTool.riskLevel, equals(AiRiskLevel.high));

      final tableTool = AiToolRegistry.getTool('get_table_status')!;
      expect(tableTool.riskLevel, equals(AiRiskLevel.low));
    });

    test('Role Authorization Matrix: Owner has full operational access', () {
      const owner = StaffMember(id: 's1', name: 'Aman Mehta', role: StaffRole.owner, pin: '1234');
      final ownerTools = AiToolRegistry.toolsForRole(owner.role);

      expect(ownerTools.any((t) => t.name == 'prepare_bulk_menu_import'), isTrue);
      expect(ownerTools.any((t) => t.name == 'get_sales_report'), isTrue);
      expect(ownerTools.any((t) => t.name == 'prepare_invoice_void'), isTrue);
      expect(ownerTools.any((t) => t.name == 'prepare_settings_update'), isTrue);

      final perm = AiPermissionGuard.checkPermission(
        staff: owner,
        tool: AiToolRegistry.getTool('prepare_settings_update')!,
        arguments: {'gst_enabled': true, 'tax_rate': 5.0},
      );
      expect(perm.isAllowed, isTrue);
    });

    test('Role Authorization Matrix: Manager cannot modify tax settings', () {
      const manager = StaffMember(id: 's2', name: 'Sh. Mehta', role: StaffRole.manager, pin: '9999');

      // Allowed to prepare menu items
      final menuPerm = AiPermissionGuard.checkPermission(
        staff: manager,
        tool: AiToolRegistry.getTool('prepare_menu_item_create')!,
      );
      expect(menuPerm.isAllowed, isTrue);

      // Denied GST/Tax modifications in settings
      final taxPerm = AiPermissionGuard.checkPermission(
        staff: manager,
        tool: AiToolRegistry.getTool('prepare_settings_update')!,
        arguments: {'tax_rate': 12.0},
      );
      expect(taxPerm.isAllowed, isFalse);
      expect(taxPerm.rejectionReason, contains('Owner privileges'));
    });

    test('Role Authorization Matrix: Cashier denied menu edits and bulk imports', () {
      const cashier = StaffMember(id: 's3', name: 'Counter Cashier', role: StaffRole.cashier, pin: '2222');

      // Cashier can bill and view reports
      expect(AiToolRegistry.getTool('prepare_invoice')!.isAuthorizedFor(cashier.role), isTrue);
      expect(AiToolRegistry.getTool('get_sales_report')!.isAuthorizedFor(cashier.role), isTrue);

      // Cashier cannot add menu items or do bulk import
      final importPerm = AiPermissionGuard.checkPermission(
        staff: cashier,
        tool: AiToolRegistry.getTool('prepare_bulk_menu_import')!,
      );
      expect(importPerm.isAllowed, isFalse);
      expect(importPerm.rejectionReason, contains('Access Denied'));
    });

    test('Role Authorization Matrix: Waiter denied financial reports and payments', () {
      const waiter = StaffMember(id: 's4', name: 'Ramesh', role: StaffRole.waiter, pin: '1001');

      // Waiter can modify table orders
      expect(AiToolRegistry.getTool('prepare_order_change')!.isAuthorizedFor(waiter.role), isTrue);
      expect(AiToolRegistry.getTool('prepare_table_status_change')!.isAuthorizedFor(waiter.role), isTrue);

      // Waiter cannot view sales report
      final reportPerm = AiPermissionGuard.checkPermission(
        staff: waiter,
        tool: AiToolRegistry.getTool('get_sales_report')!,
      );
      expect(reportPerm.isAllowed, isFalse);
      expect(reportPerm.rejectionReason, contains('Access Denied'));

      // Waiter cannot record Khata payments
      final payPerm = AiPermissionGuard.checkPermission(
        staff: waiter,
        tool: AiToolRegistry.getTool('prepare_payment')!,
      );
      expect(payPerm.isAllowed, isFalse);
    });

    test('Role Authorization Matrix: Kitchen Chef only has KOT and stock toggle access', () {
      const chef = StaffMember(id: 's7', name: 'Kitchen Chef', role: StaffRole.kitchen, pin: '3333');

      expect(AiToolRegistry.getTool('get_kitchen_tickets')!.isAuthorizedFor(chef.role), isTrue);
      expect(AiToolRegistry.getTool('prepare_menu_item_update')!.isAuthorizedFor(chef.role), isTrue);

      expect(AiToolRegistry.getTool('get_sales_report')!.isAuthorizedFor(chef.role), isFalse);
      expect(AiToolRegistry.getTool('prepare_invoice')!.isAuthorizedFor(chef.role), isFalse);
      expect(AiToolRegistry.getTool('prepare_payment')!.isAuthorizedFor(chef.role), isFalse);
    });

    test('Confirmation Manager: Token issue, verification, expiration, and replay prevention', () {
      const owner = StaffMember(id: 's1', name: 'Aman Mehta', role: StaffRole.owner, pin: '1234');
      final params = {'dish': 'Dal Tadka', 'price': 180.0};

      // 1. Issue token
      final issued = AiConfirmationManager.issueToken(
        operationName: 'prepare_menu_item_create',
        validatedParameters: params,
        staff: owner,
        validity: const Duration(minutes: 5),
      );

      expect(issued.token.startsWith('act_'), isTrue);
      expect(issued.isExpired, isFalse);
      expect(AiConfirmationManager.activeTokenCount, equals(1));

      // 2. Consume token successfully
      final consumed = AiConfirmationManager.consumeToken(
        tokenString: issued.token,
        staff: owner,
        expectedOperation: 'prepare_menu_item_create',
      );
      expect(consumed.isValid, isTrue);
      expect(consumed.token!.validatedParameters['dish'], equals('Dal Tadka'));

      // 3. Replay attempt fails (single-use protection)
      final replay = AiConfirmationManager.consumeToken(
        tokenString: issued.token,
        staff: owner,
        expectedOperation: 'prepare_menu_item_create',
      );
      expect(replay.isValid, isFalse);
      expect(replay.error, contains('already been used'));
    });

    test('Confirmation Manager: Rejects expired tokens safely', () {
      const owner = StaffMember(id: 's1', name: 'Aman Mehta', role: StaffRole.owner, pin: '1234');

      // Issue token with negative duration (already expired)
      final expiredToken = AiConfirmationManager.issueToken(
        operationName: 'prepare_payment',
        validatedParameters: {'amount': 500},
        staff: owner,
        validity: const Duration(seconds: -1),
      );

      final res = AiConfirmationManager.consumeToken(
        tokenString: expiredToken.token,
        staff: owner,
        expectedOperation: 'prepare_payment',
      );
      expect(res.isValid, isFalse);
      expect(res.error, contains('expired'));
    });

    test('Export tool schemas produces valid function calling schemas for LLM', () {
      final schemas = AiToolRegistry.exportToolSchemasForRole(StaffRole.owner);
      expect(schemas.length, greaterThanOrEqualTo(15));

      final bulkSchema = schemas.firstWhere((s) => s['name'] == 'prepare_bulk_menu_import');
      expect(bulkSchema['description'], isNotEmpty);
      expect(bulkSchema['parameters']['type'], equals('object'));
      expect(bulkSchema['parameters']['properties']['raw_content'], isNotNull);
    });
  });
}
