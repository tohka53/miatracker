import 'package:flutter/material.dart';
import 'collapsible_drawer.dart';

/// Widget base para pantallas que necesiten el drawer
/// Simplifica la implementación del drawer en diferentes screens
class DrawerScaffold extends StatelessWidget {
  final Widget body;
  final String title;
  final String currentRoute;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final bool showAppBar;
  final Color? backgroundColor;

  const DrawerScaffold({
    super.key,
    required this.body,
    required this.title,
    required this.currentRoute,
    this.actions,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.showAppBar = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: currentRoute,
      child: Scaffold(
        backgroundColor: backgroundColor ?? const Color(0xFFF5F3E8),
        appBar: showAppBar
            ? AppBar(
          title: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          elevation: 2,
          actions: actions,
          automaticallyImplyLeading: false, // Remove default back button
        )
            : null,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                backgroundColor ?? const Color(0xFFF5F3E8),
                const Color(0xFFE8E5D6),
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: showAppBar ? 16 : 70, // Space for menu button if no AppBar
                bottom: 16,
              ),
              child: body,
            ),
          ),
        ),
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: floatingActionButtonLocation,
      ),
    );
  }
}

/// Ejemplo de cómo usar el DrawerScaffold en otras pantallas
class ExampleInventoryScreen extends StatefulWidget {
  const ExampleInventoryScreen({super.key});

  @override
  State<ExampleInventoryScreen> createState() => _ExampleInventoryScreenState();
}

class _ExampleInventoryScreenState extends State<ExampleInventoryScreen> {
  @override
  Widget build(BuildContext context) {
    return DrawerScaffold(
      title: 'Inventory',
      currentRoute: '/inventory',
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            // Implement search functionality
          },
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: () {
            // Implement filter functionality
          },
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new asset
        },
        backgroundColor: const Color(0xFF6B8E3D),
        child: const Icon(Icons.add),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.search,
                  color: Color(0xFF2B5F8C),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Search assets...',
                    style: TextStyle(
                      color: Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                ),
                Icon(
                  Icons.mic,
                  color: Color(0xFF6B8E3D),
                ),
              ],
            ),
          ),

          // Categories filter
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryChip('All', true),
                _buildCategoryChip('Electronics', false),
                _buildCategoryChip('Machinery', false),
                _buildCategoryChip('Vehicles', false),
                _buildCategoryChip('Furniture', false),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Assets list
          Expanded(
            child: ListView.builder(
              itemCount: 5, // Example count
              itemBuilder: (context, index) {
                return _buildAssetCard(
                  name: 'Sample Asset ${index + 1}',
                  category: 'Electronics',
                  status: index % 2 == 0 ? 'Active' : 'Maintenance',
                  assetTag: 'AST-${1000 + index}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, bool isSelected) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      child: FilterChip(
        label: Text(
          category,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF2B5F8C),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          // Handle category selection
        },
        backgroundColor: Colors.white,
        selectedColor: const Color(0xFF6B8E3D),
        checkmarkColor: Colors.white,
        side: BorderSide(
          color: isSelected ? const Color(0xFF6B8E3D) : Colors.grey.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildAssetCard({
    required String name,
    required String category,
    required String status,
    required String assetTag,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF2B5F8C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.laptop_mac,
              color: Color(0xFF2B5F8C),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$category • $assetTag',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: status == 'Active'
                  ? const Color(0xFF6B8E3D).withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: status == 'Active'
                    ? const Color(0xFF6B8E3D)
                    : Colors.orange,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // Show options menu
            },
          ),
        ],
      ),
    );
  }
}