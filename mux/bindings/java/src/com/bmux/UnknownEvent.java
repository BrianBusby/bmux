package com.bmux;

import java.util.Map;

public record UnknownEvent(String event, Map<String, Object> raw) implements BmuxEvent {}
