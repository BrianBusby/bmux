package com.bmux;

import java.util.Map;

public record IdentifyResult(String app, String version, int protocol, String session, long pid) {
    static IdentifyResult from(Map<String, Object> data) {
        return new IdentifyResult(
            BmuxClient.asString(data.get("app")),
            BmuxClient.asString(data.get("version")),
            (int) BmuxClient.asLong(data.get("protocol")),
            BmuxClient.asString(data.get("session")),
            BmuxClient.asLong(data.get("pid"))
        );
    }
}
