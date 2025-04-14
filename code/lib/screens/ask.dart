import 'package:flutter/material.dart';
import '../widgets/custom_navbar.dart';
import 'question.dart'; // Import the QuestionScreen
import 'questions_screen.dart'; // Import the QuestionsScreen
import 'news_feed_screen.dart'; // Import the NewsFeedScreen

class AskScreen extends StatelessWidget {
  const AskScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            // Navigate to NewsFeedScreen when the back icon is pressed
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => NewsFeedScreen()),
            );
          },
        ),
        title: Text('Ask Your Neta Analytics'),
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.bold,
          color: Color(0xFF093466),
          fontSize: 25
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: Column(
                children: [
                  SizedBox(height: 10),
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => QuestionsScreen()),
                          ),
                          child: Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFF093466), width: 2), // Add a border to indicate interactivity
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total Questions',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    Icon(Icons.arrow_forward, color: Colors.blue), // Add an arrow icon to indicate interactivity
                                  ],
                                ),
                                Text(
                                  'Q1 2025',
                                  style: TextStyle(color: Color(0xFFFF5002), fontSize: 14),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  '72',
                                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                ),
                                Text('Previous Quarter: 13', style: TextStyle(fontSize: 14)),
                                Text(
                                  '75% Answered',
                                  style: TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatCard('54', 'Answered', Colors.green),
                            _buildStatCard('18', 'Unanswered', Colors.red),
                          ],
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Top Performers',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        _buildPerformerRow('GT', 27, Colors.green),
                        _buildPerformerRow('LN', 19, Colors.green),
                        _buildPerformerRow('SI', 8, Colors.yellow),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Navigate to QuestionScreen when the button is pressed
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AskYourNetaScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF093466),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('ASK YOUR OWN QUESTION', style: TextStyle(color: Colors.white)),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF093466),
                      minimumSize: Size(double.infinity, 50),
                    ),
                    child: Text('DETAILED REPORT', style: TextStyle(color: Colors.white)),
                  ),
                  SizedBox(height: 80), // Add space for the fixed navbar
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomNavBar(activeIndex: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      width: 120,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformerRow(String name, int score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Color(0xFFFF5002),
            child: Text(name, style: TextStyle(color: Colors.white)),
          ),
          SizedBox(width: 10),
          Expanded(
            child: LinearProgressIndicator(
              value: score / 30,
              color: color,
              backgroundColor: color.withAlpha(76),
            ),
          ),
          SizedBox(width: 10),
          Text('$score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}