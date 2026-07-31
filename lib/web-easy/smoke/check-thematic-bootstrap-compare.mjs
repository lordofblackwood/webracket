#!/usr/bin/env node

import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { installPlaywrightErrorGuard } from "./playwright-error-guard.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(scriptDir, "../../..");
const baseUrl =
  process.env.THEMATIC_COMPARE_URL ||
  `${process.env.SMOKE_BASE_URL || "http://127.0.0.1:8765"}/test-browser-theme-thematic-bootstrap-compare.html`;
const themes = (process.env.THEMATIC_COMPARE_THEMES || "lux,sketchy,sandstone")
  .split(",")
  .map((theme) => theme.trim())
  .filter(Boolean);
const themeSpecs = {
  superhero: { bootstrap: "superhero", web: "superhero", label: "Superhero" },
  sketchy: { bootstrap: "sketchy", web: "sketchy", label: "Sketchy" },
  lux: { bootstrap: "lux", web: "lux", label: "Lux" },
  "lux-boost": { bootstrap: "lux", web: "lux-boost", label: "Lux Boost" },
  sandstone: { bootstrap: "sandstone", web: "sandstone", label: "Sandstone" },
  "sandstone-boost": { bootstrap: "sandstone", web: "sandstone-boost", label: "Sandstone Boost" }
};
const profile = (process.env.THEMATIC_COMPARE_PROFILE || "focused").trim().toLowerCase();
const verbose = process.env.THEMATIC_COMPARE_VERBOSE === "1";
const failOnDiffs = process.env.THEMATIC_COMPARE_FAIL_ON_DIFFS === "1" ||
  (process.env.THEMATIC_COMPARE_FAIL_ON_DIFFS !== "0" && profile === "focused");

async function loadPlaywright() {
  try {
    return await import("playwright");
  } catch (_e) {
    if (process.env.SMOKE_NODE_MODULES) {
      try {
        const envPath = path.resolve(process.env.SMOKE_NODE_MODULES, "playwright/index.mjs");
        return await import(pathToFileURL(envPath).href);
      } catch (_e2) {
        // Fall through to the repository-local tool cache below.
      }
    }
    const localPath = path.resolve(rootDir, ".local-tools/node_modules/playwright/index.mjs");
    return await import(pathToFileURL(localPath).href);
  }
}

async function findHeadlessShell() {
  try {
    const mod = await import(pathToFileURL(path.resolve(rootDir, "tools/find-playwright-headless-shell.mjs")).href);
    return mod.findCachedPlaywrightHeadlessShell?.() || "";
  } catch (_e) {
    return "";
  }
}

