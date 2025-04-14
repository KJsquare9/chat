import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import 'market_product.dart';
import 'my_listings_page.dart'; // Import MyListingsPage
import 'list_item_screen.dart'; // Add this import for ListItemScreen
import '../services/api_service.dart';
import 'dart:typed_data';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key}); // Convert 'key' to super parameter

  @override
  MarketplacePageState createState() => MarketplacePageState();
}

class MarketplacePageState extends State<MarketplacePage> {
  int? selectedCategory;
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> categories = [
    {'icon': Icons.local_florist, 'label': 'Farming'},
    {'icon': Icons.pets, 'label': 'Pets'},
    {'icon': Icons.directions_car, 'label': 'Cars'},
    {'icon': Icons.build, 'label': 'Tools'},
    {'icon': Icons.chair, 'label': 'Furniture'},
    {'icon': Icons.electrical_services, 'label': 'Electronics'},
    {'icon': Icons.grid_view, 'label': 'All'},
  ];

  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> filteredProducts = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final apiService = ApiService();
      final fetchedProducts = await apiService.getProducts();
      print(fetchedProducts);
      if (mounted) {
        // Check if widget is still mounted
        setState(() {
          products = fetchedProducts;
          filteredProducts = fetchedProducts;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        // Check if widget is still mounted
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  void _filterProducts() {
    if (!mounted) return; // Check if widget is still mounted
    setState(() {
      String query = _searchController.text.toLowerCase();
      filteredProducts =
          products.where((product) {
            bool matchesSearch =
                query.isEmpty || product['name'].toLowerCase().contains(query);
            bool matchesCategory =
                selectedCategory == null ||
                selectedCategory == categories.length - 1 ||
                product['category'].toLowerCase() ==
                    categories[selectedCategory!]['label'].toLowerCase();

            return matchesSearch && matchesCategory;
          }).toList();
    });
  }

  double _scrollOffset = 0.0; // Track scroll position

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              setState(() {
                _scrollOffset = scrollNotification.metrics.pixels;
              });
              return true;
            },
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 120.0,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  forceElevated: false,
                  iconTheme: const IconThemeData(color: Colors.black),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(color: Colors.white),
                    centerTitle: true,
                    title: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 80 - _scrollOffset.clamp(0, 40),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (value) => _filterProducts(),
                                  decoration: InputDecoration(
                                    hintText: 'Search products...',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25.0),
                                      borderSide: BorderSide(
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(25.0),
                                      borderSide: const BorderSide(
                                        color: Colors.blue,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16.0,
                                    ),
                                  ),
                                  // Remove onChanged: (value) { ... },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  bool? result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (context) => const MyListingsPage(),
                                    ),
                                  );

                                  if (result != null) {
                                    _fetchProducts();
                                  }
                                },

                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF5002),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25.0),
                                  ),
                                ),
                                child: const Text('MY LISTINGS'),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedCategory = index;
                                  });
                                  _filterProducts();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        selectedCategory == index
                                            ? Colors.blue
                                            : Colors.grey[200],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(categories[index]['icon']),
                                        const SizedBox(width: 8),
                                        Text(categories[index]['label']),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isLoading)
                  const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (errorMessage != null)
                  SliverFillRemaining(
                    child: Center(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                else if (filteredProducts.isEmpty)
                  const SliverFillRemaining(
                    child: Center(child: Text('No products available')),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(8.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 8.0,
                            childAspectRatio: 0.7,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return Container(
                          color: Colors.white,
                          child: Card(
                            elevation: 0,
                            color: Colors.grey.shade100,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15.0),
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) => ProductDetailsPage(
                                          product: filteredProducts[index],
                                        ),
                                  ),
                                );
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(15.0),
                                      ),
                                      child:
                                          filteredProducts[index]['images'] !=
                                                      null &&
                                                  filteredProducts[index]['images']
                                                      .isNotEmpty &&
                                                  filteredProducts[index]['images'][0]['data'] !=
                                                      null
                                              ? Image.memory(
                                                Uint8List.fromList(
                                                  List<int>.from(
                                                    filteredProducts[index]['images'][0]['data']['data'],
                                                  ),
                                                ),
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              )
                                              : const Icon(
                                                Icons.image_not_supported,
                                              ), // Fallback if no image
                                    ),
                                  ),

                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Text(
                                      filteredProducts[index]['name'],
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0,
                                    ),
                                    child: Text(
                                      '₹${filteredProducts[index]['price'].toString()}',
                                      style: TextStyle(color: Colors.grey[600]),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          ),
                        );
                      }, childCount: filteredProducts.length),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            bottom: 70,
            right: 16,
            child: FloatingActionButton.extended(
              onPressed: () async {
                bool? result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ListItemScreen(),
                  ),
                );

                if (result == true) {
                  _fetchProducts();
                }
              },
              label: const Text('NEW'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CustomNavBar(activeIndex: 2),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
