package com.getchange.zendesk_flutter_plugin;

import zendesk.chat.Attachment;

public class ChatAttachmentMetadata {
    public int height;
    public int width;

    ChatAttachmentMetadata(int height, int width) {
        this.height = height;
        this.width = width;
    }

    public static ChatAttachmentMetadata fromMetadata(Attachment.Metadata metadata) {
        int height = metadata.getHeight();
        int width = metadata.getWidth();

        return new ChatAttachmentMetadata(height, width);
    }
}
