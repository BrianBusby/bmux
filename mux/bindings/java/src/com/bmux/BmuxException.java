package com.bmux;

public class BmuxException extends Exception {
    public BmuxException(String message) {
        super(message);
    }

    public BmuxException(String message, Throwable cause) {
        super(message, cause);
    }
}
