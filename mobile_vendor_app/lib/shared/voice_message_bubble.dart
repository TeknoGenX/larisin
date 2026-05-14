import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'app_theme.dart';

class VoiceMessageBubble extends StatefulWidget {
  final String url;
  final bool isMe;

  const VoiceMessageBubble({super.key, required this.url, required this.isMe});

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  final String _baseUrl = 'http://127.0.0.1:5003';

  @override
  void initState() {
    super.initState();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlaying = state == PlayerState.playing);
      }
    });
    _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() => _duration = newDuration);
      }
    });
    _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() => _position = newPosition);
      }
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _playPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      String fullUrl = widget.url.startsWith('http') ? widget.url : '$_baseUrl${widget.url}';
      await _audioPlayer.play(UrlSource(fullUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            _isPlaying ? Icons.pause : Icons.play_arrow,
            color: widget.isMe ? Colors.white : AppTheme.primaryIndigo,
          ),
          onPressed: _playPause,
        ),
        Expanded(
          child: Slider(
            activeColor: widget.isMe ? Colors.white : AppTheme.primaryIndigo,
            inactiveColor: widget.isMe ? Colors.white24 : Colors.grey[300],
            value: _position.inMilliseconds.toDouble(),
            max: _duration.inMilliseconds.toDouble() > 0 
                ? _duration.inMilliseconds.toDouble() 
                : 1.0,
            onChanged: (value) async {
              await _audioPlayer.seek(Duration(milliseconds: value.toInt()));
            },
          ),
        ),
        Text(
          _formatDuration(_duration - _position),
          style: TextStyle(
            fontSize: 10,
            color: widget.isMe ? Colors.white70 : Colors.grey,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }
}
