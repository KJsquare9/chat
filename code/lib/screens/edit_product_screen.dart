import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import '../services/api_service.dart';

class EditProductScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const EditProductScreen({super.key, required this.product});

  @override
  EditProductScreenState createState() => EditProductScreenState();
}

class EditProductScreenState extends State<EditProductScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCategory;
  String? _selectedCondition;

  File? productImage;
  final Logger logger = Logger();
  Map<String, String>? encodedImage;

  @override
  void initState() {
    super.initState();

    _nameController.text = widget.product['name'] ?? 'Product Name';
    _descriptionController.text =
        widget.product['description'] ?? 'Product Description';
    _priceController.text = widget.product['price']?.toString() ?? '0.00';
    _quantityController.text = widget.product['quantity']?.toString() ?? '1';
    _selectedCategory = widget.product['category'] ?? 'Furniture';
    _selectedCondition = widget.product['condition'] ?? 'New';

    // Parse the available from date if it exists
    if (widget.product['availableFromDate'] != null) {
      try {
        // If the date is provided as an ISO string
        if (widget.product['availableFromDate'] is String) {
          _selectedDate = DateTime.parse(widget.product['availableFromDate']);
        }
        // If the date is provided as a timestamp
        else if (widget.product['availableFromDate'] is int) {
          _selectedDate = DateTime.fromMillisecondsSinceEpoch(
            widget.product['availableFromDate'],
          );
        }
        // If it's a Map with date components
        else if (widget.product['availableFromDate'] is Map) {
          final dateMap = widget.product['availableFromDate'];
          _selectedDate = DateTime(
            dateMap['year'] ?? DateTime.now().year,
            dateMap['month'] ?? DateTime.now().month,
            dateMap['day'] ?? DateTime.now().day,
          );
        }
      } catch (e) {
        logger.e('Error parsing date', error: e);
        _selectedDate = DateTime.now();
      }
    } else {
      _selectedDate = DateTime.now();
    }

    _loadExistingImage();
  }

  void _loadExistingImage() {
    if (widget.product.containsKey('images') &&
        widget.product['images'] is List &&
        widget.product['images'].isNotEmpty) {
      var productImage = widget.product['images'][0];

      if (productImage != null &&
          productImage['data'] != null &&
          productImage['data']['data'] != null) {
        Uint8List imageData = Uint8List.fromList(
          List<int>.from(productImage['data']['data']),
        );
        encodedImage = {
          'data': base64Encode(imageData),
          'name': 'product_image.png',
        };
      }
    }
  }

  Future<void> _replaceImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      if (pickedFile != null) {
        File file = File(pickedFile.path);

        setState(() {
          productImage = file;

          // Encode to base64 and store in encodedImage
          String base64Image = base64Encode(file.readAsBytesSync());
          encodedImage = {
            'data': base64Image,
            'name': 'product_${DateTime.now().millisecondsSinceEpoch}.png',
          };

          logger.i('Replaced product image from $source');
        });
      }
    } catch (e) {
      logger.e('Error picking image', error: e);
    }
  }

  Widget _buildImageWidget() {
    final double slotWidth = 250.0;
    final double slotHeight = 200.0;

    if (productImage != null) {
      return ClipRRect(
        child: Image.file(
          productImage!,
          width: slotWidth,
          height: slotHeight,
          fit: BoxFit.cover,
        ),
      );
    } else if (encodedImage != null) {
      Uint8List imageData = base64Decode(encodedImage!['data'] as String);

      return ClipRRect(
        child: Image.memory(
          imageData,
          width: slotWidth,
          height: slotHeight,
          fit: BoxFit.cover,
        ),
      );
    } else {
      return const Icon(
        Icons.image_not_supported,
        size: 100,
        color: Colors.grey,
      );
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Image Source'),
            actions: [
              TextButton(
                child: const Text('Camera'),
                onPressed: () {
                  Navigator.pop(context);
                  _replaceImage(ImageSource.camera);
                },
              ),
              TextButton(
                child: const Text('Gallery'),
                onPressed: () {
                  Navigator.pop(context);
                  _replaceImage(ImageSource.gallery);
                },
              ),
            ],
          ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2025),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _updateProduct() async {
    List<Map<String, String>> images = [];
    if (encodedImage != null) {
      images.add(encodedImage!);
    }

    bool success = await ApiService().updateProduct(
      productId: widget.product['_id'],
      name: _nameController.text,
      description: _descriptionController.text,
      price: double.tryParse(_priceController.text) ?? 0.0,
      quantity: int.tryParse(_quantityController.text) ?? 0,
      category: _selectedCategory ?? widget.product['category'],
      condition: _selectedCondition ?? widget.product['condition'],
      availableFromDate: _selectedDate ?? DateTime.now(),
      // images: images,
    );

    if (success) {
      logger.i('Product updated successfully');
      Navigator.pop(context);
    } else {
      logger.e('Failed to update product');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Center(child: Image.asset('assets/images/logo.png', height: 40)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit your listing',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Text('Make changes to your existing listing'),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Price',
                      border: OutlineInputBorder(),
                      suffixText: '\$',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Product Image'),
            const SizedBox(height: 10),
            Center(
              child: GestureDetector(
                onTap: _showImagePickerDialog,
                child: Container(
                  width: 250.0,
                  height: 200.0,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      _buildImageWidget(),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Text(
                            'Tap to Replace',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              value: _selectedCategory,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCategory = newValue;
                });
              },
              items:
                  <String>[
                    'Farming',
                    'Pets',
                    'Cars',
                    'Tools',
                    'Furniture',
                    'Electronics',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
            ),

            const SizedBox(height: 10),

            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Condition',
                border: OutlineInputBorder(),
              ),
              value: _selectedCondition,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedCondition = newValue;
                });
              },
              items:
                  <String>[
                    'New',
                    'Used - Like New',
                    'Used - Good',
                    'Used - Fair',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
            ),

            const SizedBox(height: 10),
            TextFormField(
              readOnly: true,
              decoration: InputDecoration(
                labelText:
                    _selectedDate == null
                        ? 'Select Date'
                        : DateFormat('MMMM dd, yyyy').format(_selectedDate!),
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () => _selectDate(context),
                ),
              ),
              onTap: () => _selectDate(context),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _updateProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF093466),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
