import assert from "node:assert/strict";
import test from "node:test";
import site from "../assets/js/site.js";

test("All filter displays every publication", () => {
  assert.equal(site.publicationMatches(["AI Behavior", "Social Computing"], "All"), true);
});

test("a publication displays only for one of its exact tags", () => {
  const tags = ["AI Behavior", "Social Computing"];
  assert.equal(site.publicationMatches(tags, "Social Computing"), true);
  assert.equal(site.publicationMatches(tags, "AI4OceanScience"), false);
});

test("activity toggle labels describe the next action", () => {
  assert.equal(site.activityToggleLabel(false), "Show all activities");
  assert.equal(site.activityToggleLabel(true), "Show fewer activities");
});
