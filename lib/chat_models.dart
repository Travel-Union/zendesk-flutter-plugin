import 'package:meta/meta.dart';
import 'dart:convert';
import 'dart:io' show Platform;

enum ConnectionStatus {
  CONNECTING,
  RECONNECTING,
  CONNECTED,
  DISCONNECTED,
  FAILED,
  UNREACHABLE,
  UNKNOWN
}

enum AccountStatus {
  UNKNOWN,
  ONLINE,
  OFFLINE,
}

enum ChatItemType {
  UNKNOWN,
  MEMBER_JOIN,
  MEMBER_LEAVE,
  MESSAGE,
  ATTACHMENT_MESSAGE,
  RATING_REQUEST,
  RATING,
  COMMENT,
}

enum ChatRating {
  GOOD,
  BAD,
  UNKNOWN,
}

enum DeliveryStatus {
  CANCELLED,
  DELIVERED,
  FAILED_FILE_SENDING_DISABLED,
  FAILED_FILE_SIZE_TOO_LARGE,
  FAILED_INTERNAL_SERVER_ERROR,
  FAILED_RESPONSE_TIMEOUT,
  FAILED_UNKNOWN_REASON,
  FAILED_UNSUPPORTED_FILE_TYPE,
  PENDING,
  UNKNOWN,
}

enum ChatParticipant {
    VISITOR,
    AGENT,
    TRIGGER,
    SYSTEM,
    UNKNOWN,
}

ConnectionStatus toConnectionStatus(String value) {
  switch (value) {
    case 'unreachable':
    case 'UNREACHABLE':
      return ConnectionStatus.UNREACHABLE;
    case 'reconnecting':
    case 'RECONNECTING':
      return ConnectionStatus.RECONNECTING;
    case 'disconnected':
    case 'DISCONNECTED':
      return ConnectionStatus.DISCONNECTED;
    case 'connecting':
    case 'CONNECTING':
      return ConnectionStatus.CONNECTING;
    case 'connected':
    case 'CONNECTED':
      return ConnectionStatus.CONNECTED;
    case 'failed':
    case 'FAILED':
      return ConnectionStatus.FAILED;
    default:
      return ConnectionStatus.UNKNOWN;
  }
}

AccountStatus toAccountStatus(String value) {
  switch (value) {
    case 'online':
    case 'ONLINE':
      return AccountStatus.ONLINE;
    case 'offline':
    case 'OFFLINE':
      return AccountStatus.OFFLINE;
    default:
      return AccountStatus.UNKNOWN;
  }
}

ChatItemType toChatItemType(String value) {
  switch (value) {
    case 'MEMBER_JOIN':
      return ChatItemType.MEMBER_JOIN;
    case 'MEMBER_LEAVE':
      return ChatItemType.MEMBER_LEAVE;
    case 'MESSAGE':
      return ChatItemType.MESSAGE;
    case 'RATING_REQUEST':
      return ChatItemType.RATING_REQUEST;
    case 'RATING':
      return ChatItemType.RATING;
    case 'COMMENT':
      return ChatItemType.COMMENT;
    case 'ATTACHMENT_MESSAGE':
      return ChatItemType.ATTACHMENT_MESSAGE;
    default:
      return ChatItemType.UNKNOWN;
  }
}

ChatRating toChatRating(String value) {
  switch (value) {
    case 'GOOD':
      return ChatRating.GOOD;
    case 'BAD':
      return ChatRating.BAD;
    default:
      return ChatRating.UNKNOWN;
  }
}

DeliveryStatus toDeliveryStatus(String value) {
  switch (value) {
    case 'CANCELLED':
      return DeliveryStatus.CANCELLED;
    case 'DELIVERED':
      return DeliveryStatus.DELIVERED;
    case 'FAILED_FILE_SENDING_DISABLED':
      return DeliveryStatus.FAILED_FILE_SENDING_DISABLED;
    case 'FAILED_FILE_SIZE_TOO_LARGE':
      return DeliveryStatus.FAILED_FILE_SIZE_TOO_LARGE;
    case 'FAILED_INTERNAL_SERVER_ERROR':
      return DeliveryStatus.FAILED_INTERNAL_SERVER_ERROR;
    case 'FAILED_RESPONSE_TIMEOUT':
      return DeliveryStatus.FAILED_RESPONSE_TIMEOUT;
    case 'FAILED_UNKNOWN_REASON':
      return DeliveryStatus.FAILED_UNKNOWN_REASON;
    case 'FAILED_UNSUPPORTED_FILE_TYPE':
      return DeliveryStatus.FAILED_UNSUPPORTED_FILE_TYPE;
    case 'PENDING':
      return DeliveryStatus.PENDING;
    default:
      return DeliveryStatus.UNKNOWN;
  }
}

ChatParticipant toChatParticipant(String value) {
  switch (value) {
    case 'VISITOR':
      return ChatParticipant.VISITOR;
    case 'AGENT':
      return ChatParticipant.AGENT;
    case 'TRIGGER':
      return ChatParticipant.TRIGGER;
    case 'SYSTEM':
      return ChatParticipant.SYSTEM;
    default:
      return ChatParticipant.UNKNOWN;
  }
}

