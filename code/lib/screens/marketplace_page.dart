import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/custom_navbar.dart';
import 'market_product.dart';
import 'my_listings_page.dart';
import 'list_item_screen.dart';
import '../services/api_service.dart';
import 'dart:typed_data';
import 'dart:convert';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

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
  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    
    try {
      final apiService = ApiService();
      final userPincode = await apiService.getPinCode();
      final fetchedProducts = await apiService.getProducts();

      if (!mounted) return;

      List<Map<String, dynamic>> matchedProducts = [];
      
      if (userPincode != null) {
        matchedProducts = fetchedProducts.where((product) {
          return product['pincode']?.toString() == userPincode.toString();
        }).toList();
      } else {
        // If no pincode, show all products
        matchedProducts = fetchedProducts;
      }

      setState(() {
        products = matchedProducts;
        filteredProducts = matchedProducts;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        errorMessage = 'Failed to load products: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void _filterProducts() {
    if (!mounted) return;
    setState(() {
      String query = _searchController.text.toLowerCase();
      filteredProducts =
          products.where((product) {
            bool matchesSearch =
                query.isEmpty ||
                (product['name']?.toString().toLowerCase().contains(query) ??
                    false);
            bool matchesCategory =
                selectedCategory == null ||
                selectedCategory == categories.length - 1 ||
                (product['category']?.toString().toLowerCase() ==
                    categories[selectedCategory!]['label']
                        .toString()
                        .toLowerCase());

            return matchesSearch && matchesCategory;
          }).toList();
    });
  }

  Future<void> _flagProduct(String productId) async {
    try {
      final apiService = ApiService();
      String? token = await apiService.getToken();
      String? sellerId = await apiService.getSellerId();

      if (token == null || sellerId == null) {
        throw Exception('User not logged in');
      }

      final response = await http.post(
        Uri.parse('${apiService.baseUrl}/api/products/$productId/flag'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'userId': sellerId}),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              responseData['message'] ?? 'Product flagged successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _fetchProducts(); // Refresh the product list
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? 'Failed to flag product'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              final newOffset = scrollNotification.metrics.pixels;
              if ((_scrollOffset - newOffset).abs() > 1.0) {
                setState(() {
                  _scrollOffset = newOffset;
                });
              }
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
                                  if (result == true) {
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
                        final product = filteredProducts[index];
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
                                          product: product,
                                        ),
                                  ),
                                );
                              },
                              child: Stack(
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius:
                                              const BorderRadius.vertical(
                                                top: Radius.circular(15.0),
                                              ),
                                          child:
                                              product['images'] != null &&
                                                      product['images']
                                                          .isNotEmpty &&
                                                      product['images'][0]['data'] !=
                                                          null
                                                  ? Image.memory(
                                                    Uint8List.fromList(
                                                      List<int>.from(
                                                        product['images'][0]['data']['data'] ?? [],
                                                      ),
                                                    ),
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                  )
                                                  : const Icon(
                                                    Icons.image_not_supported,
                                                  ),
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          product['name'] ?? 'Unnamed Product',
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
                                          '₹${product['price']?.toString() ?? '0'}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: GestureDetector(
                                      onTap: () => _flagProduct(product['_id']),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.flag,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
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
