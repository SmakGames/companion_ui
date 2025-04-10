import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'api_key.dart';

void main() {
  runApp(CompanionApp());
}

class CompanionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Companion',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final String _triggerWord = 'hey';
  String _reply = '';
  String _temp = '';
  String _city = '';
  String _formattedDateTime = '';
  String _lastWords = '';
  double? _lat;
  double? _lon;
  bool _showInput = false;
  bool _isListening = false;
  bool _isProcessing = false;
  bool _showCaptions = true;
  Timer? _weatherTimer;

  @override
  void initState() {
    super.initState();
    //
    // Initialize speech
    //
    _initSpeech();

    //
    // Initialize the location and weather data
    //
    _fetchLocationAndWeather();

    //
    // Set up a 15 minute timer to check the weather
    //
    _weatherTimer = Timer.periodic(
      Duration(minutes: 15),
      (_) => _fetchWeather(),
    );

    //
    // Create a formatteed date object
    //
    _formattedDateTime = DateFormat(
      'EEEE, MMMM d, y – hh:mm a',
    ).format(DateTime.now());

    //
    // Create a timer to update the time every minute
    //
    Timer.periodic(Duration(minutes: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _formattedDateTime = DateFormat(
          'EEEE, MMMM d, y – hh:mm a',
        ).format(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _weatherTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  //
  // Get speech started
  //
  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if ((status == 'done' || status == 'notListening') &&
            _isListening &&
            mounted) {
          // Delay to ensure previous session ends - set to 100 initially
          Future.delayed(Duration(milliseconds: 2000), () {
            if (_isListening && mounted) _startListening();
          });
        }
      },
      onError: (error) => print('Speech error: $error'),
    );
    if (available) {
      _startListening();
    } else {
      setState(() => _reply = 'Sorry, I can’t hear you yet!');
    }
  }

  //
  // Start listening to the user
  //
  void _startListening() async {
    if (!_isListening && await _speech.initialize()) {
      setState(() => _isListening = true);
    }
    // Stop any lingering session first
    await _speech.stop();
    await Future.delayed(Duration(milliseconds: 100)); // Small buffer of 50
    if (_isListening && mounted) {
      _speech.listen(
        listenFor: Duration(minutes: 10),
        pauseFor: Duration(seconds: 2),
        cancelOnError: false,
        partialResults: false,
        onResult: (result) {
          String words = result.recognizedWords.toLowerCase();
          setState(() => _lastWords = words);
          //
          // Listen for the trigger word. If the trigger word is spoken
          // at the beginning of the utterance, the talk_api gets called.
          //
          if (words.startsWith(_triggerWord) && !_isProcessing) {
            setState(() => _isProcessing = true);
            String message = words.replaceFirst(_triggerWord, '').trim();
            if (message.isNotEmpty) {
              _sendMessage(message).then((_) {
                if (mounted) {
                  setState(() => _isProcessing = false);
                  // initial delay set to 100
                  Future.delayed(Duration(milliseconds: 100), () {
                    if (_isListening && mounted) _startListening();
                  });
                }
              });
            } else {
              if (mounted) setState(() => _isProcessing = false);
            }
          } // end of trigger word condition
        },
      );
    }
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
  }

  //
  // Get the user location and weather data
  //
  Future<void> _fetchLocationAndWeather() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _reply = 'Please enable location services.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(
            () => _reply = 'I need location permission to get the weather!',
          );
          return;
        }
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
      _lat = position.latitude;
      _lon = position.longitude;
      await _fetchWeather();
    } catch (e) {
      setState(() {
        _lat = 43.0389;
        _lon = -87.9065;
        _temp = 'unknown';
        _city = 'unknown';
      });
    }
  }

  //
  // Calls a third party weather API only
  // if our latitude and longitude are known
  //
  Future<void> _fetchWeather() async {
    if (_lat == null || _lon == null) return;
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openweathermap.org/data/2.5/weather?lat=$_lat&lon=$_lon&appid=$weatherKey&units=imperial',
        ),
      );
      final data = jsonDecode(response.body);
      setState(() {
        _temp = data['main']['temp'].toInt().toString();
        _city = data['name'];
      });
    } catch (e) {
      setState(() => _temp = 'unknown');
    }
  }

  //
  // Send a message to the backend API
  //
  Future<void> _sendMessage(String message) async {
    const url = 'http://localhost:8000/talk_api/';
    try {
      final response = await http.post(
        Uri.parse(url),
        body: {
          'message': message,
          'my_lat': _lat.toString(),
          'my_lon': _lon.toString(),
          'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
          'city': _city,
        },
      );
      final data = jsonDecode(response.body);
      setState(() => _reply = data['reply']);
      //
      // create an audible response
      //
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.speak(_reply); // Speak the reply
    } catch (e) {
      setState(() => _reply = 'Oops, I can’t connect right now!');
    }
  }

  //
  // Creates our widget tree for the presentation of the UI
  //
  @override
  Widget build(BuildContext context) {
    final time = DateTime.now();
    final isDay = time.hour >= 6 && time.hour < 18;
    final weatherBg =
        _temp != 'unknown' && int.parse(_temp) < 50 ? 'cloudy' : 'sunny';

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage(
                  'assets/room_${weatherBg}_${isDay ? 'day' : 'night'}.png',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Image.asset('assets/companion.png'),
          ),
          Positioned(
            top: 20,
            left: 20,
            right: 20,
            child: Column(
              children: [
                //
                // Toggle captions
                //
                if (_showCaptions)
                  //
                  // The text response from the API is shown here
                  //
                  Text(
                    _reply.isNotEmpty ? _reply : 'Hello, I’m here for you!',
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                //
                // Temporary - the words that the user spoke
                //
                if (_showCaptions)
                  Text(
                    'Heard: $_lastWords',
                    style: TextStyle(fontSize: 16, color: Colors.blue),
                  ),
                //
                // The text that displays the weather and city
                //
                Text(
                  _temp != 'unknown' ? 'It’s $_temp°F in $_city' : '',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.cyanAccent,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        offset: Offset(1, 1),
                        blurRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 50,
            right: 20,
            child: Column(
              children: [
                //
                // The microphone toggle button
                //
                FloatingActionButton(
                  onPressed: _isListening ? _stopListening : _startListening,
                  child: Icon(_isListening ? Icons.mic_off : Icons.mic),
                ),
                SizedBox(height: 10),
                //
                // The button to navigate to the settings screen
                //
                FloatingActionButton(
                  onPressed:
                      () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => SettingsScreen()),
                      ),
                  child: Icon(Icons.settings),
                ),
                SizedBox(height: 10),
                //
                // The input textbox view/hide toggle button
                //
                FloatingActionButton(
                  onPressed: () => setState(() => _showInput = !_showInput),
                  child: Icon(_showInput ? Icons.close : Icons.chat),
                ),
                SizedBox(height: 10),
                //
                // The closed captions toggle button
                //
                FloatingActionButton(
                  onPressed:
                      () => setState(() => _showCaptions = !_showCaptions),
                  child: Icon(
                    _showCaptions
                        ? Icons.closed_caption_off
                        : Icons.closed_caption,
                  ),
                ),
              ],
            ),
          ),
          if (_showInput)
            //
            // The input box and the "send" button
            //
            Positioned(
              bottom: 120,
              left: 20,
              right: 80,
              child: Row(
                children: [
                  //
                  // The "Expanded" widget containing two children
                  //
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        labelText: 'Say something...',
                        labelStyle: TextStyle(color: Colors.white),
                        border: OutlineInputBorder(),
                        filled: true,
                        fillColor: Colors.black54,
                      ),
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  SizedBox(width: 10),
                  //
                  // The "send" button
                  //
                  ElevatedButton(
                    onPressed: () {
                      if (_controller.text.isNotEmpty) {
                        _sendMessage(_controller.text);
                        _controller.clear();
                        setState(() => _showInput = false);
                      }
                    },
                    child: Text('Send', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
          Positioned(
            bottom: 10,
            left: 10,
            right: 40,
            child: Text(
              _formattedDateTime,
              style: const TextStyle(
                fontSize: 24,
                color: Colors.cyanAccent,
                shadows: [
                  Shadow(
                    color: Colors.black,
                    offset: Offset(0, 0),
                    blurRadius: 2,
                  ),
                ],
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

//
// Creates our settings screen's widget tree for its UI
//
class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/room_sunny_night.png',
              fit:
                  BoxFit
                      .cover, // Fill screen, maintain aspect ratio, crop if needed
              width: double.infinity, // Ensure it spans full width
              height: double.infinity, // Ensure it spans full height
            ),
          ),
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4), // adjust opacity as needed
            ),
          ),
          // Foreground content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Account and Settings',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white, // Adjust for readability
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Add more settings widgets here
              ],
            ),
          ),
        ],
      ),
    );
  }
}
