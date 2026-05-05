import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:ciro_chat_app/core/routing/app_router.dart';
import '../bloc/call_cubit.dart';

class OutgoingCallScreen extends StatelessWidget {
  final String contactName;
  final String avatarUrl;

  const OutgoingCallScreen({
    super.key,
    required this.contactName,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<CallCubit, CallState>(
      listener: (context, state) {
        if (state is CallActive) {
          final initials = state.contactName.isNotEmpty 
              ? (state.contactName.length >= 2 ? state.contactName.substring(0, 2).toUpperCase() : state.contactName[0].toUpperCase()) 
              : 'AK';
              
          if (state.isVideo) {
            context.pushReplacement(AppRouterName.videoCall, extra: {
              'contactName': state.contactName,
              'livekitUrl': state.livekitUrl,
              'livekitToken': state.livekitToken,
            });
          } else {
            context.pushReplacement(AppRouterName.voiceCall, extra: {
              'contactName': state.contactName,
              'avatarInitials': initials,
              'livekitUrl': state.livekitUrl,
              'livekitToken': state.livekitToken,
            });
          }
        } else if (state is CallEnded || state is CallIdle) {
          if (state is CallEnded && state.reason == 'rejected') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Call was rejected by the receiver.', style: TextStyle(color: Colors.white)),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 3),
              ),
            );
          }
          Navigator.pop(context); // Go back if rejected or canceled
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[800],
                backgroundImage: avatarUrl.isNotEmpty ? CachedNetworkImageProvider(avatarUrl) : null,
                child: avatarUrl.isEmpty
                    ? Text(
                        contactName.isNotEmpty ? contactName[0].toUpperCase() : '?',
                        style: const TextStyle(fontSize: 48, color: Colors.white),
                      )
                    : null,
              ),
              const SizedBox(height: 30),
              Text(
                'Calling $contactName...',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Ringing...',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 80),
              IconButton(
                iconSize: 40,
                padding: const EdgeInsets.all(20),
                style: IconButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.call_end, color: Colors.white),
                onPressed: () {
                  context.read<CallCubit>().endCall();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
