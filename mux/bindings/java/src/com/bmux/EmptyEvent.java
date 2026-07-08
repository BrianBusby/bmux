package com.bmux;

public record EmptyEvent() implements BmuxEvent {
    public String event() {
        return "empty";
    }
}
