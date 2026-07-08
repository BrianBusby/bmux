package com.bmux;

import java.util.Map;

public record Size(int cols, int rows) {
    static Size from(Map<String, Object> data) {
        return new Size((int) BmuxClient.asLong(data.get("cols")), (int) BmuxClient.asLong(data.get("rows")));
    }
}
