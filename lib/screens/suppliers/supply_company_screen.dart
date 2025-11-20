import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/supply_company_service.dart';
import '../../widgets/collapsible_drawer.dart';

class SupplyCompanyScreen extends StatefulWidget {
  const SupplyCompanyScreen({super.key});

  @override
  State<SupplyCompanyScreen> createState() => _SupplyCompanyScreenState();
}

class _SupplyCompanyScreenState extends State<SupplyCompanyScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _suppliers = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await SupplyCompanyService.getSuppliers();
      final stats = await SupplyCompanyService.getSupplierStats();
      setState(() {
        _suppliers = suppliers;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _searchSuppliers(String query) async {
    if (query.isEmpty) {
      _loadData();
      return;
    }

    setState(() => _isLoading = true);
    try {
      final results = await SupplyCompanyService.searchSuppliers(query);
      setState(() {
        _suppliers = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _showSupplierForm({Map<String, dynamic>? supplier}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SupplierFormSheet(
        supplier: supplier,
        onSaved: () {
          Navigator.pop(context);
          _loadData();
        },
      ),
    );
  }

  void _showSupplierDetails(Map<String, dynamic> supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierDetailScreen(supplier: supplier),
      ),
    ).then((_) => _loadData());
  }

  Future<void> _deleteSupplier(Map<String, dynamic> supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text('Delete supplier'),
        content: Text(
          'Are you sure you want to delete ${supplier['name']}?\n\n'
              'Associated products will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await SupplyCompanyService.deleteSupplier(supplier['id']);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Supplier deleted')),
          );
        }
        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/suppliers',
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3E8),
        appBar: AppBar(
          leading: const SizedBox.shrink(),
          title: const Text(
            'Suppliers',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildStatsSection(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search supplier...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                      _loadData();
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  _searchSuppliers(value);
                },
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
              )
                  : _suppliers.isEmpty
                  ? _buildEmptyState()
                  : _buildSuppliersList(),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showSupplierForm(),
          backgroundColor: const Color(0xFF6B8E3D),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New Supplier'),
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.secondaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Total',
            _stats['total_proveedores']?.toString() ?? '0',
            Icons.business,
          ),
          _buildStatItem(
            'Active',
            _stats['proveedores_activos']?.toString() ?? '0',
            Icons.check_circle,
          ),
          _buildStatItem(
            'Products',
            _stats['total_productos_con_proveedor']?.toString() ?? '0',
            Icons.inventory_2,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.business_outlined,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'No registered suppliers'
                : 'No results found',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'Add your first supplier'
                : 'Try another search',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showSupplierForm(),
              icon: const Icon(Icons.add),
              label: const Text('Add Supplier'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuppliersList() {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      itemCount: _suppliers.length,
      itemBuilder: (context, index) {
        final supplier = _suppliers[index];
        return _buildSupplierCard(supplier);
      },
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> supplier) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: () => _showSupplierDetails(supplier),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      (supplier['name'] as String?)
                          ?.substring(0, 1)
                          .toUpperCase() ??
                          '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supplier['name'] ?? 'No name',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (supplier['description'] != null)
                          Text(
                            supplier['description'],
                            style: Theme.of(context).textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton(
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                        onTap: () => Future.delayed(
                          Duration.zero,
                              () => _showSupplierForm(supplier: supplier),
                        ),
                      ),
                      PopupMenuItem(
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ],
                        ),
                        onTap: () => Future.delayed(
                          Duration.zero,
                              () => _deleteSupplier(supplier),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (supplier['email'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.email, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(supplier['email']),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              if (supplier['phone'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.phone, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(supplier['phone']),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              if (supplier['direccion'] != null) ...[
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        SupplyCompanyService.formatDireccion(
                            supplier['direccion']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SUPPLIER FORM AND DETAILS
// ============================================================================

class SupplierFormSheet extends StatefulWidget {
  final Map<String, dynamic>? supplier;
  final VoidCallback onSaved;

  const SupplierFormSheet({
    super.key,
    this.supplier,
    required this.onSaved,
  });

  @override
  State<SupplierFormSheet> createState() => _SupplierFormSheetState();
}

class _SupplierFormSheetState extends State<SupplierFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _calleController = TextEditingController();
  final _zonaController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _paisController = TextEditingController();
  final _codigoPostalController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.supplier != null) {
      _nameController.text = widget.supplier!['name'] ?? '';
      _descriptionController.text = widget.supplier!['description'] ?? '';
      _emailController.text = widget.supplier!['email'] ?? '';
      _phoneController.text = widget.supplier!['phone'] ?? '';
      _websiteController.text = widget.supplier!['website'] ?? '';

      final direccion = SupplyCompanyService.parseDireccion(widget.supplier!['direccion']);
      _calleController.text = direccion['calle'] ?? '';
      _zonaController.text = direccion['zona'] ?? '';
      _ciudadController.text = direccion['ciudad'] ?? '';
      _paisController.text = direccion['pais'] ?? '';
      _codigoPostalController.text = direccion['codigo_postal'] ?? '';
    } else {
      _paisController.text = 'Guatemala';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _websiteController.dispose();
    _calleController.dispose();
    _zonaController.dispose();
    _ciudadController.dispose();
    _paisController.dispose();
    _codigoPostalController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = {
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'website': _websiteController.text.trim().isNotEmpty
            ? _websiteController.text.trim()
            : null,
        'direccion': SupplyCompanyService.createDireccionJsonb(
          calle: _calleController.text.trim(),
          zona: _zonaController.text.trim(),
          ciudad: _ciudadController.text.trim(),
          pais: _paisController.text.trim(),
          codigoPostal: _codigoPostalController.text.trim(),
        ),
      };

      if (widget.supplier != null) {
        await SupplyCompanyService.updateSupplier(widget.supplier!['id'], data);
      } else {
        await SupplyCompanyService.createSupplier(data);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.supplier != null
                ? 'Supplier updated'
                : 'Supplier created'),
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.supplier != null
                              ? 'Edit Supplier'
                              : 'New Supplier',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Basic information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name *',
                      prefixIcon: Icon(Icons.business),
                      border: OutlineInputBorder(),
                    ),
                    validator: SupplyCompanyService.validateSupplierName,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      prefixIcon: Icon(Icons.description),
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Contact information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: SupplyCompanyService.validateEmail,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone',
                      prefixIcon: Icon(Icons.phone),
                      border: OutlineInputBorder(),
                      hintText: '+502 1234-5678',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: SupplyCompanyService.validatePhone,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      labelText: 'Website',
                      prefixIcon: Icon(Icons.language),
                      border: OutlineInputBorder(),
                      hintText: 'https://example.com',
                    ),
                    keyboardType: TextInputType.url,
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'Address',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _calleController,
                    decoration: const InputDecoration(
                      labelText: 'Street',
                      prefixIcon: Icon(Icons.location_on),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _zonaController,
                          decoration: const InputDecoration(
                            labelText: 'Zone',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _codigoPostalController,
                          decoration: const InputDecoration(
                            labelText: 'Postal Code',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _ciudadController,
                    decoration: const InputDecoration(
                      labelText: 'City',
                      prefixIcon: Icon(Icons.location_city),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _paisController,
                    decoration: const InputDecoration(
                      labelText: 'Country',
                      prefixIcon: Icon(Icons.public),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _saveSupplier,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8E3D),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                          : Text(widget.supplier != null
                          ? 'Update'
                          : 'Save'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class SupplierDetailScreen extends StatefulWidget {
  final Map<String, dynamic> supplier;

  const SupplierDetailScreen({super.key, required this.supplier});

  @override
  State<SupplierDetailScreen> createState() => _SupplierDetailScreenState();
}

class _SupplierDetailScreenState extends State<SupplierDetailScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await SupplyCompanyService.getProductsBySupplier(
        widget.supplier['id'],
      );
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3E8),
      appBar: AppBar(
        title: Text(widget.supplier['name'] ?? 'Supplier'),
        backgroundColor: const Color(0xFF2B5F8C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primaryContainer,
                    Theme.of(context).colorScheme.secondaryContainer,
                  ],
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: Text(
                      (widget.supplier['name'] as String?)
                          ?.substring(0, 1)
                          .toUpperCase() ??
                          '?',
                      style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.supplier['name'] ?? 'No name',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.supplier['description'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.supplier['description'],
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contact information',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (widget.supplier['email'] != null)
                    _buildInfoTile(
                      Icons.email,
                      'Email',
                      widget.supplier['email'],
                      onTap: () => _copyToClipboard(
                        widget.supplier['email'],
                        'Email',
                      ),
                    ),
                  if (widget.supplier['phone'] != null)
                    _buildInfoTile(
                      Icons.phone,
                      'Phone',
                      widget.supplier['phone'],
                      onTap: () => _copyToClipboard(
                        widget.supplier['phone'],
                        'Phone',
                      ),
                    ),
                  if (widget.supplier['website'] != null)
                    _buildInfoTile(
                      Icons.language,
                      'Website',
                      widget.supplier['website'],
                      onTap: () => _copyToClipboard(
                        widget.supplier['website'],
                        'Website',
                      ),
                    ),
                  if (widget.supplier['direccion'] != null)
                    _buildInfoTile(
                      Icons.location_on,
                      'Address',
                      SupplyCompanyService.formatDireccion(
                        widget.supplier['direccion'],
                      ),
                      onTap: () => _copyToClipboard(
                        SupplyCompanyService.formatDireccion(
                          widget.supplier['direccion'],
                        ),
                        'Address',
                      ),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Products (${_products.length})',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _isLoading
                      ? const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF6B8E3D)))
                      : _products.isEmpty
                      ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No associated products'),
                    ),
                  )
                      : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _products.length,
                    itemBuilder: (context, index) {
                      final product = _products[index];
                      return _buildProductCard(product);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value,
      {VoidCallback? onTap}) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon),
        title: Text(label),
        subtitle: Text(value),
        trailing: const Icon(Icons.copy, size: 20),
        onTap: onTap,
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: product['imagen'] != null
              ? NetworkImage(product['imagen'])
              : null,
          child:
          product['imagen'] == null ? const Icon(Icons.inventory_2) : null,
        ),
        title: Text(product['nombre_producto'] ?? 'No name'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock: ${product['cantidad'] ?? 0}'),
            if (product['lugar_fisico'] != null)
              Text('Location: ${product['lugar_fisico']}'),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }
}