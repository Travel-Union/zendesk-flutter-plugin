package com.getchange.zendesk_flutter_plugin;

import android.os.Handler;
import android.os.Looper;
import android.text.TextUtils;

import com.google.gson.GsonBuilder;

import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.PluginRegistry;
import zendesk.chat.Account;
import zendesk.chat.Agent;
import zendesk.chat.Chat;
import zendesk.chat.ChatLog;
import zendesk.chat.ChatProvider;
import zendesk.chat.ChatRating;
import zendesk.chat.ChatState;
import zendesk.chat.ConnectionStatus;
import zendesk.chat.ObservationScope;
import zendesk.chat.Observer;
import zendesk.chat.OfflineForm;
import zendesk.chat.ProfileProvider;
import zendesk.chat.VisitorInfo;

import java.io.File;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;

import static com.google.gson.FieldNamingPolicy.LOWER_CASE_WITH_UNDERSCORES;


public class ZendeskFlutterPlugin implements MethodCallHandler {

  private Handler mainHandler = new Handler(Looper.getMainLooper());
  private PluginRegistry.Registrar registrar;
  private String applicationId = null;

  private ObservationScope connectionScope = null;
  private ObservationScope accountScope = null;
  private ObservationScope chatScope = null;

  private ZendeskFlutterPlugin.EventChannelStreamHandler connectionStreamHandler = new ZendeskFlutterPlugin.EventChannelStreamHandler();
  private ZendeskFlutterPlugin.EventChannelStreamHandler accountStreamHandler = new ZendeskFlutterPlugin.EventChannelStreamHandler();
  private ZendeskFlutterPlugin.EventChannelStreamHandler agentsStreamHandler = new ZendeskFlutterPlugin.EventChannelStreamHandler();
  private ZendeskFlutterPlugin.EventChannelStreamHandler chatItemsStreamHandler = new ZendeskFlutterPlugin.EventChannelStreamHandler();

  private static class EventChannelStreamHandler implements EventChannel.StreamHandler {
    private EventChannel.EventSink eventSink = null;

    public void success(Object event) {
      if (eventSink != null) {
        eventSink.success(event);
      }
    }

    public void error(String errorCode, String errorMessage, Object errorDetails) {
      if (eventSink != null) {
        eventSink.error(errorCode, errorMessage, errorDetails);
      }
    }

    @Override
    public void onListen(Object o, EventChannel.EventSink eventSink) {
      this.eventSink = eventSink;
    }

    @Override
    public void onCancel(Object o) {
      this.eventSink = null;
    }
  }

  public static void registerWith(PluginRegistry.Registrar registrar) {
    final MethodChannel callsChannel = new MethodChannel(registrar.messenger(), "plugins.flutter.zendesk_chat_api/calls");
    final EventChannel connectionStatusEventsChannel = new EventChannel(registrar.messenger(), "plugins.flutter.zendesk_chat_api/connection_status_events");
    final EventChannel accountStatusEventsChannel = new EventChannel(registrar.messenger(),"plugins.flutter.zendesk_chat_api/account_status_events");
    final EventChannel agentEventsChannel = new EventChannel(registrar.messenger(),"plugins.flutter.zendesk_chat_api/agent_events");
    final EventChannel chatItemsEventsChannel = new EventChannel(registrar.messenger(),"plugins.flutter.zendesk_chat_api/chat_items_events");

    ZendeskFlutterPlugin plugin = new ZendeskFlutterPlugin(registrar);

    callsChannel.setMethodCallHandler(plugin);

    connectionStatusEventsChannel.setStreamHandler(plugin.connectionStreamHandler);
    accountStatusEventsChannel.setStreamHandler(plugin.accountStreamHandler);
    agentEventsChannel.setStreamHandler(plugin.agentsStreamHandler);
    chatItemsEventsChannel.setStreamHandler(plugin.chatItemsStreamHandler);
  }

  private ZendeskFlutterPlugin(PluginRegistry.Registrar registrar) {
    this.registrar = registrar;
  }

