// screens/news_feed_screen.dart
import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import 'in_app_web_view.dart';
import '../services/api_service.dart';
import '../models/article.dart'; // Import the Article model

class NewsFeedScreen extends StatefulWidget {
  const NewsFeedScreen({super.key});

  @override
  NewsFeedScreenState createState() => NewsFeedScreenState();
}

class NewsFeedScreenState extends State<NewsFeedScreen> {
  double _scrollOffset = 0.0;
  List<Article> _articles = [];
  bool _isLoading = false;
  String _errorMessage = '';
  final ApiService apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _articles = [];
    });

    try {
      _articles = await apiService.getNewsArticles(); // Use the new method
    } catch (e) {
      _errorMessage = 'Error fetching news data: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(title: const Text('News Feed')),
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
                  expandedHeight: 120.0, // Initial height
                  backgroundColor: Colors.white, // AppBar background
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  forceElevated: false,
                  automaticallyImplyLeading: false, // Remove the back button

                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      color: Colors.white,
                    ), // Ensure background remains white
                    centerTitle: true,
                    title: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height:
                          70 -
                          _scrollOffset.clamp(
                            0,
                            10,
                          ), // Adjusted for more spacing and larger minimum size
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate((
                    BuildContext context,
                    int index,
                  ) {
                    if (_isLoading) { // Show loading indicator
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (_errorMessage.isNotEmpty) { // Show error message
                      return Center(child: Text(_errorMessage, style: TextStyle(color: Colors.red)));
                    }

                    if (index == _articles.length) {
                      return const SizedBox(
                        height: 80,
                      ); // Adjust height as needed
                    }

                    final article = _articles[index];
                    return Container( // Replaced Card with Container
                      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[100], // Light grey background
                        borderRadius: BorderRadius.circular(10.0), // Rounded corners
                        boxShadow: [
                          BoxShadow(
                            // ignore: deprecated_member_use
                            color: Colors.grey.withOpacity(0.3), // Subtle shadow
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3), // changes position of shadow
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              article.title,
                              style: const TextStyle(
                                fontSize: 20, // Increased title size
                                fontWeight: FontWeight.w600, // Semi-bold font
                                color: Colors.black87, // Darker text color
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Text(
                              article.description,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[700], // Slightly darker description
                              ),
                            ),
                            const SizedBox(height: 12.0),
                            Align(
                              alignment: Alignment.centerRight, // Align button to the right
                              child: ElevatedButton(
                                onPressed: () {
                                  // onReadMorePressed functionality
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => InAppWebView(url: article.link),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF093466), // Use primary color
                                  foregroundColor: Colors.white, // White text color
                                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                                  textStyle: const TextStyle(fontSize: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30.0), // Rounded button corners
                                  ),
                                ),
                                child: const Text('Read More'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }, childCount: _isLoading || _errorMessage.isNotEmpty ? 1 : _articles.length + 1),
                ),
              ],
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomNavBar(activeIndex: 0),
          ),
        ],
      ),
    );
  }
}