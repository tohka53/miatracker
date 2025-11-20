// lib/widgets/select_supplier_dialog.dart
// DIALOG TO SELECT SUPPLIER WITH SEARCH AND QUICK CREATION
// FINAL CORRECTED VERSION: With getSuppliers(), debounce and haptic feedback

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supply_company_service.dart';

/// Shows a dialog to select a supplier
///
/// Returns the Map with the selected supplier data or null if cancelled
Future<Map<String, dynamic>?> showSupplierSelectionDialog(
    BuildContext context, {
      int? currentSupplierId,
    }) async {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) => SelectSupplierDialog(
      currentSupplierId: currentSupplierId,
    ),
  );
}

class SelectSupplierDialog extends StatefulWidget {
  final int? currentSupplierId;

  const SelectSupplierDialog({
    Key? key,
    this.currentSupplierId,
  }) : super(key: key);

  @override
  State<SelectSupplierDialog> createState() => _SelectSupplierDialogState();
}

class _SelectSupplierDialogState extends State<SelectSupplierDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _filteredSuppliers = [];
  bool _isLoading = true;
  Map<String, dynamic>? _selectedSupplier;

  // Timer for search debounce
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel(); // Cancel timer when destroying widget
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);

    try {
      // ✅ USE getSuppliers() - the correct method according to your service
      final suppliers = await SupplyCompanyService.getSuppliers();

      setState(() {
        _suppliers = suppliers;
        _filteredSuppliers = suppliers;
        _isLoading = false;

        // Pre-select current supplier if exists
        if (widget.currentSupplierId != null) {
          _selectedSupplier = suppliers.firstWhere(
                (s) => s['id'] == widget.currentSupplierId,
            orElse: () => {},
          );
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading suppliers: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Filter suppliers with debounce to improve performance
  void _filterSuppliers(String query) {
    // Cancel previous search if exists
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Create new timer with 300ms delay
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        if (query.isEmpty) {
          _filteredSuppliers = _suppliers;
        } else {
          _filteredSuppliers = _suppliers.where((supplier) {
            final name = (supplier['name'] ?? '').toLowerCase();
            final email = (supplier['email'] ?? '').toLowerCase();
            final phone = (supplier['phone'] ?? '').toLowerCase();
            final searchQuery = query.toLowerCase();

            return name.contains(searchQuery) ||
                email.contains(searchQuery) ||
                phone.contains(searchQuery);
          }).toList();
        }
      });
    });
  }

  Future<void> _createNewSupplier() async {
    // Haptic feedback when opening creation dialog
    HapticFeedback.mediumImpact();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CreateSupplierDialog(),
    );

    if (result != null) {
      // Haptic feedback on successful creation
      HapticFeedback.heavyImpact();

      await _loadSuppliers();
      setState(() {
        _selectedSupplier = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B5F8C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Color(0xFF2B5F8C),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Select Supplier',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(context).pop(null);
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _filterSuppliers,
            ),

            const SizedBox(height: 16),

            // Create supplier button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _createNewSupplier,
                icon: const Icon(Icons.add),
                label: const Text('Create New Supplier'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Suppliers list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredSuppliers.isEmpty
                  ? _buildEmptyState()
                  : _buildSuppliersList(),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop(null);
                    },
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _selectedSupplier != null
                        ? () {
                      HapticFeedback.mediumImpact();
                      Navigator.of(context).pop(_selectedSupplier);
                    }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E3D),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Select'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty
                ? 'No suppliers available'
                : 'No suppliers found',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchController.text.isEmpty) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _createNewSupplier,
              icon: const Icon(Icons.add),
              label: const Text('Create First Supplier'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuppliersList() {
    return ListView.builder(
      itemCount: _filteredSuppliers.length,
      itemBuilder: (context, index) {
        final supplier = _filteredSuppliers[index];
        final isSelected = _selectedSupplier?['id'] == supplier['id'];

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          color: isSelected
              ? const Color(0xFF6B8E3D).withOpacity(0.1)
              : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? const Color(0xFF6B8E3D)
                  : const Color(0xFF2B5F8C).withOpacity(0.2),
              child: Text(
                (supplier['name'] as String?)
                    ?.substring(0, 1)
                    .toUpperCase() ??
                    '?',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2B5F8C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              supplier['name'] ?? 'No name',
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (supplier['email'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.email, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          supplier['email'],
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (supplier['phone'] != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        supplier['phone'],
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Color(0xFF6B8E3D))
                : null,
            onTap: () {
              // Haptic feedback on selection
              HapticFeedback.selectionClick();

              setState(() {
                _selectedSupplier = supplier;
              });
            },
          ),
        );
      },
    );
  }
}

// ============================================================================
// DIALOG TO CREATE SUPPLIER QUICKLY
// ============================================================================

class _CreateSupplierDialog extends StatefulWidget {
  const _CreateSupplierDialog();

  @override
  State<_CreateSupplierDialog> createState() => _CreateSupplierDialogState();
}

class _CreateSupplierDialogState extends State<_CreateSupplierDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _createSupplier() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate(); // Vibration for validation error
      return;
    }

    // Haptic feedback when starting creation
    HapticFeedback.mediumImpact();

    setState(() => _isCreating = true);

    try {
      final supplierData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'direccion': _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
      };

      final newSupplier =
      await SupplyCompanyService.createSupplier(supplierData);

      if (mounted) {
        // Success haptic feedback
        HapticFeedback.heavyImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Supplier created successfully'),
            backgroundColor: Color(0xFF6B8E3D),
          ),
        );

        Navigator.of(context).pop(newSupplier);
      }
    } catch (e) {
      if (mounted) {
        // Error haptic feedback
        HapticFeedback.vibrate();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating supplier: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isCreating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_business, color: Color(0xFF2B5F8C)),
          SizedBox(width: 12),
          Text('New Supplier'),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Supplier Name *',
                  hintText: 'E.g: ABC Distributors',
                  prefixIcon: Icon(Icons.business),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (optional)',
                  hintText: 'supplier@example.com',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty) {
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return 'Invalid email';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (optional)',
                  hintText: '+1 234-567-8900',
                  prefixIcon: Icon(Icons.phone),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  hintText: 'Supplier address',
                  prefixIcon: Icon(Icons.location_on),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating
              ? null
              : () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(null);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isCreating ? null : _createSupplier,
          icon: _isCreating
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.save),
          label: Text(_isCreating ? 'Creating...' : 'Create'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B8E3D),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}