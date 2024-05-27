import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher_string.dart';

void main() async {
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Newwave Solution Locaion APIS'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final TextEditingController _searchController = TextEditingController();
  final String _apiKey = dotenv.env['API_KEY']!;
  final String _autoSuggestUrl = dotenv.env['AUTOSUGGEST_URL']!;
  bool _hasText = false;
  bool _isFetching = false;
  Map<String, dynamic> _searchResults = {};
  late Position position;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    _initializeLocationUpdates();
    _determinePosition();
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _hasText = _searchController.text.isNotEmpty;
      });
      if (_hasText) {
        _fetchSearchResults(_searchController.text);
      } else {
        setState(() {
          _searchResults = {};
        });
      }
    });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  // get the current location
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      // request permission after first denied
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    // Permisstions are granted, get location
    position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    return position;
  }

  void _initializeLocationUpdates() {
    Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter:
          10, // Minimum distance (in meters) before an update is triggered.
    )).listen((Position position) {
      setState(() {
        this.position = position;
      });
      // Fetch new search results whenever the position changes
      if (_hasText) {
        _fetchSearchResults(_searchController.text);
      }
    });
  }

  // get locations suggestions
  void _fetchSearchResults(String searchResult) async {
    setState(() {
      _isFetching = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          '$_autoSuggestUrl?apikey=$_apiKey&at=${position.latitude},${position.longitude}&q=$searchResult',
        ),
      );
      if (response.statusCode == 200) {
        final decodedResponse = utf8.decode(response.bodyBytes);
        setState(() {
          _searchResults = json.decode(decodedResponse);
        });
      } else {
        throw Exception('Unknown Error has occured!');
      }
    } catch (e) {
      // Handle error
      setState(() {
        _searchResults = {};
      });
    } finally {
      setState(() {
        _isFetching = false;
      });
    }
  }

  // open google map
  Future<void> _openGoogleMap(double lat, double long) async {
    String googleUrl =
        "https://www.google.com/maps/search/?api=1&query=$lat, $long";
    await canLaunchUrlString(googleUrl)
        ? await launchUrlString(googleUrl)
        : throw 'Could not launch $googleUrl';
  }

  TextSpan _highlightText(String resultText, String searchText) {
    // return result text
    if (searchText.isEmpty) {
      return TextSpan(text: resultText);
    }
    final matches = resultText.toLowerCase().split(searchText.toLowerCase());
    // means searchtext is not found in 'resultText'
    if (matches.length <= 1) {
      return TextSpan(
          text: resultText, style: const TextStyle(color: Colors.black));
    }
    List<TextSpan> spans = [];
    int start = 0;
    for (int i = 0; i < matches.length; i++) {
      if (matches[i].isNotEmpty) {
        spans.add(TextSpan(
            text: resultText.substring(start, start + matches[i].length)));
        start += matches[i].length;
      }
      if (i < matches.length - 1) {
        spans.add(TextSpan(
          text: resultText.substring(start, start + searchText.length),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ));
        start += searchText.length;
      }
    }
    return TextSpan(
        children: spans, style: const TextStyle(color: Colors.black));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(
                  top: 16,
                  left: 8,
                  right: 8,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 5,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _isFetching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.black),
                              ),
                            )
                          : const Icon(Icons.search),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Enter keyword',
                          hintStyle: TextStyle(),
                          isDense: true,
                        ),
                        onChanged: (value) {},
                      ),
                    ),
                    _hasText
                        ? IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _hasText = false;
                              });
                            },
                          )
                        : const SizedBox.shrink(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _searchResults.isNotEmpty &&
                        _searchResults['items'] != null
                    ? ListView.builder(
                        itemCount: _searchResults['items'].length,
                        itemBuilder: (context, index) {
                          final title = _searchResults['items'][index]['title'];
                          final address =
                              _searchResults['items'][index]['address'] != null
                                  ? _searchResults['items'][index]['address']
                                      ['label']
                                  : null;
                          return GestureDetector(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              height: 70,
                              child: Row(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(right: 8.0),
                                    child: Icon(
                                      Icons.place_outlined,
                                    ),
                                  ),
                                  Expanded(
                                    child: address == null
                                        ? RichText(
                                            text: _highlightText(
                                                title, _searchController.text),
                                          )
                                        : RichText(
                                            text: _highlightText(address,
                                                _searchController.text),
                                          ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _openGoogleMap(
                                          _searchResults['items'][index]
                                              ['position']['lat'],
                                          _searchResults['items'][index]
                                              ['position']['lng']);
                                    },
                                    icon: const Icon(Icons.directions),
                                  ),
                                ],
                              ),
                            ),
                            onDoubleTap: () {},
                          );
                        },
                      )
                    : const Center(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