const propGroups = {
  button: [
    "display",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "letterSpacing",
    "textTransform",
    "color",
    "backgroundColor",
    "borderTopColor",
    "borderTopStyle",
    "borderTopWidth",
    "borderRightColor",
    "borderRightStyle",
    "borderRightWidth",
    "borderBottomColor",
    "borderBottomStyle",
    "borderBottomWidth",
    "borderLeftColor",
    "borderLeftStyle",
    "borderLeftWidth",
    "borderTopLeftRadius",
    "borderTopRightRadius",
    "borderBottomRightRadius",
    "borderBottomLeftRadius",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "minHeight",
    "boxShadow",
    "opacity"
  ],
  panel: [
    "display",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "letterSpacing",
    "textTransform",
    "color",
    "backgroundColor",
    "borderTopColor",
    "borderTopStyle",
    "borderTopWidth",
    "borderRightColor",
    "borderRightStyle",
    "borderRightWidth",
    "borderBottomColor",
    "borderBottomStyle",
    "borderBottomWidth",
    "borderLeftColor",
    "borderLeftStyle",
    "borderLeftWidth",
    "borderTopLeftRadius",
    "borderTopRightRadius",
    "borderBottomRightRadius",
    "borderBottomLeftRadius",
    "boxShadow",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "width",
    "height"
  ],
  box: [
    "display",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "letterSpacing",
    "textTransform",
    "color",
    "backgroundColor",
    "borderTopColor",
    "borderTopStyle",
    "borderTopWidth",
    "borderRightColor",
    "borderRightStyle",
    "borderRightWidth",
    "borderBottomColor",
    "borderBottomStyle",
    "borderBottomWidth",
    "borderLeftColor",
    "borderLeftStyle",
    "borderLeftWidth",
    "borderTopLeftRadius",
    "borderTopRightRadius",
    "borderBottomRightRadius",
    "borderBottomLeftRadius",
    "boxShadow",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "opacity"
  ],
  text: [
    "display",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "letterSpacing",
    "textTransform",
    "color",
    "marginTop",
    "marginRight",
    "marginBottom",
    "marginLeft",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft"
  ],
  field: [
    "display",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "color",
    "backgroundColor",
    "borderTopColor",
    "borderTopStyle",
    "borderTopWidth",
    "borderRightColor",
    "borderRightStyle",
    "borderRightWidth",
    "borderBottomColor",
    "borderBottomStyle",
    "borderBottomWidth",
    "borderLeftColor",
    "borderLeftStyle",
    "borderLeftWidth",
    "borderTopLeftRadius",
    "borderTopRightRadius",
    "borderBottomRightRadius",
    "borderBottomLeftRadius",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "minHeight",
    "opacity"
  ],
  compact: [
    "display",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "color",
    "backgroundColor",
    "borderTopColor",
    "borderTopStyle",
    "borderTopWidth",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "opacity"
  ],
  divider: [
    "display",
    "height",
    "marginTop",
    "marginBottom",
    "borderTopColor",
    "borderTopStyle",
    "borderTopWidth",
    "opacity"
  ],
  pseudoText: [
    "display",
    "content",
    "float",
    "paddingRight",
    "color"
  ],
  arrowTriangle: [
    "content",
    "borderTopColor",
    "borderTopStyle",
    "borderTopWidth",
    "borderRightColor",
    "borderRightStyle",
    "borderRightWidth",
    "borderBottomColor",
    "borderBottomStyle",
    "borderBottomWidth",
    "borderLeftColor",
    "borderLeftStyle",
    "borderLeftWidth"
  ],
  tableState: [
    "display",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "color",
    "backgroundColor",
    "borderTopColor",
    "borderTopStyle",
    "borderTopWidth",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "boxShadow",
    "opacity"
  ]
};

const focusedCases = [
  {
    name: "pill active",
    heading: "Pill Navigation",
    bs: ".nav-pills .nav-link.active",
    we: ".we-tab-style-pills .we-tab-btn.is-selected",
    props: propGroups.button
  },
  {
    name: "pill inactive",
    heading: "Pill Navigation",
    bs: ".nav-pills .nav-link:not(.active)",
    we: ".we-tab-style-pills .we-tab-btn:not(.is-selected)",
    props: propGroups.button
  },
  {
    name: "toolbar secondary",
    heading: "Toolbar Variants",
    bs: ".btn-toolbar .btn-outline-secondary",
    we: ".we-toolbar-group .we-button-outline-secondary",
    props: propGroups.button
  },
  {
    name: "toolbar active",
    heading: "Toolbar Variants",
    bs: ".btn-toolbar .btn-outline-primary.active",
    we: ".we-toolbar-group .we-button-outline-primary.is-active",
    props: propGroups.button
  },
  {
    name: "offcanvas panel",
    heading: "Offcanvas Panel",
    bs: ".offcanvas",
    we: ".we-offcanvas-panel",
    props: propGroups.panel
  },
  {
    name: "offcanvas title",
    heading: "Offcanvas Panel",
    bs: ".offcanvas-title",
    we: ".we-offcanvas-title",
    props: propGroups.text
  },
  {
    name: "close standalone",
    heading: "Close Buttons",
    bs: ".btn-close",
    we: ".we-close-button",
    props: propGroups.button
  },
  {
    name: "toast close",
    heading: "Close Buttons",
    bs: ".toast .btn-close",
    we: ".we-toast .we-toast-close",
    props: propGroups.button
  }
];

