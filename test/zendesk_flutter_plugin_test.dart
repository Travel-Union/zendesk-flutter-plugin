import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zendesk_flutter_plugin/zendesk_flutter_plugin.dart';
import 'package:zendesk_flutter_plugin/chat_models.dart';

void main() {
  const MethodChannel channel =
      MethodChannel('plugins.flutter.zendesk_chat_api/calls');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await ZendeskFlutterPlugin().platformVersion, '42');
  });

  group('Model tests', () {
    test('properly converts to ConnectionStatus', () {
      expect(toConnectionStatus('failed'), ConnectionStatus.FAILED);
      expect(toConnectionStatus('FAILED'), ConnectionStatus.FAILED);
      expect(toConnectionStatus('unreachable'), ConnectionStatus.UNREACHABLE);
      expect(toConnectionStatus('UNREACHABLE'), ConnectionStatus.UNREACHABLE);
      expect(toConnectionStatus('reconnecting'), ConnectionStatus.RECONNECTING);
      expect(toConnectionStatus('RECONNECTING'), ConnectionStatus.RECONNECTING);
      expect(toConnectionStatus('disconnected'), ConnectionStatus.DISCONNECTED);
      expect(toConnectionStatus('DISCONNECTED'), ConnectionStatus.DISCONNECTED);
      expect(toConnectionStatus('connecting'), ConnectionStatus.CONNECTING);
      expect(toConnectionStatus('CONNECTING'), ConnectionStatus.CONNECTING);
      expect(toConnectionStatus('connected'), ConnectionStatus.CONNECTED);
      expect(toConnectionStatus('CONNECTED'), ConnectionStatus.CONNECTED);
      expect(toConnectionStatus('other_status'), ConnectionStatus.UNKNOWN);
      expect(toConnectionStatus(null), ConnectionStatus.UNKNOWN);
      expect(toConnectionStatus(''), ConnectionStatus.UNKNOWN);
    });

    test('properly converts to AccountStatus', () {
      expect(toAccountStatus('online'), AccountStatus.ONLINE);
      expect(toAccountStatus('ONLINE'), AccountStatus.ONLINE);
      expect(toAccountStatus('offline'), AccountStatus.OFFLINE);
      expect(toAccountStatus('OFFLINE'), AccountStatus.OFFLINE);
      expect(toAccountStatus('other_status'), AccountStatus.UNKNOWN);
      expect(toAccountStatus(null), AccountStatus.UNKNOWN);
      expect(toAccountStatus(''), AccountStatus.UNKNOWN);
    });

    test('properly converts to ChatItemType', () {
      expect(toChatItemType('MEMBER_JOIN'), ChatItemType.MEMBER_JOIN);
      expect(toChatItemType('MEMBER_LEAVE'), ChatItemType.MEMBER_LEAVE);
      expect(toChatItemType('MESSAGE'), ChatItemType.MESSAGE);
      expect(toChatItemType('RATING_REQUEST'), ChatItemType.RATING_REQUEST);
      expect(toChatItemType('RATING'), ChatItemType.RATING);
      expect(toChatItemType('COMMENT'), ChatItemType.COMMENT);
      expect(toChatItemType('ATTACHMENT_MESSAGE'), ChatItemType.ATTACHMENT_MESSAGE);
      expect(toChatItemType(null), ChatItemType.UNKNOWN);
      expect(toChatItemType(''), ChatItemType.UNKNOWN);
    });

    test('properly converts to ChatRating', () {
      expect(toChatRating('good'), ChatRating.GOOD);
      expect(toChatRating('bad'), ChatRating.BAD);
      expect(toChatRating(null), ChatRating.UNKNOWN);
      expect(toChatRating(''), ChatRating.UNKNOWN);
      expect(toChatRating('other'), ChatRating.UNKNOWN);
    });

    test('properly parses Agents json for Android', () {
      String json =
          '{"2": {"display_name":"aaaa", "avatar_path":"bbbb", "typing":true}, "1": {"display_name":"cccc", "avatar_path":"dddd", "typing":false}}';
      List<Agent> agents = Agent.parseAgentsJson(json, 'android');

      expect(2, agents.length);

      expect(agents[0].id, '2');
      expect(agents[0].displayName, 'aaaa');
      expect(agents[0].avatarUri, 'bbbb');
      expect(agents[0].isTyping, true);

      expect(agents[1].id, '1');
      expect(agents[1].displayName, 'cccc');
      expect(agents[1].avatarUri, 'dddd');
      expect(agents[1].isTyping, false);
    });

    test('properly parses Agents json for iOS', () {
      String json =
          '{"2": {"displayName":"aaaa", "avatarURL":"bbbb", "typing":true}, "1": {"displayName":"cccc", "avatarURL":"dddd", "typing":false}}';
      List<Agent> agents = Agent.parseAgentsJson(json, 'ios');

      expect(agents.length, 2);

      expect(agents[0].id, '2');
      expect(agents[0].displayName, 'aaaa');
      expect(agents[0].avatarUri, 'bbbb');
      expect(agents[0].isTyping, true);

      expect(agents[1].id, '1');
      expect(agents[1].displayName, 'cccc');
      expect(agents[1].avatarUri, 'dddd');
      expect(agents[1].isTyping, false);
    });

    test('properly converts map to Attachment', () {
      Map map = Map<String, dynamic>();
      map['mime_type'] = 'aaa';
      map['name'] = 'bbb';
      map['size'] = 1;
      map['type'] = 'ccc';
      map['url'] = 'ddd';
      map['thumbnail_url'] = 'eee';

      Attachment attachment = Attachment(map);
      expect(attachment.mimeType, 'aaa');
      expect(attachment.name, 'bbb');
      expect(attachment.size, 1);
      expect(attachment.type, 'ccc');
      expect(attachment.url, 'ddd');
      expect(attachment.thumbnailUrl, 'eee');
    });

    test('properly converts map to ChatOption', () {
      Map map = Map<String, dynamic>();
      map['label'] = "aaa";
      map['selected'] = true;

      ChatOption attachment = ChatOption(map);
      expect(attachment.label, 'aaa');
      expect(attachment.selected, true);
    });

    test('properly parses ChatItems json for Android', () {
      DateTime now = DateTime.now();
      List<ChatItem> items = ChatItem.parseChatItemsJsonForAndroid(
          '{"1":{"createTimestamp":${now.millisecondsSinceEpoch}, "modifyTimestamp":${now.millisecondsSinceEpoch}, "type":"MESSAGE", "displayName":"aaa", "message":"bbb", "nick":"ccc", '
              '"attachment":{"mime_type":"ddd", "name":"eee", "size":1, "type":"fff", "url":"ggg", "thumbnail":"hhh"}, "unverified":true, "failed": false, "options":"yes/no",'
              '"converted_options":[{"label":"yes", "selected":false},{"label":"no", "selected":true}], "upload_progress":0, "rating":"bad", "new_rating":"good", "new_comment":"comment line"}}',
          'android');

      expect(items.length, 1);

      expect(items[0].id, "1");
      expect(items[0].createTimestamp.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
      expect(items[0].modifyTimestamp.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
      expect(items[0].type, ChatItemType.MESSAGE);
      expect(items[0].displayName, 'aaa');
      expect(items[0].message, 'bbb');
      expect(items[0].nick, 'ccc');
      expect(items[0].unverified, true);
      expect(items[0].failed, false);
      expect(items[0].options, 'yes/no');
      expect(items[0].uploadProgress, 0);
      expect(items[0].rating, ChatRating.BAD);
      expect(items[0].newRating, ChatRating.GOOD);
      expect(items[0].newComment, 'comment line');

      Attachment attachment = items[0].attachment;
      expect(attachment != null, true);
      expect(attachment.mimeType, 'ddd');
      expect(attachment.name, 'eee');
      expect(attachment.size, 1);
      expect(attachment.type, 'fff');
      expect(attachment.thumbnailUrl, 'hhh');

      List<ChatOption> convertedOptions = items[0].convertedOptions;
      expect(convertedOptions != null, true);
      expect(convertedOptions.length, 2);
      expect(convertedOptions[0].label, 'yes');
      expect(convertedOptions[0].selected, false);
      expect(convertedOptions[1].label, 'no');
      expect(convertedOptions[1].selected, true);
    });

    test('properly parses ChatItems json for iOS', () {
      DateTime now = DateTime.now();
      List<ChatItem> items = ChatItem.parseChatItemsJsonForIOS(
          '[{"id":"1", "createTimestamp":${now.millisecondsSinceEpoch}, "modifyTimestamp":${now.millisecondsSinceEpoch}, "type":"MESSAGE", "displayName":"aaa", "msg":"bbb", "nick":"ccc", '
              '"attachment":{"mime_type":"ddd", "name":"eee", "size":1, "type":"fff", "url":"ggg", "thumbnail_url":"hhh"}, "verified":false, "failed": false, "options":["yes","no"],'
              '"selectedOptionIndex":1, "upload_progress":0, "rating":"bad", "new_rating":"good", "new_comment":"comment line"}]',
          'ios');

      expect(items.length, 1);

      expect(items[0].id, "1");
      expect(items[0].createTimestamp.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
      expect(items[0].modifyTimestamp.millisecondsSinceEpoch,
          now.millisecondsSinceEpoch);
      expect(items[0].type, ChatItemType.MESSAGE);
      expect(items[0].displayName, 'aaa');
      expect(items[0].message, 'bbb');
      expect(items[0].nick, 'ccc');
      expect(items[0].unverified, true);
      expect(items[0].failed, false);
      expect(items[0].options, 'yes/no');
      expect(items[0].uploadProgress, 0);
      expect(items[0].rating, ChatRating.BAD);
      expect(items[0].newRating, ChatRating.GOOD);
      expect(items[0].newComment, 'comment line');

      Attachment attachment = items[0].attachment;
      expect(attachment != null, true);
      expect(attachment.mimeType, 'ddd');
      expect(attachment.name, 'eee');
      expect(attachment.size, 1);
      expect(attachment.type, 'fff');
      expect(attachment.thumbnailUrl, 'hhh');

      List<ChatOption> convertedOptions = items[0].convertedOptions;
      expect(convertedOptions != null, true);
      expect(convertedOptions.length, 2);
      expect(convertedOptions[0].label, 'yes');
      expect(convertedOptions[0].selected, false);
      expect(convertedOptions[1].label, 'no');
      expect(convertedOptions[1].selected, true);
    });
  });
}
