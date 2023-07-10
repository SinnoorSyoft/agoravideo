import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../config.dart';

class HomeView extends StatefulWidget {
  const HomeView({Key? key}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late RtcEngine agoraEngine;
  String channelName = 'test';

  int uid = 0;

  bool _isHost = true;
  bool _isJoined = false;
  int? _remoteUid;

  @override
  void dispose() async {
    await agoraEngine.leaveChannel();
    agoraEngine.release();
    super.dispose();
  }

  showMessage(String message) {
    Get.snackbar(
      'Agora Video Call',
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  Future<void> setupVideoSDKEngine() async {
    // retrieve or request camera and microphone permissions
    try {
      await [Permission.microphone, Permission.camera].request();
      agoraEngine = createAgoraRtcEngine();
      await agoraEngine.initialize(const RtcEngineContext(appId: Config.appId));
      await agoraEngine.enableVideo();
      setState(() {
        _isJoined = true;
      });

      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          showMessage("Local user uid:${connection.localUid} joined the channel");
          setState(() {
            _isJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          showMessage("Remote user uid:$remoteUid joined the channel");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          showMessage("Remote user uid:$remoteUid left the channel");
          setState(() {
            _remoteUid = null;
          });
        },
        onError: (err, msg) => showMessage(msg),
      );
    } catch (e) {
      Get.log(e.toString());
    }
  }

  void join() async {
    // Set channel options
    try {
      ChannelMediaOptions options;

      // Set channel profile and client role
      if (_isHost) {
        options = const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        );
        await agoraEngine.startPreview();
      } else {
        options = const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        );
      }

      await agoraEngine.joinChannel(
        token: Config.tempToken,
        channelId: channelName,
        options: options,
        uid: uid,
      );
    } catch (e) {
      Get.log(e.toString());
    }
  }

  void leave() {
    setState(() {
      _isJoined = false;
      _remoteUid = null;
    });
    agoraEngine.leaveChannel();
  }

  void _handleRadioValueChange(bool? value) async {
    setState(() {
      _isHost = value!;
    });
    if (_isJoined) leave();
  }

  Widget _videoPanel() {
    if (!_isJoined) {
      return const Text(
        'Join a channel',
        textAlign: TextAlign.center,
      );
    } else if (_isHost) {
      // Show local video preview
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: agoraEngine,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    } else {
      // Show remote video
      if (_remoteUid != null) {
        return AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: agoraEngine,
            canvas: VideoCanvas(uid: _remoteUid),
            connection: RtcConnection(channelId: channelName),
          ),
        );
      } else {
        return const Text(
          'Waiting for a host to join',
          textAlign: TextAlign.center,
        );
      }
    }
  }

  @override
  void initState() {
    setupVideoSDKEngine();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Get.log('isHost: $_isHost, isJoined: $_isJoined, remoteUid: $_remoteUid');
    return Scaffold(
      appBar: AppBar(
        title: const Text('HomeView'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          // Container for the local video
          Container(
            height: 240,
            decoration: BoxDecoration(border: Border.all()),
            child: Center(child: _videoPanel()),
          ),
          // Radio Buttons
          Row(children: <Widget>[
            Radio<bool>(
              value: true,
              groupValue: _isHost,
              onChanged: (value) => _handleRadioValueChange(value),
            ),
            const Text('Host'),
            Radio<bool>(
              value: false,
              groupValue: _isHost,
              onChanged: (value) => _handleRadioValueChange(value),
            ),
            const Text('Audience'),
          ]),
          // Button Row
          Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton(
                  child: const Text("Join"),
                  onPressed: () => join(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  child: const Text("Leave"),
                  onPressed: () => leave(),
                ),
              ),
            ],
          ),
          // Button Row ends
        ],
      ),
    );
  }
}
