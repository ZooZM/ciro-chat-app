class SocketEvents {
  // Listen events
  static const String messageSent = 'messageSent';
  static const String messageDelivered = 'messageDelivered';
  static const String messageRead = 'messageRead';
  static const String receiveMessage = 'receiveMessage';
  static const String newMessage = 'newMessage';
  static const String userTyping = 'userTyping';
  static const String incomingCall = 'incomingCall';
  static const String callAccepted = 'callAccepted';
  static const String callRejected = 'callRejected';
  static const String callError = 'callError';
  static const String callEnded = 'callEnded';
  static const String userStatus = 'userStatus';
  static const String statusReceived = 'statusReceived';
  static const String messageDeleted = 'messageDeleted';

  // Group call — server → client
  static const String incomingGroupCall = 'incomingGroupCall';
  static const String groupCallParticipantJoined = 'groupCallParticipantJoined';
  static const String groupCallParticipantLeft = 'groupCallParticipantLeft';
  static const String groupCallRecordingStateChanged = 'groupCallRecordingStateChanged';
  // FR-038: active-call state (broadcast on start/end; replayed on socket reconnect)
  static const String groupCallActive = 'groupCallActive';
  static const String groupCallEnded = 'groupCallEnded';

  // Emit events
  static const String joinRoom = 'joinRoom';
  static const String typing = 'typing';
  static const String sendMessage = 'sendMessage';
  static const String markDelivered = 'markDelivered';
  static const String markRead = 'markRead';
  static const String requestCall = 'requestCall';
  static const String acceptCall = 'acceptCall';
  static const String rejectCall = 'rejectCall';
  static const String endCall = 'endCall';
  static const String uploadStatus = 'uploadStatus';
  static const String statusViewed = 'statusViewed';
  static const String deleteForEveryone = 'deleteForEveryone';

  // Group call — client → server
  static const String requestGroupCall = 'requestGroupCall';
  static const String acceptGroupCall = 'acceptGroupCall';
  static const String declineGroupCall = 'declineGroupCall';
  static const String leaveGroupCall = 'leaveGroupCall';
}
