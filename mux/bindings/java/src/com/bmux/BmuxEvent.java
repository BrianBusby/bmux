package com.bmux;

import java.util.Map;

public sealed interface BmuxEvent permits TreeChangedEvent, EmptyEvent, SurfaceEvent, SurfaceResizedEvent, VtStateEvent, OutputEvent, ResizedEvent, UnknownEvent {
    String event();

    static BmuxEvent from(Map<String, Object> raw) {
        String event = BmuxClient.asString(raw.get("event"));
        return switch (event) {
            case "tree-changed" -> new TreeChangedEvent();
            case "empty" -> new EmptyEvent();
            case "surface-output", "surface-exited", "title-changed", "bell", "detached" ->
                new SurfaceEvent(event, BmuxClient.asLong(raw.get("surface")));
            case "surface-resized" -> new SurfaceResizedEvent(
                BmuxClient.asLong(raw.get("surface")),
                (int) BmuxClient.asLong(raw.get("cols")),
                (int) BmuxClient.asLong(raw.get("rows"))
            );
            case "vt-state" -> new VtStateEvent(
                BmuxClient.asLong(raw.get("surface")),
                (int) BmuxClient.asLong(raw.get("cols")),
                (int) BmuxClient.asLong(raw.get("rows")),
                BmuxClient.asString(raw.get("data"))
            );
            case "output" -> new OutputEvent(BmuxClient.asLong(raw.get("surface")), BmuxClient.asString(raw.get("data")));
            case "resized" -> new ResizedEvent(
                BmuxClient.asLong(raw.get("surface")),
                (int) BmuxClient.asLong(raw.get("cols")),
                (int) BmuxClient.asLong(raw.get("rows")),
                BmuxClient.asString(raw.get("replay"))
            );
            default -> new UnknownEvent(event, raw);
        };
    }
}
