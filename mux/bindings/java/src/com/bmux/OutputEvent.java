package com.bmux;

public record OutputEvent(long surface, String data) implements BmuxEvent {
    public String event() {
        return "output";
    }
}