const allCases = [
  ...focusedCases,
  { name: "navigation navbar", heading: "Navigation", bs: ".navbar", we: ".we-navigation-bar", props: propGroups.panel },
  { name: "navigation brand", heading: "Navigation", bs: ".navbar-brand", we: ".we-navbar-brand", props: propGroups.button },
  { name: "navigation active link", heading: "Navigation", bs: ".navbar-nav .nav-link.active", we: ".we-navigation-bar .we-navigation-bar-items > .we-button[aria-current=\"page\"]", props: propGroups.button },
  { name: "navigation inactive link", heading: "Navigation", bs: ".navbar-nav .nav-link:not(.active)", we: ".we-navigation-bar .we-navigation-bar-items > .we-button:not(.we-navbar-brand):not([aria-current=\"page\"])", props: propGroups.button },
  { name: "navigation tab active", heading: "Navigation", bs: ".nav-tabs .nav-link.active", we: ".we-tab-list .we-tab-btn.is-selected", props: propGroups.button },
  { name: "navigation tab inactive", heading: "Navigation", bs: ".nav-tabs .nav-link:not(.active)", we: ".we-tab-list .we-tab-btn:not(.is-selected)", props: propGroups.button },
  { name: "buttons primary", heading: "Buttons And Badges", bs: ".btn-primary", we: ".we-button-primary", props: propGroups.button },
  { name: "buttons secondary", heading: "Buttons And Badges", bs: ".btn-secondary", we: ".we-button-secondary", props: propGroups.button },
  { name: "buttons light", heading: "Buttons And Badges", bs: ".btn-light", we: ".we-button-light", props: propGroups.button },
  { name: "buttons outline", heading: "Buttons And Badges", bs: ".btn-outline-primary", we: ".we-button-outline-primary", props: propGroups.button },
  { name: "badges primary", heading: "Buttons And Badges", bs: ".badge.text-bg-primary", we: ".we-badge-primary", props: propGroups.compact },
  { name: "badges secondary", heading: "Buttons And Badges", bs: ".badge.text-bg-secondary", we: ".we-badge-secondary", props: propGroups.compact },
  { name: "badges success", heading: "Buttons And Badges", bs: ".badge.text-bg-success", we: ".we-badge-success", props: propGroups.compact },
  { name: "badges danger", heading: "Buttons And Badges", bs: ".badge.text-bg-danger", we: ".we-badge-danger", props: propGroups.compact },
  { name: "card shell", heading: "Card", bs: ".card", we: ".we-card", props: propGroups.panel },
  { name: "card header", heading: "Card", bs: ".card-header", we: ".we-card-header", props: propGroups.compact },
  { name: "card body", heading: "Card", bs: ".card-body", we: ".we-card-body", props: propGroups.box },
  { name: "card title", heading: "Card", bs: ".card-title", we: ".we-card-title", props: propGroups.text },
  { name: "card footer", heading: "Card", bs: ".card-footer", we: ".we-card-footer", props: propGroups.box },
  { name: "list group active", heading: "List Group", bs: ".list-group-item.active", we: ".we-list-group-item.is-current", props: propGroups.button },
  { name: "list group item", heading: "List Group", bs: ".list-group-item:not(.active)", we: ".we-list-group-item:not(.is-current)", props: propGroups.button },
  { name: "table header", heading: "Table", bs: "thead th", we: "thead th", props: propGroups.compact },
  { name: "table cell", heading: "Table", bs: "tbody td", we: "tbody td", props: propGroups.compact },
  { name: "controls input", heading: "Controls", bs: ".form-control", we: ".we-input", props: propGroups.field },
  { name: "controls select", heading: "Controls", bs: ".form-select", we: "select.we-input", props: propGroups.field },
  { name: "controls checkbox", heading: "Controls", bs: ".form-check-input[type=checkbox]", we: ".we-checkbox", props: propGroups.field },
  { name: "dialog panel", heading: "Dialog", bs: ".modal-content", we: ".we-dialog-panel", props: propGroups.panel },
  { name: "dialog header", heading: "Dialog", bs: ".modal-header", we: ".we-dialog-header", props: propGroups.box },
  { name: "dialog title", heading: "Dialog", bs: ".modal-title", we: ".we-dialog-title", props: propGroups.text },
  { name: "dialog body", heading: "Dialog", bs: ".modal-body", we: ".we-dialog-body", props: propGroups.box },
  { name: "dialog footer", heading: "Dialog", bs: ".modal-footer", we: ".we-dialog-footer", props: propGroups.box },
  { name: "dialog secondary button", heading: "Dialog", bs: ".modal-footer .btn-secondary", we: ".we-dialog-footer .we-button-secondary", props: propGroups.button },
  { name: "accordion trigger", heading: "Accordion", bs: ".accordion-button", we: ".we-accordion-trigger", props: propGroups.button },
  { name: "accordion collapsed trigger", heading: "Accordion", bs: ".accordion-button.collapsed", we: ".we-accordion-trigger:not(.is-open)", props: propGroups.button },
  { name: "accordion body", heading: "Accordion", bs: ".accordion-body", we: ".we-accordion-content", props: propGroups.panel },
  { name: "alert warning", heading: "Alerts And Toasts", bs: ".alert-warning", we: ".we-alert-warning", props: propGroups.panel },
  { name: "toast panel", heading: "Alerts And Toasts", bs: ".toast", we: ".we-toast", props: propGroups.panel },
  { name: "toast header", heading: "Alerts And Toasts", bs: ".toast-header", we: ".we-toast-header", props: propGroups.compact },
  { name: "toast body", heading: "Alerts And Toasts", bs: ".toast-body", we: ".we-toast-message", props: propGroups.text },
  { name: "breadcrumb link", heading: "Breadcrumb And Pagination", bs: ".breadcrumb-item a", we: ".we-breadcrumb-item:not(.is-current) .we-breadcrumb-link", props: propGroups.button },
  { name: "pagination active", heading: "Breadcrumb And Pagination", bs: ".page-item.active .page-link", we: ".we-page-btn.is-current", props: propGroups.button },
  { name: "progress shell", heading: "Progress", bs: ".progress", we: ".we-progress-demo", props: propGroups.panel },
  { name: "progress success bar", heading: "Progress", bs: ".progress-bar.bg-success", we: ".we-progress-fill-success", props: propGroups.compact },
  { name: "progress info bar", heading: "Progress", bs: ".progress-bar.bg-info", we: ".we-progress-fill-info", props: propGroups.compact },
  { name: "alert success", heading: "Alert Variants", bs: ".alert-success", we: ".we-alert-success", props: propGroups.panel },
  { name: "alert danger", heading: "Alert Variants", bs: ".alert-danger", we: ".we-alert-danger", props: propGroups.panel },
  { name: "list group variants active", heading: "List Group Variants", bs: ".list-group-item.active", we: ".we-list-group-item.is-current", props: propGroups.button },
  { name: "table variants active row", heading: "Table Variants", bs: "tr.table-active td", we: "tr.we-table-row-active td", props: propGroups.tableState },
  { name: "table variants striped row", heading: "Table Variants", bs: ".table-striped > tbody > tr:nth-of-type(odd) td", we: ".we-table-striped > tbody > tr:nth-of-type(odd) td", props: propGroups.tableState },
  { name: "progress warning bar", heading: "Progress Variants", bs: ".progress-bar.bg-warning", we: ".we-progress-fill-warning", props: propGroups.compact },
  { name: "progress danger bar", heading: "Progress Variants", bs: ".progress-bar.bg-danger", we: ".we-progress-fill-danger", props: propGroups.compact },
  { name: "badge warning pill", heading: "Badge Variants", bs: ".badge.rounded-pill", we: ".we-badge-pill", props: propGroups.compact },
  { name: "badge info", heading: "Badge Variants", bs: ".badge.text-bg-info", we: ".we-badge-info", props: propGroups.compact },
  { name: "badge light", heading: "Badge Variants", bs: ".badge.text-bg-light", we: ".we-badge-light", props: propGroups.compact },
  { name: "badge dark", heading: "Badge Variants", bs: ".badge.text-bg-dark", we: ".we-badge-dark", props: propGroups.compact },
  { name: "pagination disabled", heading: "Pagination Variants", bs: ".page-item.disabled .page-link", we: ".we-page-btn.is-disabled", props: propGroups.button },
  { name: "pagination current", heading: "Pagination Variants", bs: ".page-item.active .page-link", we: ".we-page-btn.is-current", props: propGroups.button },
  { name: "pagination normal", heading: "Pagination Variants", bs: ".page-item:not(.active):not(.disabled) .page-link", we: ".we-page-btn:not(.is-current):not(.is-disabled)", props: propGroups.button },
  { name: "breadcrumb separator", heading: "Breadcrumb Variants", bs: ".breadcrumb-item + .breadcrumb-item", we: ".we-breadcrumb-item + .we-breadcrumb-item", props: propGroups.pseudoText, pseudo: "::before", includeRect: false },
  { name: "breadcrumb variants current", heading: "Breadcrumb Variants", bs: ".breadcrumb-item.active", we: ".we-breadcrumb-item.is-current", props: propGroups.button },
  { name: "form select enabled", heading: "Form Select Variants", bs: ".form-select:not(:disabled)", we: "select.we-input:not(:disabled)", props: propGroups.field },
  { name: "form select disabled", heading: "Form Select Variants", bs: ".form-select:disabled", we: "select.we-input:disabled", props: propGroups.field },
  { name: "menu popup", heading: "Menus And Dropdowns", bs: ".dropdown-menu", we: ".we-menu-popup", props: propGroups.panel },
  { name: "menu header", heading: "Menus And Dropdowns", bs: ".dropdown-header", we: ".we-menu-header", props: propGroups.text },
  { name: "menu divider", heading: "Menus And Dropdowns", bs: ".dropdown-divider", we: ".we-menu-popup .we-divider", props: propGroups.divider },
  { name: "menu active item", heading: "Menus And Dropdowns", bs: ".dropdown-item.active", we: ".we-menu-item.is-current", props: propGroups.button },
  { name: "menu normal item", heading: "Menus And Dropdowns", bs: ".dropdown-item:not(.active)", we: ".we-menu-item:not(.is-current)", props: propGroups.button },
  { name: "tooltip bubble", heading: "Tooltip And Popover", bs: ".tooltip-inner", we: ".we-tooltip-bubble", props: propGroups.panel },
  { name: "tooltip arrow triangle", heading: "Tooltip And Popover", bs: ".tooltip .tooltip-arrow", we: ".we-tooltip-bubble", props: propGroups.arrowTriangle, pseudo: "::before", includeRect: false },
  { name: "popover panel", heading: "Tooltip And Popover", bs: ".popover", we: ".we-popover-panel", props: propGroups.panel },
  { name: "popover title", heading: "Tooltip And Popover", bs: ".popover-header", we: ".we-popover-header", props: propGroups.text },
  { name: "popover body", heading: "Tooltip And Popover", bs: ".popover-body", we: ".we-popover-body", props: propGroups.box },
  { name: "button group first", heading: "Button Groups", bs: ".btn-group .btn:first-child", we: ".we-button-group .we-button:first-child", props: propGroups.button },
  { name: "button group active", heading: "Button Groups", bs: ".btn-group .btn.active", we: ".we-button-group .we-button.is-active", props: propGroups.button },
  { name: "button group last", heading: "Button Groups", bs: ".btn-group .btn:last-child", we: ".we-button-group .we-button:last-child", props: propGroups.button },
  { name: "button group vertical", heading: "Button Groups", bs: ".btn-group-vertical .btn-secondary", we: ".we-button-group-vertical .we-button-secondary", props: propGroups.button },
  { name: "button group vertical last", heading: "Button Groups", bs: ".btn-group-vertical .btn:last-child", we: ".we-button-group-vertical .we-button:last-child", props: propGroups.button },
  { name: "input group addon", heading: "Input Groups And Validation", bs: ".input-group-text", we: ".we-input-group-text", props: propGroups.field },
  { name: "input group field", heading: "Input Groups And Validation", bs: ".input-group .form-control", we: ".we-input-group .we-input", props: propGroups.field },
  { name: "valid feedback", heading: "Input Groups And Validation", bs: ".valid-feedback", we: ".we-feedback.is-valid", props: propGroups.text },
  { name: "invalid feedback", heading: "Input Groups And Validation", bs: ".invalid-feedback", we: ".we-feedback.is-invalid", props: propGroups.text },
  { name: "radio input", heading: "Radio Group", bs: ".form-check-input[type=radio]", we: ".we-radio-input", props: propGroups.field },
  { name: "range input", heading: "Range And Switches", bs: ".form-range", we: ".we-range", props: propGroups.field },
  { name: "switch input", heading: "Range And Switches", bs: ".form-switch .form-check-input", we: ".we-switch-control", props: propGroups.field },
  { name: "disabled primary", heading: "Disabled States", bs: ".btn-primary:disabled", we: ".we-button-primary:disabled", props: propGroups.button },
  { name: "disabled input", heading: "Disabled States", bs: ".form-control:disabled", we: ".we-input:disabled", props: propGroups.field },
  { name: "disabled checkbox", heading: "Disabled States", bs: ".form-check-input:disabled", we: ".we-checkbox:disabled", props: propGroups.field },
  { name: "textarea", heading: "Textarea And Helper Text", bs: "textarea.form-control", we: "textarea.we-input", props: propGroups.field },
  { name: "helper text", heading: "Textarea And Helper Text", bs: ".form-text", we: ".we-help-text", props: propGroups.text },
  { name: "checkbox group input", heading: "Checkbox Group", bs: ".form-check-input", we: ".we-checkbox", props: propGroups.field }
];

