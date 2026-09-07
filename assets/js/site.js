/* Progressive enhancements for navigation, activity disclosure, and filters. */
(function (root) {
  "use strict";

  function publicationMatches(tags, activeTag) {
    return activeTag === "All" || tags.includes(activeTag);
  }

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

  function initializePublicationFilters() {
    const buttons = Array.from(document.querySelectorAll("[data-filter]"));
    const publications = Array.from(document.querySelectorAll(".publication-item"));
    const status = document.querySelector("[data-filter-status]");
    if (buttons.length === 0 || publications.length === 0 || !status) return;

    function applyFilter(activeTag) {
      let visibleCount = 0;

      publications.forEach(function (publication) {
        const tags = publication.dataset.tags.split("|").filter(Boolean);
        const isVisible = publicationMatches(tags, activeTag);
        publication.hidden = !isVisible;
        if (isVisible) visibleCount += 1;
      });

      buttons.forEach(function (button) {
        const isActive = button.dataset.filter === activeTag;
        button.classList.toggle("is-active", isActive);
        button.setAttribute("aria-pressed", String(isActive));
      });

      status.textContent = activeTag === "All"
        ? `Showing all ${visibleCount} publications.`
        : `Showing ${visibleCount} ${activeTag} publication${visibleCount === 1 ? "" : "s"}.`;
    }

    buttons.forEach(function (button) {
      button.addEventListener("click", function () {
        applyFilter(button.dataset.filter);
      });
    });
  }

  const api = { publicationMatches, activityToggleLabel };

  if (typeof module !== "undefined" && module.exports) {
    module.exports = api;
  }

  root.ZhengJiangSite = api;

  if (typeof document !== "undefined") {
    document.addEventListener("DOMContentLoaded", function () {
      initializeNavigation();
      initializeActivities();
      initializePublicationFilters();
    });
  }
})(typeof globalThis !== "undefined" ? globalThis : this);
