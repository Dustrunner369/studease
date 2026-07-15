import 'package:http/http.dart' as http;
import 'package:mobile/models/studyspot.dart' ;
import 'dart:convert';

var url = Uri.https('localhost:5001', 'studyspots');
var response = http.get(url);


Future<void> main() async {
  try {
    final spots = await fetchStudySpots();
    
    for (StudySpot s in spots) {
      print(s.toString());
    }

  } catch (e) {
    print('Error: $e');
  }
}

Future<http.Response> fetchSpots() {
  return http.get(Uri.parse('http://localhost:5001/studyspots'));
}

Future<List<StudySpot>> fetchStudySpots() async {
  final response = await http.get(
    Uri.parse('http://localhost:5001/studyspots'),
    headers: {'Accept': 'application/json'},
  );

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.    
    final List<dynamic> jsonList = json.decode(response.body) as List<dynamic>;

    return jsonList
        .map((json) => StudySpot.fromJson(json as Map<String, dynamic>))
        .toList();
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load study spots.');
  }
}
