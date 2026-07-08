import { describe, expect, test } from "bun:test";
import {
  appPricingCheckoutURL,
  withCheckoutExternalBrowserIntent,
} from "../app/lib/billing";

describe("billing links", () => {
  test("marks relative checkout URLs for system-browser handoff", () => {
    expect(withCheckoutExternalBrowserIntent("/api/billing/checkout")).toBe(
      "/api/billing/checkout?bmux_external_browser=1",
    );
  });

  test("preserves existing query strings and hash fragments", () => {
    expect(
      withCheckoutExternalBrowserIntent(
        "https://bmux.com/api/billing/checkout?plan=pro#pay",
      ),
    ).toBe(
      "https://bmux.com/api/billing/checkout?plan=pro&bmux_external_browser=1#pay",
    );
  });

  test("app pricing checkout uses the request origin", () => {
    expect(appPricingCheckoutURL("pro", "http://localhost:9210")).toBe(
      "http://localhost:9210/api/billing/checkout?plan=pro&bmux_external_browser=1",
    );
    expect(appPricingCheckoutURL("team", "https://bmux.com")).toBe(
      "https://bmux.com/api/billing/checkout?plan=team&bmux_external_browser=1",
    );
  });

  test("app pricing checkout can carry the native callback scheme", () => {
    expect(appPricingCheckoutURL("pro", "http://localhost:9210", "bmux-dev-test")).toBe(
      "http://localhost:9210/api/billing/checkout?plan=pro&bmux_external_browser=1&bmux_scheme=bmux-dev-test",
    );
  });

  test("app pricing checkout keeps an explicit origin override", () => {
    const previous = process.env.BMUX_APP_PRICING_CHECKOUT_URL;
    process.env.BMUX_APP_PRICING_CHECKOUT_URL = "https://billing.example/checkout";
    try {
      expect(appPricingCheckoutURL("pro", "http://localhost:9210")).toBe(
        "https://billing.example/checkout?plan=pro&bmux_external_browser=1",
      );
    } finally {
      if (previous === undefined) {
        delete process.env.BMUX_APP_PRICING_CHECKOUT_URL;
      } else {
        process.env.BMUX_APP_PRICING_CHECKOUT_URL = previous;
      }
    }
  });
});
