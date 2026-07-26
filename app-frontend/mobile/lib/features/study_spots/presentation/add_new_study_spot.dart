import 'package:flutter/material.dart';

class AddNewStudySpotPage extends StatelessWidget {


  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text("Add a New Spot"),
        centerTitle: true,
      ),
      body: Center(
        child: Text("Hello"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          print("This is working");
        },
        child: const Icon(Icons.search)
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
        ]
      ),
    );

    throw UnimplementedError();
  }
}