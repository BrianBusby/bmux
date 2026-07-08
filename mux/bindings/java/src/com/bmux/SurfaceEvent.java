package com.bmux;

public record SurfaceEvent(String event, long surface) implements BmuxEvent {}
