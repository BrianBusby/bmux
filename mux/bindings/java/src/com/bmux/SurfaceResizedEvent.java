package com.bmux;

public record SurfaceResizedEvent(long surface, int cols, int rows) implements BmuxEvent {
    public String event() {
        return "surface-resized";
    }
}