const casesByProfile = {
  focused: focusedCases,
  all: allCases
};

function pixelValue(value) {
  const match = /^(-?\d+(?:\.\d+)?)px$/.exec(value);
  return match ? Number(match[1]) : null;
}

function comparable(key, lhs, rhs) {
  if (lhs === rhs) return true;
  if ((lhs === "rgba(0, 0, 0, 0)" && rhs === "transparent") ||
      (rhs === "rgba(0, 0, 0, 0)" && lhs === "transparent")) {
    return true;
  }
  // Used geometry can differ by a subpixel after font/layout rounding; keep style tokens strict.
  if (["width", "height", "rectWidth", "rectHeight"].includes(key)) {
    const lhsPx = pixelValue(lhs);
    const rhsPx = pixelValue(rhs);
    if (lhsPx !== null && rhsPx !== null && Math.abs(lhsPx - rhsPx) <= 1) {
      return true;
    }
  }
  return false;
}

async function collectCase(page, testCase) {
  return await page.evaluate(({ testCase }) => {
    function sectionByHeading(rootSelector, heading) {
      const root = document.querySelector(rootSelector);
      if (!root) return null;
      return Array.from(root.querySelectorAll(".sample-card")).find((section) => {
        const h3 = section.querySelector(":scope > h3");
        return h3 && h3.textContent.trim() === heading;
      }) || null;
    }

    function styleMap(element, props, pseudo, includeRect) {
      if (!element) return null;
      const cs = getComputedStyle(element, pseudo || null);
      const rect = element.getBoundingClientRect();
      const out = {};
      for (const prop of props) out[prop] = cs[prop];
      if (includeRect) {
        out.rectWidth = `${Math.round(rect.width * 100) / 100}px`;
        out.rectHeight = `${Math.round(rect.height * 100) / 100}px`;
      }
      return out;
    }

    const bsSection = sectionByHeading(".bs-preview", testCase.heading);
    const weSection = sectionByHeading(".we-preview", testCase.heading);
    const bsElement = bsSection?.querySelector(testCase.bs) || null;
    const weElement = weSection?.querySelector(testCase.we) || null;
    return {
      name: testCase.name,
      heading: testCase.heading,
      bsFound: Boolean(bsElement),
      weFound: Boolean(weElement),
      bs: styleMap(bsElement, testCase.props, testCase.pseudo, testCase.includeRect !== false),
      we: styleMap(weElement, testCase.props, testCase.pseudo, testCase.includeRect !== false)
    };
  }, { testCase });
}