  @Override
  public void onMethodCall(MethodCall call, MethodChannel.Result result) {
    switch(call.method) {
      case "getPlatformVersion":
        result.success("Android " + android.os.Build.VERSION.RELEASE);
        break;
      case "init":
        applicationId = call.argument("applicationId");
        final String accountKey = call.argument("accountKey");
        try {
          Chat.INSTANCE.init(registrar.activity(), accountKey);
        } catch (Exception e) {
          result.error("UNABLE_TO_INITIALIZE_CHAT_API", e.getMessage(), e);
          break;
        }
        result.success(null);
        break;
      case "startChat":
        ProfileProvider profileProvider = Chat.INSTANCE.providers().profileProvider();
        ChatProvider chatProvider = Chat.INSTANCE.providers().chatProvider();

        VisitorInfo visitorInfo = VisitorInfo.builder()
                .withPhoneNumber(call.argument("visitorPhone"))
                .withEmail(call.argument("visitorEmail"))
                .withName(call.argument("visitorName"))
                .build();

        profileProvider.setVisitorInfo(visitorInfo, null);

        String department = call.argument("department");
        String tags = call.argument("tags");

        if (!TextUtils.isEmpty(department)) {
          chatProvider.setDepartment(department, null);
        }
        if (!TextUtils.isEmpty(tags)) {
          profileProvider.addVisitorTags(Arrays.asList(tags.split(",")), null);
        }

        bindChatListeners();

        Chat.INSTANCE.providers().connectionProvider().connect();

        result.success(null);
        break;
      case "endChat":
          unbindChatListeners();
          Chat.INSTANCE.providers().chatProvider().endChat(null);
          result.success(null);
        break;
      case "sendMessage":
        if (Chat.INSTANCE.providers().connectionProvider().getConnectionStatus() != ConnectionStatus.CONNECTED) {
          result.error("CHAT_NOT_STARTED", null, null);
        } else {
          String message = call.argument("message");
          Chat.INSTANCE.providers().chatProvider().sendMessage(message);
          result.success(null);
        }
        break;
      case "resendMessage":
        if (Chat.INSTANCE.providers().connectionProvider().getConnectionStatus() != ConnectionStatus.CONNECTED) {
          result.error("CHAT_NOT_STARTED", null, null);
        } else {
          String messageId = call.argument("messageId");
          Chat.INSTANCE.providers().chatProvider().resendFailedMessage(messageId);
          result.success(null);
        }
        break;
      case "sendComment":
        if (Chat.INSTANCE.providers().connectionProvider().getConnectionStatus() != ConnectionStatus.CONNECTED) {
          result.error("CHAT_NOT_STARTED", null, null);
        } else {
          String comment = call.argument("comment");
          Chat.INSTANCE.providers().chatProvider().sendChatComment(comment, null);
          result.success(null);
        }
        break;
      case "sendAttachment":
        if (Chat.INSTANCE.providers().connectionProvider().getConnectionStatus() != ConnectionStatus.CONNECTED) {
          result.error("CHAT_NOT_STARTED", null, null);
        } else {
          String pathname = call.argument("pathname");
          if (TextUtils.isEmpty(pathname)) {
            result.error("ATTACHMENT_EMPTY_PATHNAME", null, null);
            return;
          }
          File file = new File(pathname);
          if (!file.isFile()) {
            result.error("ATTACHMENT_NOT_FILE", null, null);
            return;
          }
          Chat.INSTANCE.providers().chatProvider().sendFile(file, null);
          result.success(null);
        }
        break;
      case "sendChatRating": {
        if (Chat.INSTANCE.providers().connectionProvider().getConnectionStatus() != ConnectionStatus.CONNECTED) {
          result.error("CHAT_NOT_STARTED", null, null);
          return;
        }
        ChatRating chatLogRating = null;
        ChatProvider provider = Chat.INSTANCE.providers().chatProvider();
        String rating = call.argument("rating");
        if (!TextUtils.isEmpty(rating)) {
          chatLogRating = toChatLogRating(rating);
        }

        if (chatLogRating != null) {
          provider.sendChatRating(chatLogRating, null);
        }

        String comment = call.argument("comment");
        if (!TextUtils.isEmpty(comment)) {
          provider.sendChatComment(comment, null);
        }
        result.success(null);
        break;
      }
      case "sendOfflineMessage":
        if (Chat.INSTANCE.providers().connectionProvider().getConnectionStatus() != ConnectionStatus.CONNECTED) {
          result.error("CHAT_NOT_STARTED", null, null);
          return;
        }
        VisitorInfo info = Chat.INSTANCE.providers().profileProvider().getVisitorInfo();
        if (TextUtils.isEmpty(info.getEmail())) {
          result.error("VISITOR_EMAIL_MUST_BE PROVIDED", null, null);
          return;
        }

        Chat.INSTANCE.providers().chatProvider().sendOfflineForm(OfflineForm.builder(call.argument("message")).withVisitorInfo(info).build(), null);

        result.success(null);

        break;
      default:
        result.notImplemented();
    }
  }

  private void bindChatListeners() {
    unbindChatListeners();

    connectionScope = new ObservationScope();
    Chat.INSTANCE.providers().connectionProvider().observeConnectionStatus(connectionScope, new Observer<ConnectionStatus>() {
      @Override
      public void update(ConnectionStatus status) {
        mainHandler.post(() -> {
          connectionStreamHandler.success(status.name());
        });
      }
    });

    accountScope = new ObservationScope();
    Chat.INSTANCE.providers().accountProvider().observeAccount(accountScope, new Observer<Account>() {
      @Override
      public void update(Account account) {
        mainHandler.post(() -> {
          accountStreamHandler.success(account.getStatus().name());
        });
      }
    });

    chatScope = new ObservationScope();
    Chat.INSTANCE.providers().chatProvider().observeChatState(chatScope, new Observer<ChatState>() {
      @Override
      public void update(ChatState chatState) {
        List<ChatAgent> agents = new ArrayList<>();

        for (Agent agent: chatState.getAgents()) {
          agents.add(ChatAgent.fromAgent(agent));
        }

        mainHandler.post(() -> {
          agentsStreamHandler.success(toJson(agents));
        });

        List<ChatLogEvent> chatLogs = new ArrayList<>();

        for (ChatLog chatLog: chatState.getChatLogs()) {
          chatLogs.add(ChatLogEvent.fromChatLog(chatLog));
        }

        mainHandler.post(() -> {
          chatItemsStreamHandler.success(toJson(chatLogs));
        });
      }
    });
  }

  private void unbindChatListeners() {
    if (connectionScope != null && !connectionScope.isCancelled()) {
      connectionScope.cancel();
      connectionScope = null;
    }
    if (chatScope != null && !chatScope.isCancelled()) {
      chatScope.cancel();
      chatScope = null;
    }
    if (accountScope != null && !accountScope.isCancelled()) {
      accountScope.cancel();
      accountScope = null;
    }
  }

  private String toJson(Object object) {
    return new GsonBuilder()
        .setFieldNamingPolicy(LOWER_CASE_WITH_UNDERSCORES)
        .create()
        .toJson(object)
        .replaceAll("\\$(string|int|bool)\":", "\":");
  }

  private ChatRating toChatLogRating(String rating) {
    switch (rating) {
      case "ChatRating.GOOD":
        return ChatRating.GOOD;
      case "ChatRating.BAD":
        return ChatRating.BAD;
      default:
        return null;
    }
  }
}
