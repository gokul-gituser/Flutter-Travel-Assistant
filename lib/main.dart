import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/backend_service.dart';
import 'services/location_service.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB85C38)),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;

  ChatMessage({required this.text, required this.isUser});
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  Future<void> _login(BuildContext context) async {
    final result = await FacebookAuth.instance.login();

    if (result.status == LoginStatus.success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    } else {
      print(result.status);
      print(result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => _login(context),
          child: const Text("Login with Facebook"),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<Position>? _positionStream;

  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  

  double? _lat;
  double? _lng;

  // Colours
  static const Color _bg = Color(0xFFFAF6F1);
  static const Color _userBubble = Color(0xFFB85C38);
  static const Color _botBubble = Color(0xFFFFFFFF);
  static const Color _accent = Color(0xFFB85C38);
  static const Color _textDark = Color(0xFF2C1A0E);
  static const Color _textLight = Color(0xFF8C6A52);


void _startLocationStream() async {
 // Check if we actually have permission before starting
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      print("⚠️ Cannot start stream: No permissions");
     return;
   }

 // Cancel any existing stream just in case
    _positionStream?.cancel();

    DateTime? _lastSent;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 100, 
      ),
    ).listen((Position position) {

      final now = DateTime.now();
      if (_lastSent != null &&
          now.difference(_lastSent!) < const Duration(seconds: 5)) {
        return;
      }
      _lastSent = now;

      if (mounted) {
        setState(() { 
          _lat = position.latitude;
          _lng = position.longitude;
        });
      }

      BackendService.updateLocation(
        userId: BackendService.userId, 
        lat: position.latitude,
        lng: position.longitude,
      );
      
      print("📍 LIVE LOCATION UPDATED: $_lat, $_lng");
    });
  }

  @override
  void initState() {
    super.initState();
    _messages.add(ChatMessage(
      text: "Hello! I'm your travel assistant ✈️\nAsk me about places to visit, food, itineraries, safety tips — anything travel related.",
      isUser: false,

      
    ));
    _startLocationStream();
/*
    // ✅ START LOCATION STREAM HERE
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 50,
      ),
    ).listen((Position position) {
      setState(() { 
        _lat = position.latitude;
        _lng = position.longitude;
      });

      print("📍 LIVE LOCATION: $_lat, $_lng");
    });
    */
  }
  

  @override
  void dispose() {
    _positionStream?.cancel();

    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _send() async {
  final text = _controller.text.trim();
  if (text.isEmpty || _isLoading) return;

  _controller.clear();
  HapticFeedback.lightImpact();

  setState(() {
    _messages.add(ChatMessage(text: text, isUser: true));
    _isLoading = true;
  });
  _scrollToBottom();

  try {
    String reply = await BackendService.sendMessage(
      text,
      lat: _lat,
      lng: _lng,
    );

    // If LLM asks for location
    if (_needsLocation(reply) && _lat == null) {

      // Show LLM message in chat
      setState(() {
        _messages.add(ChatMessage(text: reply, isUser: false));
      });

      final granted = await _showLocationDialog();

      // Show user decision in chat
      setState(() {
        _messages.add(ChatMessage(
          text: granted
              ? "User allowed location access"
              : "User denied location permission",
          isUser: true,
        ));
      });

      if (granted) {
        final position = await LocationService.getLocation();

        if (position != null) {
          _lat = position.latitude;
          _lng = position.longitude;

          // START THE STREAM NOW THAT WE HAVE PERMISSION!
          _startLocationStream();

          // resend original message WITH location
          reply = await BackendService.sendMessage(
            text,
            lat: _lat,
            lng: _lng,
          );

          setState(() {
            _messages.add(ChatMessage(text: reply, isUser: false));
          });
        }
      }

      setState(() {
        _isLoading = false;
      });

      _scrollToBottom();
      return;
    }

    // normal reply
    setState(() {
      _messages.add(ChatMessage(text: reply, isUser: false));
      _isLoading = false;
    });

  } catch (e) {
    setState(() {
      _messages.add(ChatMessage(
        text: "Sorry, something went wrong. Please try again.",
        isUser: false,
      ));
      _isLoading = false;
    });
  }

  _scrollToBottom();
}

bool _needsLocation(String reply) {
  final lower = reply.toLowerCase();
  return lower.contains('location') ||
         lower.contains('where you are') ||
         lower.contains('near you') ||
         lower.contains('your area');
}

Future<bool> _showLocationDialog() async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('📍 Location needed'),
      content: const Text(
        'To find places near you, the assistant needs your location. Allow access?'
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('No thanks'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFB85C38),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Allow'),
        ),
      ],
    ),
  );
  return result ?? false;
}

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('✈️', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Travel Assistant',
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _isLoading ? 'typing...' : 'online',
                  style: TextStyle(
                    color: _isLoading ? _accent : _textLight,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              await FacebookAuth.instance.logOut();

              // show message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Logged out"),
                  duration: Duration(seconds: 2),
                ),
              );

              Future.delayed(const Duration(milliseconds: 500), () {


                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
                });
            },
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(color: _textLight.withOpacity(0.15), height: 1),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) return _buildTyping();
                return _buildBubble(_messages[index]);
              },
            ),
          ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    final isUser = msg.isUser;
    return Padding(
      padding: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isUser ? 64 : 0,
        right: isUser ? 0 : 64,
      ),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('✈️', style: TextStyle(fontSize: 13)),
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? _userBubble : _botBubble,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isUser ? Colors.white : _textDark,
                  fontSize: 14.5,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4, right: 64),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text('✈️', style: TextStyle(fontSize: 13)),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _botBubble,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return _Dot(delay: Duration(milliseconds: i * 200));
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: _bg,
        border: Border(
          top: BorderSide(color: _textLight.withOpacity(0.15)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: _textDark, fontSize: 14.5),
                decoration: InputDecoration(
                  hintText: 'Ask me anything...',
                  hintStyle: TextStyle(color: _textLight.withOpacity(0.7)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: _send,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _isLoading ? _textLight : _accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _accent.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

// Animated typing dot
class _Dot extends StatefulWidget {
  final Duration delay;
  const _Dot({required this.delay});

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
    _anim = Tween(begin: 0.3, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: Container(
        width: 7,
        height: 7,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFB85C38),
        ),
      ),
    );
  }
}