async function collectSectionHeadings(page) {
  return await page.evaluate(() => {
    const root = document.querySelector(".bs-preview");
    if (!root) return [];
    return Array.from(root.querySelectorAll(".sample-card > h3"))
      .map((h3) => h3.textContent.trim())
      .filter(Boolean);
  });
}

function diffCase(result) {
  if (!result.bsFound || !result.weFound) {
    return [{ prop: "selector", bs: result.bsFound ? "found" : "missing", we: result.weFound ? "found" : "missing" }];
  }
  function nonPaintingBorderEdge(side, edge) {
    const style = side[`${edge}Style`];
    const width = side[`${edge}Width`];
    return style === "none" || style === "hidden" || width === "0px";
  }
  function ignorableBorderColor(key) {
    const edge = key.match(/^border(Top|Right|Bottom|Left)Color$/)?.[1];
    if (!edge) return false;
    const prefix = `border${edge}`;
    return nonPaintingBorderEdge(result.bs, prefix) &&
      nonPaintingBorderEdge(result.we, prefix);
  }
  const diffs = [];
  const keys = Object.keys(result.bs || {});
  for (const key of keys) {
    const lhs = result.bs[key];
    const rhs = result.we[key];
    if (ignorableBorderColor(key)) continue;
    if (!comparable(key, lhs, rhs)) diffs.push({ prop: key, bs: lhs, we: rhs });
  }
  return diffs;
}

