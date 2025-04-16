import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'api_key.dart';
import 'dart:html' as html; // New import for web audio
import 'package:shared_preferences/shared_preferences.dart';

const String backendUrl = 'http://127.0.0.1:8000/api/v1/'; // Base URL for APIs

void main() {
  runApp(CompanionApp());
}

class CompanionApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Companion',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        textTheme: TextTheme(
          // Larger fonts for elderly users
          bodyLarge: TextStyle(fontSize: 28),
          bodyMedium: TextStyle(fontSize: 24),
          labelLarge: TextStyle(fontSize: 20),
        ),
      ),
      home: LoginScreen(), // Start with login
    );
  }
}

// New: Login screen for JWT authentication
class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _cityController = TextEditingController(); // New
  final TextEditingController _preferredNameController =
      TextEditingController(); // New
  final TextEditingController _securityAnswerController =
      TextEditingController(); // New
  final TextEditingController _newPasswordController =
      TextEditingController(); // New
  String _error = '';
  bool _isSignUp = false;
  bool _isResetPassword = false;

  Future<void> _login() async {
    final url = Uri.parse('${backendUrl}auth/token/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'username': _usernameController.text,
          'password': _passwordController.text,
        },
      );
      print('Login response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access']);
        await prefs.setString('refresh_token', data['refresh']);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => ChatScreen()),
        );
      } else {
        setState(() => _error = 'Login failed. Check credentials.');
      }
    } catch (e) {
      print('Login error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  // new
  Future<void> _signUp() async {
    if (_preferredNameController.text.isEmpty) {
      setState(() => _error = 'Please enter your preferred name.');
      return;
    }
    if (_securityAnswerController.text.isEmpty) {
      setState(() => _error = 'Please enter a security answer.');
      return;
    }
    final url = Uri.parse('${backendUrl}auth/register/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'password': _passwordController.text,
          'preferred_name': _preferredNameController.text,
          'city':
              _cityController.text.isNotEmpty ? _cityController.text : 'Boston',
          'security_answer': _securityAnswerController.text,
        }),
      );
      print('SignUp response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 201) {
        setState(() {
          _error = 'Account created! Please log in.';
          _isSignUp = false;
          _isResetPassword = false;
        });
      } else {
        setState(() => _error = 'Sign-up failed: ${response.body}');
      }
    } catch (e) {
      print('SignUp error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  Future<void> _resetPassword() async {
    final url = Uri.parse('${backendUrl}auth/password_reset/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': _usernameController.text,
          'security_answer': _securityAnswerController.text,
          'new_password': _newPasswordController.text,
        }),
      );
      print('Password reset response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200) {
        setState(() {
          _error = 'Password reset! Please log in.';
          _isResetPassword = false;
        });
      } else {
        setState(() => _error = 'Reset failed: ${response.body}');
      }
    } catch (e) {
      print('Reset error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isSignUp
              ? 'Sign Up'
              : _isResetPassword
              ? 'Reset Password'
              : 'Login',
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username (required)'),
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 10),
            if (!_isResetPassword)
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(labelText: 'Password (required)'),
                obscureText: true,
                style: TextStyle(fontSize: 24),
              ),
            if (_isSignUp) ...[
              SizedBox(height: 10),
              TextField(
                controller: _preferredNameController,
                decoration: InputDecoration(
                  labelText: 'Preferred Name (required)',
                ),
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _cityController,
                decoration: InputDecoration(labelText: 'City (optional)'),
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _securityAnswerController,
                decoration: InputDecoration(
                  labelText:
                      'Security Answer (e.g., First pet’s name, required)',
                ),
                style: TextStyle(fontSize: 24),
              ),
            ],
            if (_isResetPassword) ...[
              SizedBox(height: 10),
              TextField(
                controller: _securityAnswerController,
                decoration: InputDecoration(
                  labelText: 'Security Answer (e.g., First pet’s name)',
                ),
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(height: 10),
              TextField(
                controller: _newPasswordController,
                decoration: InputDecoration(labelText: 'New Password'),
                obscureText: true,
                style: TextStyle(fontSize: 24),
              ),
            ],
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_isSignUp) {
                  _signUp();
                } else if (_isResetPassword) {
                  _resetPassword();
                } else {
                  _login();
                }
              },
              child: Text(
                _isSignUp
                    ? 'Create Account'
                    : _isResetPassword
                    ? 'Reset Password'
                    : 'Login',
                style: TextStyle(fontSize: 20),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp
                    ? 'Already have an account? Login'
                    : 'Need an account? Sign Up',
                style: TextStyle(fontSize: 20, color: Colors.blue),
              ),
            ),
            TextButton(
              onPressed:
                  () => setState(() {
                    _isResetPassword = !_isResetPassword;
                    if (!_isResetPassword) _isSignUp = false;
                  }),
              child: Text(
                _isResetPassword ? 'Back to Login' : 'Forgot Password?',
                style: TextStyle(fontSize: 20, color: Colors.blue),
              ),
            ),
            if (_error.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text(
                  _error,
                  style: TextStyle(color: Colors.red, fontSize: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

// How It’s Supposed to Work (Big Picture)
// 1. Start: App loads → _initSpeech → mic on (_startListening).
// 2. Listen: Mic waits up to 10m (listenFor), finalizes after 4s silence (pauseFor).
// 3. Trigger: Hears “hey [message]” → strips “hey” → sends to _sendMessage.
// 4. Reply: OpenAI responds → Google TTS speaks → mic restarts (100ms delay).
// 5. Cycle: If silence or phrase ends, 2s delay (onStatus) → mic back on.
// 6. Stop: User toggles off → mic stays off.
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final SpeechToText _speech = SpeechToText();
  final String _triggerWord = 'hey';
  String _reply = '';
  String _temp = '';
  String _city = 'Boston';
  String _preferredName = ''; // From user_profile
  String _accountStatus = ''; // From user_profile
  String _units = 'imperial';
  String _formattedDateTime = '';
  String _lastWords = '';
  String? _accessToken; // JWT token
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
    // Load the access token
    //
    //_loadToken();
    _loadToken().then((_) {
      if (_accessToken != null && mounted) {
        _fetchUserProfile();
      }
      _initSpeech();
      _fetchLocationAndWeather();
    });

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

  // New: Load JWT token
  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _accessToken = prefs.getString('access_token');
    });
    if (_accessToken == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  // New: Fetch user_profile data
  Future<void> _fetchUserProfile() async {
    if (_accessToken == null) return;
    final url = Uri.parse('${backendUrl}user_profile/');
    try {
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _preferredName = data['preferred_name']?.toString() ?? '';
          _city = data['city'] ?? 'Boston';
          _accountStatus = data['account_status']?.toString() ?? '';
          _reply =
              _preferredName.isNotEmpty
                  ? 'Welcome, $_preferredName!'
                  : 'Welcome!';
        });
        _speakReply("Welcome $_preferredName! I am happy to see you.");
      } else if (response.statusCode == 401) {
        await _refreshToken();
        await _fetchUserProfile(); // Retry
      } else {
        setState(() => _reply = 'Couldn’t load profile.');
      }
    } catch (e) {
      setState(() => _reply = 'Network error fetching profile.');
    }
  }

  // New: Refresh JWT token
  Future<void> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refreshToken = prefs.getString('refresh_token');
    if (refreshToken == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
      return;
    }
    final url = Uri.parse('${backendUrl}auth/token/refresh/');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString('access_token', data['access']);
        setState(() => _accessToken = data['access']);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => LoginScreen()),
        );
      }
    } catch (e) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    }
  }

  //
  // Expected Behavior
  // Mic turns on at app start, stays on by restarting after each phrase or stop.
  // Console logs: “listening” → “done” → 2s pause → “listening” cycle.
  //
  Future<void> _initSpeech() async {
    //
    // Prepares the mic — returns true if ready
    //
    bool available = await _speech.initialize(
      // Callback for mic state changes (e.g., “listening,” “done,” “notListening”).
      // If mic stops (done = phrase ended, notListening = fully off) AND
      // you want it on (_isListening) AND widget’s alive (mounted), wait 2000ms (2s),
      // then restart via _startListening.
      onStatus: (status) {
        print('Speech status: $status');
        if ((status == 'done' || status == 'notListening') &&
            _isListening &&
            mounted) {
          // Delay to ensure previous session ends - set to 100 initially
          Future.delayed(Duration(milliseconds: 200), () {
            if (_isListening && mounted) _startListening();
          });
        }
      },
      // Logs issues (e.g., mic denied)—helps you debug.
      onError: (error) => print('Speech error: $error'),
    );
    // if (available): If init succeeds, start listening immediately.
    if (available) {
      _startListening();
    } else {
      // Else: Show a “can’t hear” message—user knows mic’s down.
      setState(() => _reply = 'Sorry, I can’t hear you yet!');
    }
  }

  //
  // Purpose: Core mic control—keeps it listening and processes “hey” triggers.
  // Expected Behavior:
  //  - Mic’s on → hears “hey [message]” → processes → speaks → restarts after 100ms.
  //  - Console: “listening” → phrase → “done” (after 4s silence) → quick restart.
  //
  void _startListening() async {
    // if (!_isListening && ...): If mic’s off, init it AND
    // flag _isListening—UI updates (e.g., mic icon).
    if (!_isListening && await _speech.initialize()) {
      setState(() => _isListening = true);
    }
    // _speech.stop(): Stops any active session - prevents overlap errors on web.
    await _speech.stop();
    // Future.delayed(10ms): Tiny buffer—lets web’s SpeechRecognition reset
    await Future.delayed(Duration(milliseconds: 10)); // Small buffer of 50
    if (_isListening && mounted) {
      // speech.listen(): Starts mic with:
      // - listenFor: 10 minutes: Max duration—web might cap lower (e.g., Chrome ~10m) —
      //   keeps mic alive long-term.
      // - pauseFor: <n> seconds: After <n>s silence, finalizes phrase—triggers onResult.
      // - cancelOnError: false: Keeps going despite glitches—robust for elderly users.
      // - partialResults: false: Waits for full phrase—cleaner input.
      // - onResult:
      // - - Stores Words: words = full phrase (e.g., “hey how’s it going”).
      // - - Trigger Check: If starts with “hey” and not busy (_isProcessing), act:
      // - - - Strip Trigger: message = “how’s it going”.
      // - - - Send: Call _sendMessage—talks to OpenAI/Google TTS.
      // - - - Post-Reply: After _sendMessage finishes (.then),
      // - - - - reset _isProcessing,
      // - - - - wait 100ms,
      // - - - - restart listening.
      // - - Empty Case: If just “hey” (no message), reset _isProcessing — no action.
      _speech.listen(
        listenFor: Duration(minutes: 10), // 10 "minutes: 10"
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
            //
            // Removes the trigger word.
            //
            String message = words.replaceFirst(_triggerWord, '').trim();
            if (message.isNotEmpty) {
              _sendMessage(message).then((_) {
                if (mounted) {
                  setState(() => _isProcessing = false);
                  //
                  // initial delay set to 100
                  // Too long? If mic’s off too much, play with the number to test responsiveness.
                  //
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

  // How It Works
  // Purpose: Manual mic off—via UI toggle.
  //   _isListening = false: Stops auto-restart in _initSpeech’s onStatus.
  //   _speech.stop(): Turns off mic immediately.
  // Expected Behavior
  //   Mic off, no restarts—UI shows “mic off” icon.
  void _stopListening() {
    setState(() => _isListening = false);
    _speech.stop();
  }

  //
  // Get the user location and weather data
  //
  Future<void> _fetchLocationAndWeather() async {
    // Web fallback: Use user_profile city if geolocator fails
    //bool isWeb = identical(0, 0.0); // Simple web check
    //if (isWeb) {
    //  await _fetchWeather();
    //  return;
    //}
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
  // Calls our weather API only
  // if our latitude and longitude are known
  //
  Future<void> _fetchWeather() async {
    if (_lat == null || _lon == null) {
      setState(() => _temp = "No location");
      return;
    }

    final url = Uri.parse(
      '${backendUrl}weather/?lat=$_lat&lon=$_lon&units=$_units',
    );
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _temp = data['temperature']?.toString() ?? "Unknown";
          _city = data['city'] ?? "Unknown";
          _units = data['units'] ?? _units;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() => _temp = errorData['error'] ?? "Weather error");
      }
    } catch (e) {
      setState(() => _temp = "Network error");
    }
  }

  //
  // Send a message to the backend API
  //
  Future<void> _sendMessage(String message) async {
    final url = Uri.parse('${backendUrl}talk/');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          'city': _city, // Use user_profile city
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _reply = data['reply'] ?? 'No response');
        await _speakReply(data['reply']);
      } else if (response.statusCode == 401) {
        await _refreshToken();
        await _sendMessage(message); // Retry
      } else {
        setState(() => _reply = 'Error: ${response.body}');
      }
    } catch (e) {
      setState(() => _reply = 'Can’t connect to chat service.');
    }
  }

  Future<void> _speakReply(String text) async {
    const googleTtsUrl =
        'https://texttospeech.googleapis.com/v1/text:synthesize';
    try {
      final ttsResponse = await http.post(
        Uri.parse(googleTtsUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': googleApiKey,
        },
        body: jsonEncode({
          'input': {'text': text},
          'voice': {'languageCode': 'en-US', 'name': 'en-US-News-L'},
          'audioConfig': {
            'audioEncoding': 'MP3',
            'speakingRate': 1.0,
            'pitch': 0.0,
          },
        }),
      );
      if (ttsResponse.statusCode == 200) {
        final ttsData = jsonDecode(ttsResponse.body);
        final audioContent = ttsData['audioContent'];
        final blob = html.Blob([base64Decode(audioContent)]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        final audio =
            html.AudioElement()
              ..src = url
              ..autoplay = true;
        html.document.body?.append(audio);
        audio.onEnded.listen((_) {
          audio.remove();
          html.Url.revokeObjectUrl(url);
        });
      } else {
        setState(() => _reply = 'Sorry, I can’t speak right now!');
      }
    } catch (e) {
      setState(() => _reply = 'Speech error. Try again.');
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
                    _reply.isNotEmpty
                        ? _reply
                        : 'Hello, ${_preferredName.isNotEmpty ? _preferredName : "friend"}!',
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
                    fontSize: 28,
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
                        MaterialPageRoute(
                          builder:
                              (_) => SettingsScreen(
                                preferredName: _preferredName,
                                city: _city,
                                accountStatus: _accountStatus,
                                showCaptions: _showCaptions,
                                onCaptionsChanged: (value) {
                                  setState(() => _showCaptions = value);
                                },
                              ),
                        ),
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
class SettingsScreen extends StatefulWidget {
  final String preferredName;
  final String city;
  final String accountStatus;
  final bool showCaptions;
  final ValueChanged<bool> onCaptionsChanged;

  SettingsScreen({
    required this.preferredName,
    required this.city,
    required this.accountStatus,
    required this.showCaptions,
    required this.onCaptionsChanged,
  });

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isChangePassword = false;
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  String _error = '';

  Future<void> _changePassword() async {
    final url = Uri.parse('${backendUrl}auth/password_change/');
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'old_password': _oldPasswordController.text,
          'new_password': _newPasswordController.text,
        }),
      );
      print(
        'Password change response: ${response.statusCode} ${response.body}',
      );
      if (response.statusCode == 200) {
        setState(() {
          _error = 'Password changed successfully!';
          _isChangePassword = false;
          _oldPasswordController.clear();
          _newPasswordController.clear();
        });
      } else {
        setState(() => _error = 'Change failed: ${response.body}');
      }
    } catch (e) {
      print('Change password error: $e');
      setState(() => _error = 'Network error. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Settings')),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/room_sunny_night.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Hello, ${widget.preferredName.isNotEmpty ? widget.preferredName : 'User'}!',
                  style: TextStyle(
                    fontSize: 28,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 20),
                Text(
                  'City: ${widget.city}',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
                Text(
                  'Account Status: ${widget.accountStatus == 'A' ? 'Active' : 'Suspended'}',
                  style: TextStyle(fontSize: 24, color: Colors.white),
                ),
                SizedBox(height: 20),
                if (_isChangePassword) ...[
                  TextField(
                    controller: _oldPasswordController,
                    decoration: InputDecoration(labelText: 'Old Password'),
                    obscureText: true,
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: _newPasswordController,
                    decoration: InputDecoration(labelText: 'New Password'),
                    obscureText: true,
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _changePassword,
                    child: Text(
                      'Change Password',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isChangePassword = false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(fontSize: 20, color: Colors.blue),
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () => setState(() => _isChangePassword = true),
                    child: Text(
                      'Change Password',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ],
                SizedBox(height: 20),
                SwitchListTile(
                  title: Text(
                    'Show Captions',
                    style: TextStyle(fontSize: 24, color: Colors.white),
                  ),
                  value: widget.showCaptions,
                  onChanged: widget.onCaptionsChanged,
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    );
                  },
                  child: Text('Logout', style: TextStyle(fontSize: 20)),
                ),
                if (_error.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      _error,
                      style: TextStyle(color: Colors.red, fontSize: 20),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
