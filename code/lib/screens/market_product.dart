import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Import your API service
import '../screens/chat_screen.dart'; // Import the ChatScreen

class ProductDetailsPage extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsPage({super.key, required this.product});

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  int _currentImageIndex = 0;
  final PageController _pageController = PageController();

  List<Uint8List> getProductImages() {
    List<Uint8List> images = [];
    if (widget.product.containsKey('images') &&
        widget.product['images'] != null) {
      for (var image in widget.product['images']) {
        if (image != null && image['data'] != null) {
          images.add(Uint8List.fromList(List<int>.from(image['data']['data'])));
        }
      }
    }
    return images;
  }

  // Function to get category icon and color
  Map<String, dynamic> getCategoryBadge(String? category) {
    switch (category?.toLowerCase()) {
      case 'farming':
        return {
          'icon': Icons.agriculture,
          'color': Colors.green,
          'text': 'FARMING',
        };
      case 'pets':
        return {'icon': Icons.pets, 'color': Colors.teal, 'text': 'PETS'};
      case 'cars':
        return {
          'icon': Icons.directions_car,
          'color': Colors.red,
          'text': 'CARS',
        };
      case 'tools':
        return {'icon': Icons.build, 'color': Colors.orange, 'text': 'TOOLS'};
      case 'furniture':
        return {
          'icon': Icons.chair,
          'color': Colors.brown,
          'text': 'FURNITURE',
        };
      case 'electronics':
        return {
          'icon': Icons.electrical_services,
          'color': Colors.blue,
          'text': 'ELECTRONICS',
        };
      default:
        return {'icon': Icons.category, 'color': Colors.grey, 'text': 'OTHER'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Uint8List> images = getProductImages();
    final category = widget.product['category'];
    final categoryBadge = getCategoryBadge(category);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // App bar with back button and logo
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.indigo),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 60,
                        child: Image.asset('assets/images/logo.png'),
                      ),
                      const Text(
                        'PRODUCT DETAILS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'XX Feb, 20XX',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ],
              ),
            ),

            // Product image slider
            SizedBox(
              height: 240,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentImageIndex = index;
                      });
                    },
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return images.isNotEmpty
                          ? Image.memory(
                            images[index],
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                          : const Icon(Icons.image_not_supported);
                    },
                  ),

                  // Bottom indicator dots
                  Positioned(
                    bottom: 10,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        images.length,
                        (index) => Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                _currentImageIndex == index
                                    ? Colors.black
                                    : Colors.grey[500],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Product title, quantity, price and category badge
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.product['name'] ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                              },
                              child: const Icon(Icons.close, size: 18),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '\u20B9${widget.product['price'] ?? '0'}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quantity
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '× ${widget.product['quantity'] ?? '1'}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),

                  // Category badge
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: categoryBadge['color'],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          categoryBadge['icon'],
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        categoryBadge['text'],
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Condition and description
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONDITION: ${widget.product['condition']?.toUpperCase() ?? 'UNKNOWN'}',
                    style: const TextStyle(
                      color: Colors.indigo,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product['description'] ?? 'No description available',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Contact seller button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    _contactSeller(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween, // Align at ends
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            widget.product['seller_name']?.toUpperCase() ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: const [
                          Text(
                            'CONTACT SELLER',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _contactSeller(BuildContext context) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final apiService = ApiService();
      final productId = widget.product['_id'];

      if (productId == null) {
        if (mounted) {
          Navigator.pop(context); // Dismiss loading dialog
          _showErrorSnackbar(context, "Product ID is missing");
        }
        return;
      }

      // Call the API to find or create a conversation with the seller
      final response = await apiService.findOrCreateSellerConversation(
        productId,
      );

      // Dismiss loading dialog
      if (!mounted) return;
      Navigator.pop(context);

      if (response['success'] == true && response['conversation'] != null) {
        final conversation = response['conversation'];

        // Navigate to the chat screen with the conversation data
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ChatScreen(
                  conversationId: conversation['_id'],
                  receiverId: conversation['sellerId'],
                  receiverName:
                      conversation['sellerName'] ??
                      widget.product['seller_name'] ??
                      'Seller',
                ),
          ),
        );
      } else {
        if (!mounted) return;
        _showErrorSnackbar(
          context,
          response['message'] ?? "Failed to start conversation",
        );
      }
    } catch (e) {
      // Dismiss loading dialog if still showing
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
        _showErrorSnackbar(context, "Error: ${e.toString()}");
      }
    }
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
