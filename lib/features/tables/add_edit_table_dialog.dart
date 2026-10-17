import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../providers/restaurant_provider.dart';

class AddEditTableDialog extends ConsumerStatefulWidget {
  final RestaurantTable? table;

  const AddEditTableDialog({super.key, this.table});

  @override
  ConsumerState<AddEditTableDialog> createState() => _AddEditTableDialogState();
}

class _AddEditTableDialogState extends ConsumerState<AddEditTableDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _numberController;
  late TextEditingController _nameController;
  late TextEditingController _customSectionController;
  late int _capacity;
  late String _selectedSection;
  bool _isCustomSection = false;

  static const List<String> _standardSections = [
    'Indoor AC',
    'Outdoor Lawn',
    'Rooftop Terrace',
    'First Floor',
    'Banquet Hall',
  ];

  @override
  void initState() {
    super.initState();
    final t = widget.table;
    _numberController = TextEditingController(text: t?.tableNumber ?? '');
    _nameController = TextEditingController(text: t?.name ?? '');
    _capacity = t?.capacity ?? 6;

    if (t != null) {
      if (_standardSections.contains(t.section)) {
        _selectedSection = t.section;
        _customSectionController = TextEditingController();
        _isCustomSection = false;
      } else {
        _selectedSection = 'Custom';
        _customSectionController = TextEditingController(text: t.section);
        _isCustomSection = true;
      }
    } else {
      _selectedSection = 'Indoor AC';
      _customSectionController = TextEditingController();
      _isCustomSection = false;
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _nameController.dispose();
    _customSectionController.dispose();
    super.dispose();
  }

  String _getFinalSection() {
    if (_isCustomSection) {
      final custom = _customSectionController.text.trim();
      return custom.isNotEmpty ? custom : 'Indoor AC';
    }
    return _selectedSection;
  }

  void _saveTable() {
    if (!_formKey.currentState!.validate()) return;

    final tableNumber = _numberController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final section = _getFinalSection();
    final capacity = _capacity;

    if (widget.table == null) {
      // Create new table
      final result = ref.read(tablesProvider.notifier).addTable(
            tableNumber: tableNumber,
            name: name.isNotEmpty ? name : 'Table $tableNumber',
            section: section,
            capacity: capacity,
          );

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to add table'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Table $tableNumber ($section, $capacity Seats) added successfully!'),
          backgroundColor: AppColors.statusAvailable,
        ),
      );
    } else {
      // Edit existing table
      final result = ref.read(tablesProvider.notifier).updateTableDetails(
            id: widget.table!.id,
            newTableNumber: tableNumber,
            newName: name.isNotEmpty ? name : 'Table $tableNumber',
            newSection: section,
            newCapacity: capacity,
          );

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to update table'),
            backgroundColor: Colors.red.shade700,
          ),
        );
        return;
      }

      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Table $tableNumber details updated successfully!'),
          backgroundColor: AppColors.statusAvailable,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.table != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_note : Icons.add_business_outlined,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? 'Edit Table ${widget.table!.tableNumber}' : 'Add New Dining Table',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  isEditing
                                      ? 'Update name, number, floor section & capacity'
                                      : 'Configure identifiers, zone & seating limit',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Table Number & Display Name Fields
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 380;
                    if (isNarrow) {
                      return Column(
                        children: [
                          TextFormField(
                            controller: _numberController,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                              LengthLimitingTextInputFormatter(8),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Table No. *',
                              hintText: 'e.g. T11, G01',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.pin, size: 18),
                              isDense: true,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Display Name / Label',
                              hintText: 'e.g. VIP Window Booth',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.label_outline, size: 18),
                              isDense: true,
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _numberController,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\-]')),
                              LengthLimitingTextInputFormatter(8),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Table No. *',
                              hintText: 'e.g. T11, G01',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.pin, size: 18),
                              isDense: true,
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: _nameController,
                            decoration: const InputDecoration(
                              labelText: 'Display Name / Label',
                              hintText: 'e.g. VIP Window Booth',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.label_outline, size: 18),
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 18),

                // Floor / Section Picker
                const Text(
                  'Floor / Location Zone:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._standardSections.map((sec) {
                      final isSelected = !_isCustomSection && _selectedSection == sec;
                      IconData icon = Icons.meeting_room_outlined;
                      if (sec.contains('Indoor')) icon = Icons.ac_unit;
                      if (sec.contains('Outdoor') || sec.contains('Lawn')) icon = Icons.park_outlined;
                      if (sec.contains('Rooftop') || sec.contains('Terrace')) icon = Icons.wb_twilight;
                      if (sec.contains('Banquet')) icon = Icons.celebration_outlined;
                      if (sec.contains('Floor')) icon = Icons.stairs_outlined;

                      return ChoiceChip(
                        avatar: Icon(icon, size: 16),
                        label: Text(sec),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setState(() {
                              _selectedSection = sec;
                              _isCustomSection = false;
                            });
                          }
                        },
                      );
                    }),
                    ChoiceChip(
                      avatar: const Icon(Icons.add_location_alt_outlined, size: 16),
                      label: const Text('Custom Floor / Area...'),
                      selected: _isCustomSection,
                      onSelected: (val) {
                        setState(() {
                          _isCustomSection = true;
                          _selectedSection = 'Custom';
                        });
                      },
                    ),
                  ],
                ),
                if (_isCustomSection) ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _customSectionController,
                    decoration: const InputDecoration(
                      labelText: 'Custom Floor / Zone Name',
                      hintText: 'e.g. Poolside Garden, Mezzanine, Private Cabana',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.edit_location_alt_outlined, size: 18),
                      isDense: true,
                    ),
                    validator: (val) {
                      if (_isCustomSection && (val == null || val.trim().isEmpty)) {
                        return 'Enter a custom section name';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 20),

                // Sitting Capacity Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Sitting Capacity:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_capacity Guests',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [2, 4, 6, 8, 10, 12].map((cap) {
                    final isSelected = _capacity == cap;
                    return ChoiceChip(
                      label: Text('$cap Seats'),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _capacity = cap);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.remove, size: 18),
                      onPressed: _capacity > 1 ? () => setState(() => _capacity--) : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Slider(
                        value: _capacity.toDouble().clamp(1.0, 30.0),
                        min: 1,
                        max: 30,
                        divisions: 29,
                        label: '$_capacity Seats',
                        onChanged: (val) => setState(() => _capacity = val.round()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.add, size: 18),
                      onPressed: _capacity < 50 ? () => setState(() => _capacity++) : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: Icon(isEditing ? Icons.check : Icons.add, size: 18),
                      label: Text(
                        isEditing ? 'Save Changes' : 'Create Table',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _saveTable,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
