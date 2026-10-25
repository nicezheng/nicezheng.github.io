/* Progressive enhancements for navigation and activity disclosure. */
(function (root) {
  "use strict";

  function activityToggleLabel(isExpanded) {
    return isExpanded ? "Show fewer activities" : "Show all activities";
  }

  function initializeNavigation() {
    const toggle = document.querySelector(".nav-toggle");
    const navigation = document.querySelector(".site-nav");
    if (!toggle || !navigation) return;

    toggle.addEventListener("click", function () {
      const isOpen = toggle.getAttribute("aria-expanded") === "true";
      toggle.setAttribute("aria-expanded", String(!isOpen));
      navigation.classList.toggle("is-open", !isOpen);
    });

    navigation.addEventListener("click", function (event) {
      if (event.target.closest("a")) {
        toggle.setAttribute("aria-expanded", "false");
        navigation.classList.remove("is-open");
      }
    });
  }

  function initializeActivities() {
    const list = document.querySelector("[data-activity-list]");
    const toggle = document.querySelector("[data-activity-toggle]");
    if (!list || !toggle) return;

    const extraItems = Array.from(list.querySelectorAll("[data-extra='true']"));
    if (extraItems.length === 0) return;

    let isExpanded = false;
    toggle.hidden = false;

    function render() {
      extraItems.forEach(function (item) {
        item.hidden = !isExpanded;
      });
      toggle.setAttribute("aria-expanded", String(isExpanded));
      toggle.textContent = activityToggleLabel(isExpanded);
    }

    toggle.addEventListener("click", function () {
      isExpanded = !isExpanded;
      render();
    });

    render();
  }

  const api = { activityToggleLabel };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }

  root.ZhengJiangSite = api;

  if (typeof document !== "undefined") {
    document.addEventListener("DOMContentLoaded", function () {
      initializeNavigation();
      initializeActivities();
    });
  }
})(typeof globalThis !== "undefined" ? globalThis : this);
