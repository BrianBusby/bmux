package com.bmux;

public final class BmuxTransportException extends BmuxException {
    public BmuxTransportException(String message, Throwable cause) {
        super(message, cause);
    }

    public BmuxTransportException(String message) {
        super(message);
    }
}
