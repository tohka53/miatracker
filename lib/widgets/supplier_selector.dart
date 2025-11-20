import 'package:flutter/material.dart';
import '../services/supply_company_service.dart';

/// Widget para seleccionar un proveedor
/// Uso: SupplierSelector(
///   selectedSupplierId: _supplierId,
///   onSupplierSelected: (supplierId) => setState(() => _supplierId = supplierId),
/// )
class SupplierSelector extends StatefulWidget {
  final int? selectedSupplierId;
  final ValueChanged<int?> onSupplierSelected;
  final bool isRequired;
  final String? label;

  const SupplierSelector({
    super.key,
    this.selectedSupplierId,
    required this.onSupplierSelected,
    this.isRequired = false,
    this.label,
  });

  @override
  State<SupplierSelector> createState() => _SupplierSelectorState();
}

class _SupplierSelectorState extends State<SupplierSelector> {
  List<Map<String, dynamic>> _suppliers = [];
  Map<String, dynamic>? _selectedSupplier;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await SupplyCompanyService.getSuppliers();
      setState(() {
        _suppliers = suppliers;
        _isLoading = false;
        if (widget.selectedSupplierId != null) {
          _selectedSupplier = _suppliers.firstWhere(
                (s) => s['id'] == widget.selectedSupplierId,
            orElse: () => {},
          );
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showSupplierPicker() async {
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SupplierPickerSheet(
        suppliers: _suppliers,
        selectedId: widget.selectedSupplierId,
        onRefresh: _loadSuppliers,
      ),
    );

    if (selected != null) {
      setState(() => _selectedSupplier = selected);
      widget.onSupplierSelected(selected['id']);
    }
  }

  void _clearSelection() {
    setState(() => _selectedSupplier = null);
    widget.onSupplierSelected(null);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Card(
        child: ListTile(
          leading: CircularProgressIndicator(),
          title: Text('Cargando proveedores...'),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: Icon(
          _selectedSupplier != null ? Icons.business : Icons.business_outlined,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          _selectedSupplier != null
              ? _selectedSupplier!['name']
              : widget.label ?? 'Seleccionar proveedor',
          style: TextStyle(
            fontWeight: _selectedSupplier != null
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        subtitle: _selectedSupplier != null && _selectedSupplier!['email'] != null
            ? Text(_selectedSupplier!['email'])
            : widget.isRequired
            ? const Text('Requerido', style: TextStyle(color: Colors.red))
            : const Text('Opcional'),
        trailing: _selectedSupplier != null
            ? IconButton(
          icon: const Icon(Icons.clear),
          onPressed: widget.isRequired ? null : _clearSelection,
        )
            : const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _showSupplierPicker,
      ),
    );
  }
}

/// Sheet modal para seleccionar proveedor
class _SupplierPickerSheet extends StatefulWidget {
  final List<Map<String, dynamic>> suppliers;
  final int? selectedId;
  final VoidCallback onRefresh;

  const _SupplierPickerSheet({
    required this.suppliers,
    this.selectedId,
    required this.onRefresh,
  });

  @override
  State<_SupplierPickerSheet> createState() => _SupplierPickerSheetState();
}

class _SupplierPickerSheetState extends State<_SupplierPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredSuppliers = [];

  @override
  void initState() {
    super.initState();
    _filteredSuppliers = widget.suppliers;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterSuppliers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSuppliers = widget.suppliers;
      } else {
        _filteredSuppliers = widget.suppliers.where((supplier) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Seleccionar Proveedor',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Búsqueda
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar proveedor...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _filterSuppliers,
                ),
              ),

              const SizedBox(height: 16),

              // Lista de proveedores
              Expanded(
                child: _filteredSuppliers.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No se encontraron proveedores',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onRefresh();
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Crear nuevo proveedor'),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  controller: scrollController,
                  itemCount: _filteredSuppliers.length,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemBuilder: (context, index) {
                    final supplier = _filteredSuppliers[index];
                    final isSelected = supplier['id'] == widget.selectedId;

                    return Card(
                      color: isSelected
                          ? Theme.of(context)
                          .colorScheme
                          .primaryContainer
                          : null,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          child: Text(
                            (supplier['name'] as String?)
                                ?.substring(0, 1)
                                .toUpperCase() ??
                                '?',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          supplier['name'] ?? 'Sin nombre',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (supplier['email'] != null)
                              Text(supplier['email']),
                            if (supplier['phone'] != null)
                              Text(supplier['phone']),
                          ],
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle)
                            : null,
                        onTap: () => Navigator.pop(context, supplier),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Widget compacto para mostrar información del proveedor en una card
class SupplierInfoCard extends StatelessWidget {
  final Map<String, dynamic>? supplier;
  final VoidCallback? onTap;
  final bool showDetails;

  const SupplierInfoCard({
    super.key,
    this.supplier,
    this.onTap,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    if (supplier == null) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.business_outlined),
          title: const Text('Sin proveedor asignado'),
          trailing: onTap != null ? const Icon(Icons.add) : null,
          onTap: onTap,
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            (supplier!['name'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          supplier!['name'] ?? 'Sin nombre',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: showDetails
            ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (supplier!['email'] != null) Text(supplier!['email']),
            if (supplier!['phone'] != null) Text(supplier!['phone']),
          ],
        )
            : null,
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}

/// Chip compacto para mostrar proveedor
class SupplierChip extends StatelessWidget {
  final Map<String, dynamic>? supplier;
  final VoidCallback? onTap;
  final bool showDeleteButton;
  final VoidCallback? onDelete;

  const SupplierChip({
    super.key,
    this.supplier,
    this.onTap,
    this.showDeleteButton = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (supplier == null) {
      return Chip(
        avatar: const Icon(Icons.business_outlined, size: 18),
        label: const Text('Sin proveedor'),
        onDeleted: onTap,
        deleteIcon: const Icon(Icons.add, size: 18),
      );
    }

    return Chip(
      avatar: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          (supplier!['name'] as String?)?.substring(0, 1).toUpperCase() ?? '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      label: Text(supplier!['name'] ?? 'Sin nombre'),
      onDeleted: showDeleteButton ? onDelete : null,
      deleteIcon: showDeleteButton ? const Icon(Icons.close, size: 18) : null,
    );
  }
}