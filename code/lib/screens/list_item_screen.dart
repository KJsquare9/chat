import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // Import intl for date formatting
import 'package:logger/logger.dart'; // Import logger package
import '../services/api_service.dart';

class ListItemScreen extends StatefulWidget {
  const ListItemScreen({super.key});

  @override
  ListItemScreenState createState() => ListItemScreenState();
}

class ListItemScreenState extends State<ListItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _productNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  DateTime? _selectedDate = DateTime.now();
  final Logger _logger = Logger(); // Initialize logger

  File? _image; // Store the selected image
  String? _selectedCategory;
  String? _selectedCondition;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await ImagePicker().pickImage(source: source);
      setState(() {
        if (pickedFile != null) {
          _image = File(pickedFile.path);
        } else {
          _logger.i('No image selected.');
        }
      });
    } catch (e) {
      _logger.e('Error picking image: $e');
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
   Future<void> _submitForm() async {
  if (_formKey.currentState!.validate()) {
    double price = double.parse(_priceController.text);
    int quantity = int.parse(_quantityController.text);

    bool success = await ApiService().createProduct(
      name: _productNameController.text,
      description: _descriptionController.text,
      price: price,
      quantity: quantity,
      category: _selectedCategory!,
      condition: _selectedCondition!,
      availableFromDate: _selectedDate!,
      image: _image,
    );

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product listed successfully')),
      );

      // ✅ Return a result to the previous page after a delay
      Future.delayed(const Duration(milliseconds: 500), () {
        Navigator.pop(context, true); // Passing `true` to signal success
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to list product')),
      );
    }
  }
}



  @override
  void dispose() {
    _productNameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
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
        centerTitle: true,
        title: Image.asset('assets/images/logo.png', height: 40),
      ),
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'List Your Item',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Share your product with potential buyers',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _productNameController,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter the product name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Price',
                          prefixText: '\$',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter the quantity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid integer';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (BuildContext context) {
                        return SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              ListTile(
                                leading: const Icon(Icons.camera_alt),
                                title: const Text('Take a photo'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImage(ImageSource.camera);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.image),
                                title: const Text('Choose from gallery'),
                                onTap: () {
                                  Navigator.pop(context);
                                  _pickImage(ImageSource.gallery);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        _image != null
                            ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _image!,
                                width: double.infinity,
                                height: 150,
                                fit: BoxFit.cover,
                              ),
                            )
                            : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.cloud_upload,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                                Text(
                                  'Upload Image',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Select Category',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCategory,
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
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCategory = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select a category';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Item Condition',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedCondition,
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
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedCondition = newValue;
                    });
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please select the item condition';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Availability',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          _selectedDate == null
                              ? 'Select Date'
                              : DateFormat('MMMM dd, yyyy').format(
                                _selectedDate!,
                              ), // Format the selected date
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // ElevatedButton(
                //   onPressed: () {
                //     if (_formKey.currentState!.validate()) {
                //       // Process data here (not implemented in this example)
                //       print('Product Name: ${_productNameController.text}');
                //       print('Description: ${_descriptionController.text}');
                //       print('Price: ${_priceController.text}');
                //       print('Quantity: ${_quantityController.text}');
                //       print('Image Path: ${_image?.path}');
                //       print('Category: $_selectedCategory');
                //       print('Condition: $_selectedCondition');
                //       print('Available Date: $_selectedDate');
                //       ScaffoldMessenger.of(context).showSnackBar(
                //         const SnackBar(content: Text('Processing Data')),
                //       );
                //     }
                //   },
                //   style: ElevatedButton.styleFrom(
                //     backgroundColor: const Color.fromRGBO(13, 71, 161, 1),
                //     foregroundColor: Colors.white,
                //     padding: const EdgeInsets.symmetric(vertical: 16),
                //     textStyle: const TextStyle(fontSize: 16),
                //   ),
                //   child: const Text('REVIEW PRODUCT LISTING'),
                // ),
                // const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _submitForm();
                      // Process data here (not implemented in this example)
                      _logger.i('Product Name: ${_productNameController.text}');
                      _logger.i('Description: ${_descriptionController.text}');
                      _logger.i('Price: ${_priceController.text}');
                      _logger.i('Quantity: ${_quantityController.text}');
                      _logger.i('Image Path: ${_image?.path}');
                      _logger.i('Category: $_selectedCategory');
                      _logger.i('Condition: $_selectedCondition');
                      _logger.i('Available Date: $_selectedDate');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Listing Product!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF5002),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  child: const Text('LIST PRODUCT'),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