class AbstractModel {
  final String _id;
  final Map<String, dynamic> _attributes;
  final String _os;

  AbstractModel(this._id, this._attributes, [@visibleForTesting this._os]);

  String get id {
    return _id;
  }

  dynamic attribute(String attrname) {
    return _attributes != null ? _attributes[attrname] : null;
  }

  @visibleForTesting
  String os() {
    return this._os ?? Platform.operatingSystem;
  }

  String toString() => 'id=$_id ${JsonEncoder().convert(_attributes)}';
}

class Agent extends AbstractModel {
  Agent(String id, Map attributes, [@visibleForTesting String os])
      : super(id, attributes, os);

  String get displayName => attribute('display_name');

  String get nick => attribute('nick');

  bool get isTyping => attribute('is_typing');

  String get avatarUri => attribute('avatar_path');

  static List<Agent> parseAgentsJson(String json,
      [@visibleForTesting String os]) {
    var out = List<Agent>();
    print(json);
    jsonDecode(json).forEach((value) {
      out.add(Agent(null, value, os));
    });
    return out;
  }
}

class Attachment extends AbstractModel {
  Attachment(Map attributes, [@visibleForTesting String os])
      : super('', attributes, os);

  String get mimeType {
    return attribute('mime_type');
  }

  String get name {
    return attribute('name');
  }

  int get size {
    return attribute('size');
  }

  String get type {
    return attribute('type');
  }

  String get url {
    return attribute('url');
  }

  String get thumbnailUrl {
    return attribute('thumbnail') ?? attribute('thumbnail_url');
  }
}

class ChatOption extends AbstractModel {
  ChatOption(Map attributes) : super('', attributes);

  String get label {
    return attribute('label');
  }

  bool get selected {
    return attribute('selected');
  }
}

class ChatItem extends AbstractModel {
  ChatItem(Map attrs, [@visibleForTesting String os])
      : super(attrs['id'], attrs, os);

  DateTime get createTimestamp =>
      DateTime.fromMillisecondsSinceEpoch(attribute('create_timestamp'), isUtc: false);

  DateTime get modifyTimestamp =>
      DateTime.fromMillisecondsSinceEpoch(attribute('modify_timestamp'), isUtc: false);

  ChatItemType get type => toChatItemType(attribute('type'));

  DeliveryStatus get deliveryStatus => toDeliveryStatus(attribute('delivery_status'));

  String get displayName => attribute('display_name');
  
  String get nick => attribute('nick');

  ChatParticipant get participant => toChatParticipant(attribute('participant'));

  String get message => attribute('message');

  Attachment get attachment {
    dynamic raw = attribute('attachment');
    return (raw != null && raw is Map) ? Attachment(raw) : null;
  }

  bool get unverified {
    if (os() == 'android') {
      return attribute('unverified');
    } else if (os() == 'ios') {
      bool verified = attribute('verified');
      return verified != null ? !verified : null;
    } else {
      return null;
    }
  }

  bool get failed => attribute('failed');

  String get options {
    var raw = attribute('options');
    if (os() == 'android') {
      return raw;
    } else if (os() == 'ios' && raw != null) {
      return raw.join("/");
    } else {
      return null;
    }
  }

  List<ChatOption> get convertedOptions {
    if (os() == 'android') {
      List<dynamic> raw = attribute('converted_options');
      if (raw == null || raw.isEmpty) {
        return null;
      }
      return raw.map((optionAttrs) => ChatOption(optionAttrs)).toList();
    } else if (os() == 'ios') {
      List<ChatOption> out = List();
      var labels = attribute('options');
      if (labels != null) {
        int selectedOptionIndex = attribute('selectedOptionIndex') ?? -1;
        for (var i = 0; i < labels.length; i++) {
          Map optionAttrs = Map<String, dynamic>();
          optionAttrs['label'] = labels[i];
          optionAttrs['selected'] = (i == selectedOptionIndex);
          out.add(ChatOption(optionAttrs));
        }
      }
      return out;
    } else {
      return null;
    }
  }

  int get uploadProgress => attribute('upload_progress');

  ChatRating get rating => toChatRating(attribute('previous_rating'));

  ChatRating get newRating => toChatRating(attribute('current_rating'));

  String get previousComment => attribute('previous_comment');

  String get newComment => attribute('current_comment');

  static List<ChatItem> parseChatItemsJsonForAndroid(String json,
      [@visibleForTesting String os]) {
    var out = List<ChatItem>();
    jsonDecode(json).forEach((value) {
      out.add(ChatItem(value, os));
    });
    return out;
  }

  static List<ChatItem> parseChatItemsJsonForIOS(String json,
      [@visibleForTesting String os]) {
    var out = List<ChatItem>();
    print(json);
    jsonDecode(json).forEach((value) {
      out.add(ChatItem(value, os));
    });
    return out;
  }
}
