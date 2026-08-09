#!/usr/bin/env node

import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { installPlaywrightErrorGuard } from "./playwright-error-guard.mjs";

const scriptDir = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(scriptDir, "../../..");
const baseUrl =
  process.env.THEMATIC_COMPARE_URL ||
  `${process.env.SMOKE_BASE_URL || "http://127.0.0.1:8765"}/test-browser-theme-thematic-bootstrap-compare.html`;
const themes = (process.env.THEMATIC_COMPARE_THEMES ||
  "brite,quartz,lux,sketchy,sandstone,superhero,lux-boost,sandstone-boost,vapor,morph,materia,flatly,zephyr")
  .split(",")
  .map((theme) => theme.trim())
  .filter(Boolean);
const themeSpecs = {
  brite: { bootstrap: "brite", web: "brite", label: "Brite" },
  quartz: { bootstrap: "quartz", web: "quartz", label: "Quartz" },
  superhero: { bootstrap: "superhero", web: "superhero", label: "Superhero" },
  sketchy: { bootstrap: "sketchy", web: "sketchy", label: "Sketchy" },
  lux: { bootstrap: "lux", web: "lux", label: "Lux" },
  "lux-boost": { bootstrap: "lux", web: "lux-boost", label: "Lux Boost" },
  sandstone: { bootstrap: "sandstone", web: "sandstone", label: "Sandstone" },
  "sandstone-boost": { bootstrap: "sandstone", web: "sandstone-boost", label: "Sandstone Boost" },
  vapor: { bootstrap: "vapor", web: "vapor", label: "Vapor" },
  morph: { bootstrap: "morph", web: "morph", label: "Morph" },
  materia: { bootstrap: "materia", web: "materia", label: "Materia" },
  flatly: { bootstrap: "flatly", web: "flatly", label: "Flatly" },
  zephyr: { bootstrap: "zephyr", web: "zephyr", label: "Zephyr" }
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
  alertClose: [
    "display",
    "position",
    "top",
    "right",
    "zIndex",
    "boxSizing",
    "width",
    "height",
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
  scrollspyShell: [
    "display",
    "alignItems",
    "gap",
    "maxHeight",
    "overflowX",
    "overflowY",
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
    "paddingLeft"
  ],
  scrollspySection: [
    "display",
    "gap",
    "minHeight",
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
    "paddingLeft"
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
  sectionHeading: [
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
    "borderBottomColor",
    "borderBottomStyle",
    "borderBottomWidth",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "opacity",
    "textShadow"
  ],
  labelText: [
    "display",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "letterSpacing",
    "textTransform",
    "color",
    "opacity"
  ],
  floatingLabel: [
    "display",
    "position",
    "top",
    "left",
    "zIndex",
    "maxWidth",
    "height",
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "letterSpacing",
    "textTransform",
    "color",
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
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "transform",
    "transformOrigin",
    "opacity"
  ],
  flexLabelText: [
    "fontFamily",
    "fontSize",
    "fontWeight",
    "lineHeight",
    "letterSpacing",
    "textTransform",
    "color",
    "opacity"
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
  spinnerIcon: [
    "display",
    "boxSizing",
    "color",
    "backgroundColor",
    "width",
    "height",
    "verticalAlign",
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
    "opacity"
  ],
  placeholder: [
    "display",
    "boxSizing",
    "color",
    "backgroundColor",
    "width",
    "height",
    "minHeight",
    "verticalAlign",
    "cursor",
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
  ],
  carouselViewport: [
    "display",
    "position",
    "width",
    "overflowX",
    "overflowY"
  ],
  carouselControl: [
    "display",
    "position",
    "top",
    "bottom",
    "zIndex",
    "alignItems",
    "justifyContent",
    "width",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "color",
    "textAlign",
    "backgroundColor",
    "filter",
    "borderTopWidth",
    "borderTopStyle",
    "borderTopColor",
    "borderRightWidth",
    "borderRightStyle",
    "borderRightColor",
    "borderBottomWidth",
    "borderBottomStyle",
    "borderBottomColor",
    "borderLeftWidth",
    "borderLeftStyle",
    "borderLeftColor",
    "opacity"
  ],
  carouselIndicator: [
    "boxSizing",
    "display",
    "flexGrow",
    "flexShrink",
    "flexBasis",
    "width",
    "height",
    "paddingTop",
    "paddingRight",
    "paddingBottom",
    "paddingLeft",
    "marginRight",
    "marginLeft",
    "textIndent",
    "cursor",
    "backgroundColor",
    "backgroundClip",
    "borderTopWidth",
    "borderTopStyle",
    "borderTopColor",
    "borderRightWidth",
    "borderRightStyle",
    "borderRightColor",
    "borderBottomWidth",
    "borderBottomStyle",
    "borderBottomColor",
    "borderLeftWidth",
    "borderLeftStyle",
    "borderLeftColor",
    "opacity"
  ],
  pageRoot: [
    "color",
    "backgroundColor",
    "backgroundImage",
    "textShadow"
  ],
  glowText: [
    "color",
    "textShadow"
  ],
  sectionHeader: [
    "color",
    "backgroundColor",
    "textShadow"
  ],
  formCheckRow: [
    "display",
    "paddingLeft"
  ]
};

const focusedCases = [
  {
    name: "preview root background",
    bs: ".bs-preview",
    we: ".we-preview",
    props: propGroups.pageRoot,
    includeRect: false
  },
  {
    name: "preview section header glow",
    heading: "Navigation",
    bs: ":scope > h3",
    we: ":scope > h3",
    props: propGroups.sectionHeader,
    includeRect: false
  },
  {
    name: "navigation brand glow",
    heading: "Navigation",
    bs: ".navbar-brand",
    we: ".we-navbar-brand",
    props: propGroups.glowText,
    includeRect: false
  },
  {
    name: "card header glow",
    heading: "Card",
    bs: ".card-header",
    we: ".we-card-header",
    props: propGroups.sectionHeader,
    includeRect: false
  },
  {
    name: "card title glow",
    heading: "Card",
    bs: ".card-title",
    we: ".we-card-title",
    props: propGroups.glowText,
    includeRect: false
  },
  {
    name: "dialog title glow",
    heading: "Dialog",
    bs: ".modal-title",
    we: ".we-dialog-title",
    props: propGroups.glowText,
    includeRect: false
  },
  {
    name: "toast title glow",
    heading: "Alerts And Toasts",
    bs: ".toast-header strong",
    we: ".we-toast-title",
    props: propGroups.glowText,
    includeRect: false
  },
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
    name: "scrollspy active item",
    heading: "Scrollspy",
    bs: ".scrollspy-demo .nav-pills .nav-link.active",
    we: ".we-scrollspy .we-scrollspy-item.is-current",
    props: propGroups.button
  },
  {
    name: "scrollspy inactive item",
    heading: "Scrollspy",
    bs: ".scrollspy-demo .nav-pills .nav-link:not(.active)",
    we: ".we-scrollspy .we-scrollspy-item:not(.is-current)",
    props: propGroups.button
  },
  {
    name: "scrollspy shell",
    heading: "Scrollspy",
    bs: ".scrollspy-demo",
    we: ".we-scrollspy",
    props: propGroups.scrollspyShell
  },
  {
    name: "scrollspy sections",
    heading: "Scrollspy",
    bs: ".scrollspy-demo-sections",
    we: ".we-scrollspy-sections",
    props: propGroups.scrollspyShell
  },
  {
    name: "scrollspy section",
    heading: "Scrollspy",
    bs: ".scrollspy-demo-sections section",
    we: ".we-scrollspy-section",
    props: propGroups.scrollspySection
  },
  {
    name: "scrollspy section title",
    heading: "Scrollspy",
    bs: ".scrollspy-demo-sections section strong",
    we: ".we-scrollspy-section strong",
    props: propGroups.text
  },
  {
    name: "list group disabled",
    heading: "List Group",
    bs: ".list-group-item.disabled",
    we: ".we-list-group-item.is-disabled",
    props: propGroups.button
  },
  {
    name: "floating label control",
    heading: "Floating Labels",
    bs: ".form-floating > .form-control",
    we: ".we-floating-field > .we-floating-control",
    props: propGroups.field
  },
  {
    name: "floating label text",
    heading: "Floating Labels",
    bs: ".form-floating > label",
    we: ".we-floating-field > .we-floating-label",
    props: propGroups.floatingLabel
  },
  {
    name: "toolbar secondary",
    heading: "Toolbar Variants",
    bs: ".btn-toolbar .btn-outline-secondary",
    we: ".we-toolbar-group .we-button-outline-secondary",
    props: propGroups.button
  },
  {
    name: "toolbar secondary adjacent",
    heading: "Toolbar Variants",
    bs: ".btn-toolbar .btn-outline-secondary + .btn-outline-secondary",
    we: ".we-toolbar-group .we-button-outline-secondary + .we-button-outline-secondary",
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
    name: "offcanvas header",
    heading: "Offcanvas Panel",
    bs: ".offcanvas-header",
    we: ".we-offcanvas-header",
    props: propGroups.box
  },
  {
    name: "offcanvas title",
    heading: "Offcanvas Panel",
    bs: ".offcanvas-title",
    we: ".we-offcanvas-title",
    props: propGroups.text
  },
  {
    name: "offcanvas body",
    heading: "Offcanvas Panel",
    bs: ".offcanvas-body",
    we: ".we-offcanvas-body",
    props: propGroups.box
  },
  {
    name: "offcanvas close",
    heading: "Offcanvas Panel",
    bs: ".offcanvas .btn-close",
    we: ".we-offcanvas-panel .we-close-button",
    props: propGroups.button
  },
  {
    name: "offcanvas primary button",
    heading: "Offcanvas Panel",
    bs: ".offcanvas .btn-primary",
    we: ".we-offcanvas-panel .we-button-primary",
    props: propGroups.button
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
  { name: "navigation overview panel", heading: "Navigation", bs: ".tab-content", we: ".we-tab-content", props: propGroups.panel },
  { name: "sample section heading", heading: "Typography", bs: "h3", we: "h3", props: propGroups.sectionHeading },
  { name: "lead text", heading: "Typography", bs: ".lead", we: ".we-lead", props: propGroups.text },
  { name: "blockquote quote", heading: "Typography", bs: ".blockquote", we: ".we-blockquote-quote", props: propGroups.text },
  { name: "blockquote attribution", heading: "Typography", bs: ".blockquote-footer", we: ".we-blockquote-attrib", props: propGroups.text },
  { name: "blockquote attribution prefix", heading: "Typography", bs: ".blockquote-footer", we: ".we-blockquote-attrib", props: propGroups.pseudoText, pseudo: "::before", includeRect: false },
  { name: "buttons primary", heading: "Buttons And Badges", bs: ".btn-primary", we: ".we-button-primary", props: propGroups.button },
  { name: "buttons secondary", heading: "Buttons And Badges", bs: ".btn-secondary", we: ".we-button-secondary", props: propGroups.button },
  { name: "buttons light", heading: "Buttons And Badges", bs: ".btn-light", we: ".we-button-light", props: propGroups.button },
  { name: "buttons outline", heading: "Buttons And Badges", bs: ".btn-outline-primary", we: ".we-button-outline-primary", props: propGroups.button },
  { name: "buttons large", heading: "Buttons And Badges", bs: ".btn-lg", we: ".we-button-lg", props: propGroups.button },
  { name: "buttons small", heading: "Buttons And Badges", bs: ".btn-sm", we: ".we-button-sm", props: propGroups.button },
  { name: "badges primary", heading: "Buttons And Badges", bs: ".badge.text-bg-primary", we: ".we-badge-primary", props: propGroups.compact },
  { name: "badges secondary", heading: "Buttons And Badges", bs: ".badge.text-bg-secondary", we: ".we-badge-secondary", props: propGroups.compact },
  { name: "badges success", heading: "Buttons And Badges", bs: ".badge.text-bg-success", we: ".we-badge-success", props: propGroups.compact },
  { name: "badges danger", heading: "Buttons And Badges", bs: ".badge.text-bg-danger", we: ".we-badge-danger", props: propGroups.compact },
  { name: "card shell", heading: "Card", bs: ".card", we: ".we-card", props: propGroups.panel },
  { name: "card header", heading: "Card", bs: ".card-header", we: ".we-card-header", props: propGroups.compact },
  { name: "card body", heading: "Card", bs: ".card-body", we: ".we-card-body", props: propGroups.box },
  { name: "card title", heading: "Card", bs: ".card-title", we: ".we-card-title", props: propGroups.text },
  { name: "card subtitle", heading: "Card", bs: ".card-subtitle", we: ".we-card-subtitle", props: propGroups.text },
  { name: "card text", heading: "Card", bs: ".card-text", we: ".we-card-text", props: propGroups.text },
  { name: "card primary button", heading: "Card", bs: ".card-body .btn-primary", we: ".we-card-body .we-button-primary", props: propGroups.button },
  { name: "card link", heading: "Card", bs: ".card-link", we: ".we-card-action-text", props: propGroups.text },
  { name: "card footer", heading: "Card", bs: ".card-footer", we: ".we-card-footer", props: propGroups.box },
  { name: "list group active", heading: "List Group", bs: ".list-group-item.active", we: ".we-list-group-item.is-current", props: propGroups.button },
  { name: "list group item", heading: "List Group", bs: ".list-group-item:not(.active)", we: ".we-list-group-item:not(.is-current)", props: propGroups.button },
  { name: "table header", heading: "Table", bs: "thead th", we: "thead th", props: propGroups.compact },
  { name: "table cell", heading: "Table", bs: "tbody td", we: "tbody td", props: propGroups.compact },
  { name: "controls input", heading: "Controls", bs: ".form-control", we: ".we-input", props: propGroups.field },
  { name: "controls input small", heading: "Controls", bs: ".form-control-sm", we: ".we-input-sm", props: propGroups.field },
  { name: "controls input large", heading: "Controls", bs: ".form-control-lg", we: ".we-input-lg", props: propGroups.field },
  { name: "controls select", heading: "Controls", bs: ".form-select", we: "select.we-input", props: propGroups.field },
  { name: "controls checkbox", heading: "Controls", bs: ".form-check-input[type=checkbox]", we: ".we-checkbox", props: propGroups.field },
  { name: "controls label", heading: "Controls", bs: ".field-stack label", we: ".field-stack label", props: propGroups.labelText },
  { name: "controls checkbox label", heading: "Controls", bs: ".form-check-label", we: ".we-form-check > span", props: propGroups.labelText },
  { name: "controls switch label", heading: "Controls", bs: ".form-switch .form-check-label", we: ".we-switch-row.we-form-check > span", props: propGroups.flexLabelText },
  { name: "dialog panel", heading: "Dialog", bs: ".modal-content", we: ".we-dialog-panel", props: propGroups.panel },
  { name: "dialog header", heading: "Dialog", bs: ".modal-header", we: ".we-dialog-header", props: propGroups.box },
  { name: "dialog title", heading: "Dialog", bs: ".modal-title", we: ".we-dialog-title", props: propGroups.text },
  { name: "dialog body", heading: "Dialog", bs: ".modal-body", we: ".we-dialog-body", props: propGroups.box },
  { name: "dialog footer", heading: "Dialog", bs: ".modal-footer", we: ".we-dialog-footer", props: propGroups.box },
  { name: "dialog close", heading: "Dialog", bs: ".modal-header .btn-close", we: ".we-dialog-header .we-dialog-close", props: propGroups.button },
  { name: "dialog secondary button", heading: "Dialog", bs: ".modal-footer .btn-secondary", we: ".we-dialog-footer .we-button-secondary", props: propGroups.button },
  { name: "dialog primary button", heading: "Dialog", bs: ".modal-footer .btn-primary", we: ".we-dialog-footer .we-button-primary", props: propGroups.button },
  { name: "accordion trigger", heading: "Accordion", bs: ".accordion-button", we: ".we-accordion-trigger", props: propGroups.button },
  { name: "accordion collapsed trigger", heading: "Accordion", bs: ".accordion-button.collapsed", we: ".we-accordion-trigger:not(.is-open)", props: propGroups.button },
  { name: "accordion body", heading: "Accordion", bs: ".accordion-body", we: ".we-accordion-content", props: propGroups.panel },
  { name: "alert warning", heading: "Alerts And Toasts", bs: ".alert-warning", we: ".we-alert-warning", props: propGroups.panel },
  { name: "alert title", heading: "Alerts And Toasts", bs: ".alert-warning strong", we: ".we-alert-warning .we-alert-title", props: propGroups.text },
  { name: "alert link", heading: "Alerts And Toasts", bs: ".alert-warning .alert-link", we: ".we-alert-warning .we-alert-link", props: propGroups.text },
  { name: "toast panel", heading: "Alerts And Toasts", bs: ".toast", we: ".we-toast", props: propGroups.panel },
  { name: "toast header", heading: "Alerts And Toasts", bs: ".toast-header", we: ".we-toast-header", props: propGroups.compact },
  { name: "toast title", heading: "Alerts And Toasts", bs: ".toast-header strong", we: ".we-toast-title", props: propGroups.text },
  { name: "toast meta", heading: "Alerts And Toasts", bs: ".toast-header small", we: ".we-toast-meta", props: propGroups.text },
  { name: "toast body", heading: "Alerts And Toasts", bs: ".toast-body", we: ".we-toast-message", props: propGroups.text },
  { name: "breadcrumb link", heading: "Breadcrumb And Pagination", bs: ".breadcrumb-item a", we: ".we-breadcrumb-item:not(.is-current) .we-breadcrumb-link", props: propGroups.button },
  { name: "pagination active", heading: "Breadcrumb And Pagination", bs: ".page-item.active .page-link", we: ".we-page-btn.is-current", props: propGroups.button },
  { name: "progress shell", heading: "Progress", bs: ".progress", we: ".we-progress-demo", props: propGroups.panel },
  { name: "progress success bar", heading: "Progress", bs: ".progress-bar.bg-success", we: ".we-progress-fill-success", props: propGroups.compact },
  { name: "progress info bar", heading: "Progress", bs: ".progress-bar.bg-info", we: ".we-progress-fill-info", props: propGroups.compact },
  { name: "spinner border icon", heading: "Spinners", bs: ".spinner-border.text-primary", we: ".we-spinner.we-text-primary .we-spinner-icon", props: propGroups.spinnerIcon },
  { name: "placeholder text", heading: "Placeholders", bs: ".placeholder.text-primary", we: ".we-placeholder.we-text-primary", props: propGroups.placeholder },
  { name: "alert success", heading: "Alert Variants", bs: ".alert-success", we: ".we-alert-success", props: propGroups.panel },
  { name: "alert danger", heading: "Alert Variants", bs: ".alert-danger", we: ".we-alert-danger", props: propGroups.panel },
  { name: "alert close", heading: "Alert Variants", bs: ".alert-dismissible .btn-close", we: ".we-alert .we-alert-dismiss", props: propGroups.alertClose },
  { name: "list group variants active", heading: "List Group Variants", bs: ".list-group-item.active", we: ".we-list-group-item.is-current", props: propGroups.button },
  { name: "table variants active row", heading: "Table Variants", bs: "tr.table-active td", we: "tr.we-table-row-active td", props: propGroups.tableState },
  { name: "table variants striped row", heading: "Table Variants", bs: ".table-striped > tbody > tr:nth-of-type(odd) td", we: ".we-table-striped > tbody > tr:nth-of-type(odd) td", props: propGroups.tableState },
  { name: "table variants primary row", heading: "Table Variants", bs: ".table-tone-demo tr.table-primary td", we: ".we-table-tone-demo tr.we-table-row-primary td", props: propGroups.tableState },
  { name: "table variants secondary row", heading: "Table Variants", bs: ".table-tone-demo tr.table-secondary td", we: ".we-table-tone-demo tr.we-table-row-secondary td", props: propGroups.tableState },
  { name: "table variants success row", heading: "Table Variants", bs: ".table-tone-demo tr.table-success td", we: ".we-table-tone-demo tr.we-table-row-success td", props: propGroups.tableState },
  { name: "table variants info row", heading: "Table Variants", bs: ".table-tone-demo tr.table-info td", we: ".we-table-tone-demo tr.we-table-row-info td", props: propGroups.tableState },
  { name: "table variants warning row", heading: "Table Variants", bs: ".table-tone-demo tr.table-warning td", we: ".we-table-tone-demo tr.we-table-row-warning td", props: propGroups.tableState },
  { name: "table variants danger row", heading: "Table Variants", bs: ".table-tone-demo tr.table-danger td", we: ".we-table-tone-demo tr.we-table-row-danger td", props: propGroups.tableState },
  { name: "table variants light row", heading: "Table Variants", bs: ".table-tone-demo tr.table-light td", we: ".we-table-tone-demo tr.we-table-row-light td", props: propGroups.tableState },
  { name: "table variants dark row", heading: "Table Variants", bs: ".table-tone-demo tr.table-dark td", we: ".we-table-tone-demo tr.we-table-row-dark td", props: propGroups.tableState },
  { name: "table variants small cell", heading: "Table Variants", bs: ".table-sm tbody td", we: ".we-table-sm tbody td", props: propGroups.tableState },
  { name: "table variants borderless cell", heading: "Table Variants", bs: ".table-borderless tbody td", we: ".we-table-borderless tbody td", props: propGroups.tableState },
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
  { name: "form select small", heading: "Form Select Variants", bs: ".form-select-sm", we: "select.we-input-sm", props: propGroups.field },
  { name: "form select large", heading: "Form Select Variants", bs: ".form-select-lg", we: "select.we-input-lg", props: propGroups.field },
  { name: "form select disabled", heading: "Form Select Variants", bs: ".form-select:disabled", we: "select.we-input:disabled", props: propGroups.field },
  { name: "menu trigger", heading: "Menus And Dropdowns", bs: ".dropdown-toggle", we: ".we-menu-label", props: propGroups.button },
  { name: "menu trigger arrow", heading: "Menus And Dropdowns", bs: ".dropdown-toggle", we: ".we-menu-label", props: propGroups.arrowTriangle, pseudo: "::after", includeRect: false },
  { name: "menu popup", heading: "Menus And Dropdowns", bs: ".dropdown-menu", we: ".we-menu-popup", props: propGroups.panel },
  { name: "menu header", heading: "Menus And Dropdowns", bs: ".dropdown-header", we: ".we-menu-header", props: propGroups.text },
  { name: "menu divider", heading: "Menus And Dropdowns", bs: ".dropdown-divider", we: ".we-menu-popup .we-divider", props: propGroups.divider },
  { name: "menu active item", heading: "Menus And Dropdowns", bs: ".dropdown-item.active", we: ".we-menu-item.is-current", props: propGroups.button },
  { name: "menu text item", heading: "Menus And Dropdowns", bs: ".dropdown-item-text", we: ".we-menu-text", props: propGroups.text },
  { name: "menu disabled item", heading: "Menus And Dropdowns", bs: ".dropdown-item.disabled", we: ".we-menu-item.is-disabled", props: propGroups.button },
  { name: "menu normal item", heading: "Menus And Dropdowns", bs: ".dropdown-item:not(.active)", we: ".we-menu-item:not(.is-current)", props: propGroups.button },
  { name: "tooltip bubble", heading: "Tooltip And Popover", bs: ".tooltip-inner", we: ".we-tooltip-bubble", props: propGroups.panel },
  { name: "tooltip arrow triangle", heading: "Tooltip And Popover", bs: ".tooltip .tooltip-arrow", we: ".we-tooltip-bubble", props: propGroups.arrowTriangle, pseudo: "::before", includeRect: false },
  { name: "popover panel", heading: "Tooltip And Popover", bs: ".popover", we: ".we-popover-panel", props: propGroups.panel },
  { name: "popover arrow border", heading: "Tooltip And Popover", bs: ".popover > .popover-arrow", we: ".we-popover-arrow", props: propGroups.arrowTriangle, pseudo: "::before", includeRect: false },
  { name: "popover arrow fill", heading: "Tooltip And Popover", bs: ".popover > .popover-arrow", we: ".we-popover-arrow", props: propGroups.arrowTriangle, pseudo: "::after", includeRect: false },
  { name: "popover title", heading: "Tooltip And Popover", bs: ".popover-header", we: ".we-popover-header", props: propGroups.text },
  { name: "popover body", heading: "Tooltip And Popover", bs: ".popover-body", we: ".we-popover-body", props: propGroups.box },
  { name: "button group first", heading: "Button Groups", bs: ".btn-group .btn:first-child", we: ".we-button-group .we-button:first-child", props: propGroups.button },
  { name: "button group active", heading: "Button Groups", bs: ".btn-group .btn.active", we: ".we-button-group .we-button.is-active", props: propGroups.button },
  { name: "button group last", heading: "Button Groups", bs: ".btn-group .btn:last-child", we: ".we-button-group .we-button:last-child", props: propGroups.button },
  { name: "button group vertical", heading: "Button Groups", bs: ".btn-group-vertical .btn-secondary", we: ".we-button-group-vertical .we-button-secondary", props: propGroups.button },
  { name: "button group vertical last", heading: "Button Groups", bs: ".btn-group-vertical .btn:last-child", we: ".we-button-group-vertical .we-button:last-child", props: propGroups.button },
  { name: "input group wrapper", heading: "Input Groups And Validation", bs: ".input-group", we: ".we-input-group", props: propGroups.panel },
  { name: "input group addon", heading: "Input Groups And Validation", bs: ".input-group-text", we: ".we-input-group-text", props: propGroups.field },
  { name: "input group field", heading: "Input Groups And Validation", bs: ".input-group .form-control", we: ".we-input-group .we-input", props: propGroups.field },
  { name: "input group button", heading: "Input Groups And Validation", bs: ".input-group .btn-outline-secondary", we: ".we-input-group .we-button-outline-secondary", props: propGroups.button },
  { name: "input group small addon", heading: "Input Groups And Validation", bs: ".input-group-sm .input-group-text", we: ".we-input-group-sm .we-input-group-text", props: propGroups.field },
  { name: "input group small field", heading: "Input Groups And Validation", bs: ".input-group-sm .form-control", we: ".we-input-group-sm .we-input", props: propGroups.field },
  { name: "input group small button", heading: "Input Groups And Validation", bs: ".input-group-sm .btn-outline-secondary", we: ".we-input-group-sm .we-button-outline-secondary", props: propGroups.button },
  { name: "input group large addon", heading: "Input Groups And Validation", bs: ".input-group-lg .input-group-text", we: ".we-input-group-lg .we-input-group-text", props: propGroups.field },
  { name: "input group large select", heading: "Input Groups And Validation", bs: ".input-group-lg .form-select", we: ".we-input-group-lg select.we-input", props: propGroups.field },
  { name: "input group large button", heading: "Input Groups And Validation", bs: ".input-group-lg .btn-outline-secondary", we: ".we-input-group-lg .we-button-outline-secondary", props: propGroups.button },
  { name: "valid input", heading: "Input Groups And Validation", bs: ".form-control.is-valid", we: ".we-input.is-valid", props: propGroups.field },
  { name: "invalid input", heading: "Input Groups And Validation", bs: ".form-control.is-invalid", we: ".we-input.is-invalid", props: propGroups.field },
  { name: "valid feedback", heading: "Input Groups And Validation", bs: ".valid-feedback", we: ".we-feedback.is-valid", props: propGroups.text },
  { name: "invalid feedback", heading: "Input Groups And Validation", bs: ".invalid-feedback", we: ".we-feedback.is-invalid", props: propGroups.text },
  { name: "radio row", heading: "Radio Group", bs: ".form-check", we: ".we-choice-row", props: propGroups.formCheckRow, includeRect: false },
  { name: "radio input", heading: "Radio Group", bs: ".form-check-input[type=radio]", we: ".we-radio-input", props: propGroups.field },
  { name: "radio unchecked input", heading: "Radio Group", bs: ".form-check-input[type=radio]:not(:checked)", we: ".we-radio-input:not(:checked)", props: propGroups.field },
  { name: "radio label", heading: "Radio Group", bs: ".form-check-label", we: ".we-choice-row > span", props: propGroups.labelText },
  { name: "range input", heading: "Range And Switches", bs: ".form-range", we: ".we-range", props: propGroups.field },
  { name: "range label", heading: "Range And Switches", bs: ".field-stack label", we: ".field-stack label", props: propGroups.labelText },
  { name: "switch input", heading: "Range And Switches", bs: ".form-switch .form-check-input", we: ".we-switch-control", props: propGroups.field },
  { name: "switch unchecked input", heading: "Range And Switches", bs: ".form-switch .form-check-input:not(:checked)", we: ".we-switch-control:not(:checked)", props: propGroups.field },
  { name: "switch label", heading: "Range And Switches", bs: ".form-switch .form-check-label", we: ".we-switch-row label", props: propGroups.flexLabelText },
  { name: "disabled primary", heading: "Disabled States", bs: ".btn-primary:disabled", we: ".we-button-primary:disabled", props: propGroups.button },
  { name: "disabled outline secondary", heading: "Disabled States", bs: ".btn-outline-secondary:disabled", we: ".we-button-outline-secondary:disabled", props: propGroups.button },
  { name: "disabled input", heading: "Disabled States", bs: ".form-control:disabled", we: ".we-input:disabled", props: propGroups.field },
  { name: "disabled checkbox", heading: "Disabled States", bs: ".form-check-input:disabled", we: ".we-checkbox:disabled", props: propGroups.field },
  { name: "disabled checkbox label", heading: "Disabled States", bs: ".form-check-input:disabled ~ .form-check-label", we: ".we-checkbox:disabled ~ span", props: propGroups.labelText },
  { name: "textarea", heading: "Textarea And Helper Text", bs: "textarea.form-control", we: "textarea.we-input", props: propGroups.field },
  { name: "helper text", heading: "Textarea And Helper Text", bs: ".form-text", we: ".we-help-text", props: propGroups.text },
  { name: "checkbox group input", heading: "Checkbox Group", bs: ".form-check-input", we: ".we-checkbox", props: propGroups.field },
  { name: "checkbox group unchecked input", heading: "Checkbox Group", bs: ".form-check-input:not(:checked)", we: ".we-checkbox:not(:checked)", props: propGroups.field },
  { name: "checkbox group label", heading: "Checkbox Group", bs: ".form-check-label", we: ".we-choice-row > span", props: propGroups.labelText },
  { name: "carousel viewport", heading: "Carousel", bs: ".carousel-inner", we: ".we-carousel-viewport", props: propGroups.carouselViewport },
  { name: "carousel prev control", heading: "Carousel", bs: ".carousel-control-prev", we: ".we-carousel-prev", props: propGroups.carouselControl },
  { name: "carousel next control", heading: "Carousel", bs: ".carousel-control-next", we: ".we-carousel-next", props: propGroups.carouselControl },
  { name: "carousel indicator", heading: "Carousel", bs: ".carousel-indicators [data-bs-target]:not(.active)", we: ".we-carousel-indicator:not(.is-current)", props: propGroups.carouselIndicator },
  { name: "carousel active indicator", heading: "Carousel", bs: ".carousel-indicators [data-bs-target].active", we: ".we-carousel-indicator.is-current", props: propGroups.carouselIndicator }
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

    const bsRoot = document.querySelector(".bs-preview");
    const weRoot = document.querySelector(".we-preview");
    const bsSection = testCase.heading ? sectionByHeading(".bs-preview", testCase.heading) : bsRoot;
    const weSection = testCase.heading ? sectionByHeading(".we-preview", testCase.heading) : weRoot;
    const bsElement = testCase.heading ? bsSection?.querySelector(testCase.bs) || null : bsRoot?.matches(testCase.bs) ? bsRoot : bsRoot?.querySelector(testCase.bs) || null;
    const weElement = testCase.heading ? weSection?.querySelector(testCase.we) || null : weRoot?.matches(testCase.we) ? weRoot : weRoot?.querySelector(testCase.we) || null;
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
  if (verbose) return diffs;
  const priority = [
    "selector",
    "content",
    "width",
    "height",
    "color",
    "backgroundColor",
    "backgroundImage",
    "textShadow",
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
    .slice(0, 8);
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
      await page.goto(url, { waitUntil: "domcontentloaded", timeout: 30000 });
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
