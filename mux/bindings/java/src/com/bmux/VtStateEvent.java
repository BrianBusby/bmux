package com.bmux;

public record VtStateEvent(long surface, int cols, int rows, String data) implements BmuxEvent {
    public String event() {
        return "vt-state";
    }
}