function interestingDiffs(diffs) {
  const priority = [
    "selector",
    "content",
    "width",
    "height",
    "color",
    "backgroundColor",
    "borderTopColor",
    "borderRightColor",
    "borderBottomColor",
    "borderLeftColor",
    "borderTopStyle",
    "borderRightStyle",
    "borderBottomStyle",
    "borderLeftStyle",
    "borderTopWidth",
    "borderLeftWidth",
    "borderRightWidth",
    "borderBottomWidth",
    "borderTopLeftRadius",
    "borderTopRightRadius",
    "borderBottomRightRadius",
    "borderBottomLeftRadius",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "letterSpacing",
    "textTransform",
    "boxShadow",
    "opacity",
    "rectWidth",
    "rectHeight"
  ];
  return diffs
    .filter((diff) => priority.includes(diff.prop))
    .sort((a, b) => priority.indexOf(a.prop) - priority.indexOf(b.prop))
    .slice(0, verbose ? diffs.length : 8);
}

function summarizeTheme(themeName, results) {
  const totalDiffs = results.reduce((sum, result) => sum + result.diffs.length, 0);
  const failing = results.filter((result) => result.diffs.length > 0);
  console.log(`\nTHEME ${themeName}: ${totalDiffs} diffs across ${results.length} cases`);
  for (const result of results) {
    if (result.diffs.length === 0 && !verbose) continue;
    console.log(`- ${result.name}: ${result.diffs.length} diffs`);
    for (const diff of interestingDiffs(result.diffs)) {
      console.log(`  ${diff.prop}: bs=${JSON.stringify(diff.bs)} we=${JSON.stringify(diff.we)}`);
    }
  }
  if (profile === "all" && failing.length > 0) {
    console.log("\nTop mismatch cases:");
    for (const result of failing
      .slice()
      .sort((a, b) => b.diffs.length - a.diffs.length)
      .slice(0, 8)) {
      const top = interestingDiffs(result.diffs)[0];
      const hint = top ? ` (${top.prop})` : "";
      console.log(`- ${themeName} / ${result.heading} / ${result.name}: ${result.diffs.length} diffs${hint}`);
    }
  }
  return totalDiffs;
}

