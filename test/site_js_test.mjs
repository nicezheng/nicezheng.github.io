import assert from "node:assert/strict";
import test from "node:test";
import site from "../assets/js/site.js";

test("activity toggle labels describe the next action", () => {
  assert.equal(site.activityToggleLabel(false), "Show all activities");
  assert.equal(site.activityToggleLabel(true), "Show fewer activities");
});
