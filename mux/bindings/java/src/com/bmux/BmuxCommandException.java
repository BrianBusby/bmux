package com.bmux;

public final class BmuxCommandException extends BmuxException {
    private final String serverMessage;
    private final Object commandId;

    public BmuxCommandException(String serverMessage, Object commandId) {
        super(serverMessage);
        this.serverMessage = serverMessage;
        this.commandId = commandId;
    }

    public String serverMessage() {
        return serverMessage;
    }

    public Object commandId() {
        return commandId;
    }
}
