package com.bmux;

import java.util.Map;

public record Tab(long surface, String kind, String browserSource, String name, String title, Size size, boolean dead) {
    @SuppressWarnings("unchecked")
    static Tab from(Map<String, Object> data) {
        Size size = data.get("size") instanceof Map<?, ?> rawSize
            ? Size.from((Map<String, Object>) rawSize)
            : null;
        return new Tab(
            BmuxClient.asLong(data.get("surface")),
            BmuxClient.asString(data.get("kind")),
            data.get("browser_source") == null ? null : BmuxClient.asString(data.get("browser_source")),
            data.get("name") == null ? null : BmuxClient.asString(data.get("name")),
            BmuxClient.asString(data.get("title")),
            size,
            Boolean.TRUE.equals(data.get("dead"))
        );
    }
}
