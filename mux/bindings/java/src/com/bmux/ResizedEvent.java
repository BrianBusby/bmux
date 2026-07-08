package com.bmux;

public record ResizedEvent(long surface, int cols, int rows, String replay) implements BmuxEvent {
    public String event() {
        return "resized";
    }
}