async function main() {
  const cases = casesByProfile[profile];
  if (!cases) {
    throw new Error(`unknown THEMATIC_COMPARE_PROFILE=${JSON.stringify(profile)}; use focused or all`);
  }

  const { chromium } = await loadPlaywright();
  const executablePath = await findHeadlessShell();
  const browser = await chromium.launch({
    headless: true,
    ...(executablePath ? { executablePath } : {})
  });

  let grandTotal = 0;
  try {
    const page = await browser.newPage({ viewport: { width: 1500, height: 1100 } });
    const guard = installPlaywrightErrorGuard(page);
    page.setDefaultTimeout(15000);

    console.log(`thematic compare profile=${profile} failOnDiffs=${failOnDiffs ? "yes" : "no"}`);
    console.log(`baseUrl=${baseUrl}`);
    console.log(`themes=${themes.join(",")}`);

    for (const theme of themes) {
      const url = `${baseUrl}?theme=${encodeURIComponent(theme)}`;
      const themeSpec = themeSpecs[theme] || { bootstrap: theme, web: theme, label: theme };
      const mark = guard.mark();
      await page.goto(url, { waitUntil: "commit" });
      await page.waitForFunction(() =>
        document.querySelector("#bootstrap-theme-link") &&
        document.querySelector("#we-theme-style") &&
        document.querySelector("#we-preview"));
      await page.evaluate(async ({ themeName, themeSpec }) => {
        const weCoreSelector = ".we-preview";
        const bootstrapTitle = document.querySelector("#bootstrap-title");
        const weTitle = document.querySelector("#we-title");
        const current = document.querySelector("#current");
        const themeSelect = document.querySelector("#theme-select");
        const bootstrapLink = document.querySelector("#bootstrap-theme-link");
        const wePreview = document.querySelector("#we-preview");
        const weThemeStyle = document.querySelector("#we-theme-style");

        function webThemeNames(themeSpec) {
          const names = [themeSpec.web];
          if (themeSpec.bootstrap && themeSpec.bootstrap !== themeSpec.web) names.push(themeSpec.bootstrap);
          return names;
        }

        function scopeWeThemeCss(themeSpec, cssText) {
          return webThemeNames(themeSpec)
            .sort((a, b) => b.length - a.length)
            .reduce((text, themeName) => {
              const exact = `html.we-theme-${themeName}`;
              return text
                .replaceAll(`${exact} body`, `${weCoreSelector}.we-theme-${themeName}`)
                .replaceAll(exact, `${weCoreSelector}.we-theme-${themeName}`);
            }, cssText);
        }

        if (themeSelect) themeSelect.value = themeName;
        if (current) current.textContent = `current=${themeName}`;
        if (bootstrapTitle) bootstrapTitle.textContent = `${themeSpec.label.replace(" Boost", "")} Bootstrap`;
        if (weTitle) weTitle.textContent = `${themeSpec.label} web-easy`;
        if (bootstrapLink) bootstrapLink.href = `./generated/bootstrap-${themeSpec.bootstrap}-scoped.css`;
        if (wePreview) {
          wePreview.className = `we-preview ${webThemeNames(themeSpec).map((themeName) => `we-theme-${themeName}`).join(" ")}`;
        }
        if (weThemeStyle) {
          const css = await fetch(`./generated/thematic-${themeSpec.web}.css`).then((r) => r.text());
          weThemeStyle.textContent = scopeWeThemeCss(themeSpec, css);
        }
      }, { themeName: theme, themeSpec });
      await page.waitForFunction(({ bootstrapTheme, webTheme }) => {
        const bs = document.querySelector(".bs-preview");
        const we = document.querySelector(".we-preview");
        if (!bs || !we) return false;
        const bsReady = getComputedStyle(bs).getPropertyValue("--bs-body-font-family").trim() !== "";
        const weReady = getComputedStyle(we).getPropertyValue("--we-font-family-base").trim() !== "";
        const link = document.querySelector("#bootstrap-theme-link");
        const linkReady = link && link.href.endsWith(`/generated/bootstrap-${bootstrapTheme}-scoped.css`);
        return bsReady && weReady && linkReady && we.classList.contains(`we-theme-${webTheme}`);
      }, { bootstrapTheme: themeSpec.bootstrap, webTheme: themeSpec.web });
      await page.evaluate(async () => {
        if (!document.fonts) return;
        await Promise.race([
          document.fonts.ready,
          new Promise((resolve) => setTimeout(resolve, 5000))
        ]);
      });
      guard.assertSince(mark, `thematic compare ${theme}`);

      if (profile === "all") {
        const headings = await collectSectionHeadings(page);
        const covered = new Set(cases.map((testCase) => testCase.heading));
        const missing = headings.filter((heading) => !covered.has(heading));
        if (missing.length > 0) {
          throw new Error(`all profile is missing section coverage: ${missing.join(", ")}`);
        }
      }

      const results = [];
      for (const testCase of cases) {
        const result = await collectCase(page, testCase);
        results.push({ ...result, diffs: diffCase(result) });
      }
      grandTotal += summarizeTheme(theme, results);
    }
  } finally {
    await browser.close();
  }

  if (grandTotal > 0 && failOnDiffs) {
    throw new Error(`thematic compare found ${grandTotal} diffs`);
  }
  console.log(`\nPASS thematic compare ${profile}: ${grandTotal} diffs${failOnDiffs ? "" : " (report only)"}`);
}

main().catch((e) => {
  console.error(`FAIL\n${String(e.message || e)}`);
  process.exit(1);
});
