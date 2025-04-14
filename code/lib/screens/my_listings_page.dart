import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'edit_product_screen.dart';

class MyListingsPage extends StatefulWidget {

  const MyListingsPage();

  @override
  MyListingsPageState createState() => MyListingsPageState();
}

class MyListingsPageState extends State<MyListingsPage> {
  List<Map<String, dynamic>> products = [];
  final ApiService apiService = ApiService();
  bool isLoading = true; // ✅ Track loading state

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    try {
      List<Map<String, dynamic>> fetchedProducts =
          await apiService.getProductsBySeller();

      setState(() {
        products = fetchedProducts;
        isLoading = false; // ✅ Stop loading once data is fetched
      });
    } catch (e) {
      print('Error loading products: $e');
      setState(() {
        isLoading = false; // ✅ Stop loading even if fetching fails
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context, false);
          },
        ),
        title: const Text(
          'My Listings',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator()) // ✅ Show loader only while loading
          : products.isEmpty
              ? const Center(
                  child: Text(
                    'No products available.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: products.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 16),
                        itemBuilder: (context, index) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.0),
                                child: products[index]['images'] != null &&
                                        products[index]['images'].isNotEmpty &&
                                        products[index]['images'][0]['data'] != null
                                    ? Image.memory(
                                        Uint8List.fromList(
                                          List<int>.from(products[index]['images']
                                              [0]['data']['data']),
                                        ),
                                        width: 80,
                                        height: 80,
                                        fit: BoxFit.cover,
                                      )
                                    : const Icon(Icons.image_not_supported,
                                        size: 80),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      products[index]['name'] ?? 'Unnamed Product',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      products[index]['price'] != null
                                          ? '₹${products[index]['price']}'
                                          : 'Price not available',
                                      style: TextStyle(color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditProductScreen(
                                        product: products[index],
                                      ),
                                    ),
                                  );
                                  fetchProducts(); // ✅ Refresh after editing
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () {
                                  _showDeleteConfirmationDialog(context, index);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Future<void> _showDeleteConfirmationDialog(
      BuildContext context, int index) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Delete'),
          content: const Text('Are you sure you want to delete this product?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Delete'),
              onPressed: () async {
                await _deleteProduct(index);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteProduct(int index) async {
    try {
      String productId = products[index]['_id'];
      await apiService.deleteProduct(productId);

      setState(() {
        products.removeAt(index);
      });
    } catch (e) {
      print('Error deleting product: $e');
    }
  }
}


 


