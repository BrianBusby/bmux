package com.bmux;

public record TreeChangedEvent() implements BmuxEvent {
    public String event() {
        return "tree-changed";
    }
}
