if (typeof WebAssembly.Tag === 'undefined' || typeof WebAssembly.Exception === 'undefined') {
  throw new Error('WebRacket requires WebAssembly exception handling (Tag + Exception).');
}

const foreign_error_tag = new WebAssembly.Tag({ parameters: ['externref'] });

function wrap_ffi_host_exceptions(fn) {
  return (...args) => {
    try {
      return fn(...args);
    } catch (err) {
      if (err instanceof WebAssembly.Exception) {
        throw err;
      }
      throw new WebAssembly.Exception(foreign_error_tag, [err]);
    }
  };
}

const ffiExceptionBridgeSkipModules =
  new Set(['env', 'primitives', 'math', 'char', 'core', 'provider', 'ffi']);

function is_ffi_exception_bridge_module(moduleName) {
  return !ffiExceptionBridgeSkipModules.has(moduleName);
}

function install_ffi_exception_bridge(imports) {
  // IMPORTANT:
  // Wrap only user FFI modules here (the modules loaded from `.ffi` files).
  // Do *not* wrap core runtime modules:
  // - env: memory import table, not foreign procedure calls
  // - primitives/math/char: internal runtime imports used all over the VM
  //
  // Reason: only calls produced via define-foreign are wrapped in wasm
  // with a `(catch $ffi-host-exn ...)` path. If we also wrapped core modules,
  // internal runtime errors would be rethrown as foreign-call exceptions and
  // could bypass the intended internal error handling/debug flow.
  for (const [moduleName, table] of Object.entries(imports)) {
    if (!is_ffi_exception_bridge_module(moduleName)) {
      continue;
    }
    if (!table || typeof table !== 'object') {
      continue;
    }
    for (const key of Object.keys(table)) {
      const value = table[key];
      if (typeof value === 'function') {
        table[key] = wrap_ffi_host_exceptions(value);
      }
    }
  }
}

function assert_ffi_exception_bridge_visible_imports(module, imports, label) {
  const required = new Map();
  for (const spec of WebAssembly.Module.imports(module)) {
    if (spec.kind !== 'function' || !is_ffi_exception_bridge_module(spec.module)) {
      continue;
    }
    if (!required.has(spec.module)) {
      required.set(spec.module, new Set());
    }
    required.get(spec.module).add(spec.name);
  }

  for (const [moduleName, names] of required.entries()) {
    const table = imports[moduleName];
    if (!table || typeof table !== 'object') {
      throw new Error(
        `FFI import table '${moduleName}' required by ${label} must be an object`
      );
    }
    const prototype = Object.getPrototypeOf(table);
    if (prototype !== Object.prototype && prototype !== null) {
      throw new Error(
        `FFI import table '${moduleName}' required by ${label} must be a plain object`
      );
    }
    for (const name of names) {
      const descriptor = Object.getOwnPropertyDescriptor(table, name);
      if (!descriptor || !descriptor.enumerable) {
        throw new Error(
          `FFI import '${moduleName}.${name}' required by ${label} must be an own enumerable function so host exceptions can be bridged`
        );
      }
      if (typeof table[name] !== 'function') {
        throw new Error(
          `FFI import '${moduleName}.${name}' required by ${label} must be a function`
        );
      }
    }
  }
}

function call_console_fallback(name, fallbackName, args) {
  const target = typeof console === 'undefined' ? null : console;
  if (!target) {
    return;
  }

  const method = typeof target[name] === 'function'
    ? target[name]
    : fallbackName && typeof target[fallbackName] === 'function'
      ? target[fallbackName]
      : null;
  if (method) {
    return method.call(target, ...args);
  }
}

function decode_js_send_args(args) {
  return from_fasl(args) || [];
}

function require_js_target(obj, who) {
  if (obj === null || obj === undefined) {
    throw new Error(`${who}: target object is null or undefined`);
  }
  return obj;
}

function call_js_method(obj, name, args, who) {
  const target = require_js_target(obj, who);
  const methodName = from_fasl(name);
  const method = target[methodName];
  if (typeof method !== 'function') {
    throw new Error(`${who}: method ${String(methodName)} not available in this environment`);
  }
  return method.apply(target, decode_js_send_args(args));
}

function call_array_static_method(methodName, args = []) {
  return require_host_function(Array,
                               methodName,
                               `Array.${methodName}`)(...args);
}

function call_array_method(arr, methodName, args = []) {
  return require_host_function(arr,
                               methodName,
                               `Array.${methodName}`)(...args);
}

function call_number_method(x, methodName, args = []) {
  return require_host_function(x,
                               methodName,
                               `Number.${methodName}`)(...args);
}

function call_jsxgraph_board_create(board, elementType, parents, attrs) {
  const create = require_host_function(board,
                                       'create',
                                       'JSXGraph Board.create');
  return create(elementType, from_fasl(parents), from_fasl(attrs));
}

function call_jsxgraph_board_method(board, methodName, args = []) {
  const method = require_host_function(board,
                                       methodName,
                                       `JSXGraph Board.${methodName}`);
  return method(...args);
}

function call_jsxgraph_method(owner, ownerName, methodName, args = []) {
  const method = require_host_function(owner,
                                       methodName,
                                       `JSXGraph ${ownerName}.${methodName}`);
  return method(...args);
}

function get_window_property(name) {
  return get_required_host_property(typeof window === 'undefined' ? null : window,
                                    name,
                                    `window.${name}`);
}

function set_window_property(name, value) {
  set_required_host_property(typeof window === 'undefined' ? null : window,
                             name,
                             value,
                             `window.${name}`);
}

function require_document_target(displayName) {
  return require_host_target(typeof document === 'undefined' ? null : document,
                             displayName);
}

function require_document_value(name, displayName) {
  return require_host_value(typeof document === 'undefined' ? null : document,
                            name,
                            displayName);
}

function get_performance_property(name) {
  return get_required_host_property(typeof performance === 'undefined' ? null : performance,
                                    name,
                                    `performance.${name}`);
}

function get_performance_event_counts_property(counts, name) {
  return get_required_host_property(counts, name, `PerformanceEventCounts.${name}`);
}

function get_performance_memory_info_property(mem, name) {
  return get_required_host_property(mem, name, `PerformanceMemory.${name}`);
}

function get_xterm_terminal_property(term, name) {
  return get_required_host_property(term, name, `xterm.js Terminal.${name}`);
}

function set_xterm_terminal_property(term, name, value) {
  set_required_host_property(term, name, value, `xterm.js Terminal.${name}`);
}

function get_canvas_element_property(canvas, name) {
  return get_required_host_property(canvas, name, `canvas.${name}`);
}

function set_canvas_element_property(canvas, name, value) {
  set_required_host_property(canvas, name, value, `canvas.${name}`);
}

function get_canvas_2d_property(ctx, name) {
  return get_required_host_property(ctx, name, `CanvasRenderingContext2D.${name}`);
}

function set_canvas_2d_property(ctx, name, value) {
  set_required_host_property(ctx, name, value, `CanvasRenderingContext2D.${name}`);
}

function get_image_data_property(data, name) {
  return get_required_host_property(data, name, `ImageData.${name}`);
}

function get_text_metrics_property(metrics, name) {
  return get_required_host_property(metrics, name, `TextMetrics.${name}`);
}

function get_dom_matrix_property(matrix, name) {
  return get_required_host_property(matrix, name, `DOMMatrix.${name}`);
}

function get_media_property(media, name) {
  return get_required_host_property(media, name, `HTMLMediaElement.${name}`);
}

function set_media_property(media, name, value) {
  set_required_host_property(media, name, value, `HTMLMediaElement.${name}`);
}

function get_image_property(img, name) {
  return get_required_host_property(img, name, `HTMLImageElement.${name}`);
}

function set_image_property(img, name, value) {
  set_required_host_property(img, name, value, `HTMLImageElement.${name}`);
}

function get_event_property(evt, name) {
  return get_required_host_property(evt, name, `Event.${name}`);
}

function get_mouse_event_property(evt, name) {
  return get_required_host_property(evt, name, `MouseEvent.${name}`);
}

function get_keyboard_event_property(evt, name) {
  return get_required_host_property(evt, name, `KeyboardEvent.${name}`);
}

function get_touch_event_property(evt, name) {
  return get_required_host_property(evt, name, `TouchEvent.${name}`);
}

function get_message_event_property(evt, name) {
  return get_required_host_property(evt, name, `MessageEvent.${name}`);
}

function get_close_event_property(evt, name) {
  return get_required_host_property(evt, name, `CloseEvent.${name}`);
}

function get_touch_list_property(xs, name) {
  return get_required_host_property(xs, name, `TouchList.${name}`);
}

function get_touch_property(touch, name) {
  return get_required_host_property(touch, name, `Touch.${name}`);
}

function get_dom_rect_property(rect, name) {
  return get_required_host_property(rect, name, `DOMRect.${name}`);
}

function get_element_property(elem, name) {
  return get_required_host_property(elem, name, `Element.${name}`);
}

function set_element_property(elem, name, value) {
  set_required_host_property(elem, name, value, `Element.${name}`);
}

function get_dom_token_list_property(list, name) {
  return get_required_host_property(list, name, `DOMTokenList.${name}`);
}

function get_node_list_property(list, name) {
  return get_required_host_property(list, name, `NodeList.${name}`);
}

function get_html_collection_property(list, name) {
  return get_required_host_property(list, name, `HTMLCollection.${name}`);
}

function get_shadow_root_property(root, name) {
  return get_required_host_property(root, name, `ShadowRoot.${name}`);
}

function get_dom_rect_list_property(list, name) {
  return get_required_host_property(list, name, `DOMRectList.${name}`);
}

function get_jsxgraph_board_property(board, name) {
  return get_required_host_property(board, name, `JSXGraph Board.${name}`);
}

function get_jsxgraph_point_property(pt, name) {
  return get_required_host_property(pt, name, `JSXGraph Point.${name}`);
}

function set_jsxgraph_point_property(pt, name, value) {
  set_required_host_property(pt, name, value, `JSXGraph Point.${name}`);
}

function construct_js_value(ctor, args) {
  if (ctor === null || ctor === undefined) {
    throw new Error('js-new: constructor is null or undefined');
  }
  if (typeof ctor !== 'function') {
    throw new Error(`js-new: expected constructor function, got ${typeof ctor}`);
  }
  return new ctor(...decode_js_send_args(args));
}

var imports = {
    // Core Wasm runtime imports.
    'env': {
        'memory': memory
    },

    // WebRacket runtime primitive imports.
    'primitives': {
      // Diagnostics, callbacks, and output.
      'console_log': ((x)   => console.error(x)),
      'add':         ((x,y) => x+y),
      'foreign_error_tag': foreign_error_tag,
      'make_callback': make_callback,
      'js_output':   ((x)   => output_string.push(x)),
      'js_print_fasl': ((start, len) => {
        const bytes = new Uint8Array(memory.buffer).slice(start, start + len);
        const [v] = fasl_to_js_value(bytes);
        console.log(v);
      }),

      // Time and date.
      'current_inexact_milliseconds': (() => Date.now()),
      'current_milliseconds_bits': (() => {
        const modulus = 0x40000000;
        let n = Math.trunc(Date.now()) % modulus;
        if (n >= 0x20000000) n -= modulus;
        return (n << 1) | 0;
      }),
      'date_field': ((seconds, local, field) => {
        const d = new Date(seconds * 1000);
        const get = local ? {
          year: () => d.getFullYear(),
          month: () => d.getMonth() + 1,
          day: () => d.getDate(),
          hour: () => d.getHours(),
          minute: () => d.getMinutes(),
          second: () => d.getSeconds(),
          weekDay: () => d.getDay(),
          offset: () => -d.getTimezoneOffset() * 60
        } : {
          year: () => d.getUTCFullYear(),
          month: () => d.getUTCMonth() + 1,
          day: () => d.getUTCDate(),
          hour: () => d.getUTCHours(),
          minute: () => d.getUTCMinutes(),
          second: () => d.getUTCSeconds(),
          weekDay: () => d.getUTCDay(),
          offset: () => 0
        };
        const yearDay = (() => {
          const start = local
            ? new Date(get.year(), 0, 1)
            : new Date(Date.UTC(get.year(), 0, 1));
          const now = local
            ? new Date(get.year(), d.getMonth(), d.getDate())
            : new Date(Date.UTC(get.year(), d.getUTCMonth(), d.getUTCDate()));
          return Math.floor((now - start) / 86400000);
        });
        const dst = (() => {
          if (!local) return 0;
          const jan = new Date(get.year(), 0, 1).getTimezoneOffset();
          const jul = new Date(get.year(), 6, 1).getTimezoneOffset();
          return d.getTimezoneOffset() < Math.max(jan, jul) ? 1 : 0;
        });
        // WebRacket currently represents exact integers as small fixnums, while
        // Racket's date* nanosecond range extends to 999,999,999. Preserve a
        // safe exact value until larger exact integers are available.
        const nanos = (() => 0);
        switch (field) {
          case 0: return get.second();
          case 1: return get.minute();
          case 2: return get.hour();
          case 3: return get.day();
          case 4: return get.month();
          case 5: return get.year();
          case 6: return get.weekDay();
          case 7: return yearDay();
          case 8: return dst();
          case 9: return get.offset();
          case 10: return nanos();
          default: return 0;
        }
      }),

      // Virtual filesystem.
      'vfs_stat_kind': ((start, len) => {
        try {
          const stat = webracketVFS.stat(vfs_path_from_memory(start, len));
          if (stat.type === 'file') return 1;
          if (stat.type === 'directory') return 2;
          return 0;
        } catch (_) {
          return 0;
        }
      }),
      'vfs_file_size': ((start, len) => {
        try {
          const stat = webracketVFS.stat(vfs_path_from_memory(start, len));
          return stat.type === 'file' ? stat.size : -1;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_stat': ((pathStart, pathLen, outStart, outMax) => {
        try {
          const stat = webracketVFS.stat(vfs_path_from_memory(pathStart, pathLen));
          if (stat.type === 'missing') return -1;
          const mtime = stat.mtime || 0;
          const payload = [
            Symbol.for('device-id'), 0,
            Symbol.for('inode'), stat.identity || 0,
            Symbol.for('mode'), stat.mode || 0,
            Symbol.for('hardlink-count'), 1,
            Symbol.for('user-id'), 0,
            Symbol.for('group-id'), 0,
            Symbol.for('device-id-for-special-file'), 0,
            Symbol.for('size'), stat.size || 0,
            Symbol.for('block-size'), 0,
            Symbol.for('block-count'), 0,
            Symbol.for('access-time-seconds'), mtime,
            Symbol.for('modify-time-seconds'), mtime,
            Symbol.for('change-time-seconds'), mtime,
            Symbol.for('creation-time-seconds'), mtime,
            Symbol.for('access-time-nanoseconds'), 0,
            Symbol.for('modify-time-nanoseconds'), 0,
            Symbol.for('change-time-nanoseconds'), 0,
            Symbol.for('creation-time-nanoseconds'), 0
          ];
          const bytes = js_value_to_fasl(payload);
          if (bytes.length > outMax) return -2;
          new Uint8Array(memory.buffer).set(bytes, outStart);
          return bytes.length;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_read_file': ((pathStart, pathLen, outStart, outMax) => {
        try {
          const bytes = webracketVFS.readFile(vfs_path_from_memory(pathStart, pathLen));
          if (bytes.length > outMax) return -2;
          new Uint8Array(memory.buffer).set(bytes, outStart);
          return bytes.length;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_write_file': ((pathStart, pathLen, bytesStart, bytesLen) => {
        try {
          const bytes = new Uint8Array(memory.buffer).slice(bytesStart, bytesStart + bytesLen);
          webracketVFS.writeFile(vfs_path_from_memory(pathStart, pathLen), bytes);
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_delete_file': ((pathStart, pathLen) => {
        try {
          webracketVFS.deleteFile(vfs_path_from_memory(pathStart, pathLen));
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_delete_directory': ((pathStart, pathLen) => {
        try {
          webracketVFS.deleteDirectory(vfs_path_from_memory(pathStart, pathLen));
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_delete_directory_files': ((pathStart, pathLen) => {
        try {
          webracketVFS.deleteTree(vfs_path_from_memory(pathStart, pathLen));
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_make_directory': ((pathStart, pathLen) => {
        try {
          webracketVFS.mkdir(vfs_path_from_memory(pathStart, pathLen));
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_make_directory_star': ((pathStart, pathLen) => {
        try {
          webracketVFS.mkdirp(vfs_path_from_memory(pathStart, pathLen));
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_make_parent_directory_star': ((pathStart, pathLen) => {
        try {
          webracketVFS.makeParentDirectory(vfs_path_from_memory(pathStart, pathLen));
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_root_list': ((outStart, outMax) => {
        try {
          const bytes = js_value_to_fasl(webracketVFS.rootList());
          if (bytes.length > outMax) return -2;
          new Uint8Array(memory.buffer).set(bytes, outStart);
          return bytes.length;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_list_directory': ((pathStart, pathLen, outStart, outMax) => {
        try {
          const names = webracketVFS.listDir(vfs_path_from_memory(pathStart, pathLen));
          const bytes = js_value_to_fasl(names);
          if (bytes.length > outMax) return -2;
          new Uint8Array(memory.buffer).set(bytes, outStart);
          return bytes.length;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_rename': ((oldStart, oldLen, newStart, newLen, existsOk) => {
        try {
          webracketVFS.rename(
            vfs_path_from_memory(oldStart, oldLen),
            vfs_path_from_memory(newStart, newLen),
            existsOk !== 0);
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_copy_file': ((srcStart, srcLen, destStart, destLen, existsOk) => {
        try {
          webracketVFS.copyFile(
            vfs_path_from_memory(srcStart, srcLen),
            vfs_path_from_memory(destStart, destLen),
            existsOk !== 0);
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_copy_directory_files': ((srcStart, srcLen, destStart, destLen) => {
        try {
          webracketVFS.copyTree(
            vfs_path_from_memory(srcStart, srcLen),
            vfs_path_from_memory(destStart, destLen));
          return 0;
        } catch (_) {
          return -1;
        }
      }),
      'vfs_modify_seconds': ((pathStart, pathLen, hasSecs, secs) => {
        try {
          return webracketVFS.modifySeconds(
            vfs_path_from_memory(pathStart, pathLen),
            hasSecs !== 0 ? secs : undefined);
        } catch (_) {
          return -1;
        }
      }),
      'vfs_permissions': ((pathStart, pathLen, setMode, mode) => {
        try {
          return webracketVFS.permissions(
            vfs_path_from_memory(pathStart, pathLen),
            setMode !== 0 ? mode : undefined);
        } catch (_) {
          return -1;
        }
      }),
      'vfs_identity': ((pathStart, pathLen) => {
        try {
          return webracketVFS.identity(vfs_path_from_memory(pathStart, pathLen));
        } catch (_) {
          return -1;
        }
      }),

      // External values and FFI bridge helpers.
      'register_external': (obj => { externals.push(obj); return externals.length - 1; }),
      'lookup_external':   (idx => externals[idx]),
      'external_number_to_f64': (obj =>
        (typeof obj === 'number'
         ? obj
         : (obj instanceof Number ? obj.valueOf() : NaN))),
      'flonum_to_string': (x =>
        to_fasl(flonum_to_racket_string(x))),
      'external_string_to_string': (obj =>
        (typeof obj === 'string'
         ? to_string(obj)
         : (obj instanceof String ? to_string(obj.valueOf())
                                   : to_string(String(obj))))),
      'external_nullish': (obj => ((obj === null) || (obj === undefined)) ? 1 : 0),
      'external_undefined': (obj => (obj === undefined) ? 1 : 0),

      // Unicode character operations.
      'char_upcase': ((cp) => {
        const s = String.fromCodePoint(cp).toUpperCase();
        const arr = Array.from(s);
        return (arr.length === 1) ? arr[0].codePointAt(0) : cp;
      }),
      'char_downcase': ((cp) => {
        const s = String.fromCodePoint(cp).toLowerCase();
        const arr = Array.from(s);
        return (arr.length === 1) ? arr[0].codePointAt(0) : cp;
      }),
      'char_titlecase': ((cp) => {
        const lower = String.fromCodePoint(cp).toLocaleLowerCase();
        const title = lower.charAt(0).toLocaleUpperCase() + lower.slice(1);
        const arr = Array.from(title);
        return (arr.length === 1) ? arr[0].codePointAt(0) : cp;
      }),
      'char_foldcase': ((cp) => {
        // JavaScript has no direct Unicode foldcase API, but upper-then-lower
        // fixes the final sigma case while preserving our single-codepoint guard.
        const s = String.fromCodePoint(cp).toUpperCase().toLowerCase();
        const arr = Array.from(s);
        return (arr.length === 1) ? arr[0].codePointAt(0) : cp;
      }),
      // NOTE: This classification covers only a subset of Unicode's
      // grapheme break property table and should be expanded.
      'char_grapheme_break_property': (cp => {
        if (cp === 0x000D) return 1; // CR
        if (cp === 0x000A) return 2; // LF
        if ((cp >= 0x0000 && cp <= 0x001F && cp !== 0x000A && cp !== 0x000D) ||
            (cp >= 0x007F && cp <= 0x009F)) return 3; // Control
        if ((cp >= 0x0300 && cp <= 0x036F) ||
            (cp >= 0x1AB0 && cp <= 0x1AFF) ||
            (cp >= 0x1DC0 && cp <= 0x1DFF) ||
            (cp >= 0x20D0 && cp <= 0x20FF) ||
            (cp >= 0xFE20 && cp <= 0xFE2F) ||
            cp === 0x200C) return 4; // Extend
        if (cp === 0x200D) return 5; // ZWJ
        if (cp >= 0x1F1E6 && cp <= 0x1F1FF) return 6; // Regional Indicator
        if ((cp >= 0x0600 && cp <= 0x0605) || cp === 0x06DD || cp === 0x070F || cp === 0x08E2)
          return 7; // Prepend (subset)
        if (cp === 0x0903 || cp === 0x093B ||
            (cp >= 0x093E && cp <= 0x0940) ||
            (cp >= 0x0949 && cp <= 0x094C) ||
            (cp >= 0x094E && cp <= 0x094F) ||
            (cp >= 0x0982 && cp <= 0x0983))
          return 8; // SpacingMark (subset)
        if ((cp >= 0x1100 && cp <= 0x115F) || (cp >= 0xA960 && cp <= 0xA97C)) return 9; // L
        if ((cp >= 0x1160 && cp <= 0x11A7) || (cp >= 0xD7B0 && cp <= 0xD7C6)) return 10; // V
        if ((cp >= 0x11A8 && cp <= 0x11FF) || (cp >= 0xD7CB && cp <= 0xD7FB)) return 11; // T
        if (cp >= 0xAC00 && cp <= 0xD7A3) {
          const sIndex = cp - 0xAC00;
          return (sIndex % 28 === 0) ? 12 : 13; // LV or LVT
        }
        return 0; // Other
      }),
      'char_general_category': ((cp) => {
        const s = String.fromCodePoint(cp);
        if (/\p{Lu}/u.test(s)) return 0;
        if (/\p{Ll}/u.test(s)) return 1;
        if (/\p{Lt}/u.test(s)) return 2;
        if (/\p{Lm}/u.test(s)) return 3;
        if (/\p{Lo}/u.test(s)) return 4;
        if (/\p{Mn}/u.test(s)) return 5;
        if (/\p{Mc}/u.test(s)) return 6;
        if (/\p{Me}/u.test(s)) return 7;
        if (/\p{Nd}/u.test(s)) return 8;
        if (/\p{Nl}/u.test(s)) return 9;
        if (/\p{No}/u.test(s)) return 10;
        if (/\p{Ps}/u.test(s)) return 11;
        if (/\p{Pe}/u.test(s)) return 12;
        if (/\p{Pi}/u.test(s)) return 13;
        if (/\p{Pf}/u.test(s)) return 14;
        if (/\p{Pd}/u.test(s)) return 15;
        if (/\p{Pc}/u.test(s)) return 16;
        if (/\p{Po}/u.test(s)) return 17;
        if (/\p{Sc}/u.test(s)) return 18;
        if (/\p{Sm}/u.test(s)) return 19;
        if (/\p{Sk}/u.test(s)) return 20;
        if (/\p{So}/u.test(s)) return 21;
        if (/\p{Zs}/u.test(s)) return 22;
        if (/\p{Zp}/u.test(s)) return 23;
        if (/\p{Zl}/u.test(s)) return 24;
        if (/\p{Cc}/u.test(s)) return 25;
        if (/\p{Cf}/u.test(s)) return 26;
        if (/\p{Cs}/u.test(s)) return 27;
        if (/\p{Co}/u.test(s)) return 28;
        return 29; // Cn
      }),
      'char_alphabetic': ((cp) =>
        Number(/\p{Alphabetic}/u.test(String.fromCodePoint(cp)))),
      'char_lower_case': ((cp) =>
        Number(/\p{Lowercase}/u.test(String.fromCodePoint(cp)))),
      'char_upper_case': ((cp) =>
        Number(/\p{Uppercase}/u.test(String.fromCodePoint(cp)))),
      'char_title_case': ((cp) =>
        Number(/\p{gc=Lt}/u.test(String.fromCodePoint(cp)))),
      'char_numeric': ((cp) =>
        Number(/\p{Number}/u.test(String.fromCodePoint(cp)))),
      'char_symbolic': ((cp) =>
        Number(/\p{gc=Sm}|\p{gc=Sc}|\p{gc=Sk}|\p{gc=So}/u.test(String.fromCodePoint(cp)))),
      'char_punctuation': ((cp) =>
        Number(/\p{gc=Pc}|\p{gc=Pd}|\p{gc=Ps}|\p{gc=Pe}|\p{gc=Pi}|\p{gc=Pf}|\p{gc=Po}/u.test(String.fromCodePoint(cp)))),
      'char_graphic': ((cp) =>
        Number(/\p{gc=Ll}|\p{gc=Lm}|\p{gc=Lo}|\p{gc=Lt}|\p{gc=Lu}|\p{gc=Nd}|\p{gc=Nl}|\p{gc=No}|\p{gc=Mn}|\p{gc=Mc}|\p{gc=Me}|\p{Alphabetic}|\p{Number}|\p{gc=Sm}|\p{gc=Sc}|\p{gc=Sk}|\p{gc=So}|\p{gc=Pc}|\p{gc=Pd}|\p{gc=Ps}|\p{gc=Pe}|\p{gc=Pi}|\p{gc=Pf}|\p{gc=Po}/u.test(String.fromCodePoint(cp)))),
      'char_extended_pictographic': ((cp) =>
        Number(/\p{Extended_Pictographic}/u.test(String.fromCodePoint(cp))))
    },

    // General JavaScript FFI.
    'standard': {
      'global-this':               (() => globalThis),
      'infinity':                  (() => Infinity),
      'nan':                       (() => NaN),
      'undefined':                 (() => undefined),
      'nullish?':                  ((v) => ((v === null) || (v === undefined)) ? 1 : 0),
      'null?':                     ((v) => (v === null) ? 1 : 0),
      'undefined?':                ((v) => (v === undefined) ? 1 : 0),
      'truthy?':                   ((v) => v ? 1 : 0),
      'eval':                      ((code) => eval(from_fasl(code))),
      'is-finite':                 ((x) => isFinite(x) ? 1 : 0),
      'finite?':                   ((x) => isFinite(x) ? 1 : 0),
      'is-nan':                    ((x) => isNaN(x) ? 1 : 0),
      'nan?':                      ((x) => isNaN(x) ? 1 : 0),
      'parse-float':               ((s) => parseFloat(from_fasl(s))),
      'parse-int':                 ((s) => parseInt(from_fasl(s))),
      'decode-uri':                ((s) => decodeURI(from_fasl(s))),
      'decode-uri-component':      ((s) => decodeURIComponent(from_fasl(s))),
      'encode-uri':                ((s) => encodeURI(from_fasl(s))),
      'encode-uri-component':      ((s) => encodeURIComponent(from_fasl(s))),
      'var':                       ((name) => globalThis[from_fasl(name)]),
      'ref/value':                 ((obj, key) => to_fasl(require_js_target(obj, 'js-ref')[from_fasl(key)])),
      'ref/extern':                ((obj, key) => require_js_target(obj, 'js-ref/extern')[from_fasl(key)]),
      'set!':                      ((obj, key, val) => ( require_js_target(obj, 'js-set!')[from_fasl(key)] = from_fasl(val) )),
      'index':                     ((obj, prop) => to_fasl( require_js_target(obj, 'js-index')[ from_fasl(prop) ] ) ),
      'assign':                    ((name, val) => (globalThis[from_fasl(name)] = from_fasl(val))),
      'new':                       ((ctor, args) => construct_js_value(ctor, args)),
      // Send variants:
      // - send/extern  => raw JS result
      // - send/value   => JS result converted via FASL
      // - send/boolean => strict boolean result; throws on non-boolean
      // - send/truthy  => JS truthiness to 0/1
      // Default `send` mirrors `send/value`.
      'send':                      ((obj, name, args) => {
                                    const x = call_js_method(obj, name, args, 'js-send');
                                    return to_fasl(x);
                                   }),
      'send/extern':               ((obj, name, args) => call_js_method(obj, name, args, 'js-send/extern') ),
      'send/value':                ((obj, name, args) => {
                                    const x = call_js_method(obj, name, args, 'js-send/value');
                                    return to_fasl(x);
                                   }),
      'send/boolean':              ((obj, name, args) => {
                                    const x = call_js_method(obj, name, args, 'js-send/boolean');
                                    if (typeof x === 'boolean') {
                                      return x ? 1 : 0;
                                    }
                                    if ((typeof x === 'object') && (x instanceof Boolean)) {
                                      return x.valueOf() ? 1 : 0;
                                    }
                                    throw new TypeError(`js-send/boolean: expected boolean result, got ${typeof x}`);
                                   }),
      'send/truthy':               ((obj, name, args) => {
                                    const x = call_js_method(obj, name, args, 'js-send/truthy');
                                    return x ? 1 : 0;
                                   }),
      'send/flonum':               ((obj, name, args) => {
                                    const x = call_js_method(obj, name, args, 'js-send/flonum')
                                    return (( (typeof x === "object") && (x instanceof Number) ) ? x.valueOf() : x)
                                    }),
      'throw':                     (exn => { throw from_fasl(exn); }),
      'null':                      (() => null),
      'this':                      (function () { return this; }),
      'object':                    (fields => {
                                     const decoded = from_fasl(fields);
                                     const entries = is_alist(decoded)
                                       ? alist_to_vector_pairs(decoded)
                                       : (decoded || []);
                                     const o = {};
                                     for (const [k, v] of entries) {
                                       o[k] = v;
                                     }
                                     return o;
                                   }),
      'array':                     (args => { const as = from_fasl(args);
                                              return to_fasl( [...( as ? as : [])])
                                    }),
      'array/extern':               (args => { const as = from_fasl(args);
                                              return [...( as ? as : [])]
                                    }),
      'typeof':                    ((obj) => typeof obj),
      'value->string':             ((obj) => String(obj)),
      'instanceof':                ((obj, type) => (obj instanceof type) ? 1 : 0),
      'operator':                  ((op, operands) => {
                                     const o = from_fasl(op);
                                     const args = from_fasl(operands) || [];
                                     if (args.length === 1) {
                                       return Function('a', `return ${o} a;`)(args[0]);
                                     } else if (args.length === 2) {
                                       return Function('a','b', `return a ${o} b;`)(args[0], args[1]);
                                     } else {
                                       return Function('args', `return args.reduce((a,b)=>a ${o} b);`)(args);
                                     }
                                       }),
      // The following returns the prototype object
      // Some are guarded by a test. These might not be available everywhere.
      'Object':                    (() => Object),
      'Function':                  (() => Function),
      'Boolean':                   (() => Boolean),
      'Symbol':                    (() => Symbol),
      'Error':                     (() => Error),
      'AggregateError':            (() => (typeof AggregateError === 'undefined' ? undefined : AggregateError)),
      'EvalError':                 (() => EvalError),
      'RangeError':                (() => RangeError),
      'ReferenceError':            (() => ReferenceError),
      'SuppressedError':           (() => (typeof SuppressedError === 'undefined' ? undefined : SuppressedError)),
      'SyntaxError':               (() => SyntaxError),
      'TypeError':                 (() => TypeError),
      'URIError':                  (() => URIError),
      'InternalError':             (() => (typeof InternalError === 'undefined' ? undefined : InternalError)),
      'Number':                    (() => Number),
      'BigInt':                    (() => BigInt),
      'Math':                      (() => Math),
      'Date':                      (() => Date),
      'Temporal':                  (() => (typeof Temporal === 'undefined' ? undefined : Temporal)),
      'String':                    (() => String),
      'RegExp':                    (() => RegExp),
      'Array':                     (() => Array),
      'TypedArray':                (() => (typeof TypedArray === 'undefined' ? undefined : TypedArray)),
      'Int8Array':                 (() => Int8Array),
      'Uint8Array':                (() => Uint8Array),
      'Uint8ClampedArray':         (() => Uint8ClampedArray),
      'Int16Array':                (() => Int16Array),
      'Uint16Array':               (() => Uint16Array),
      'Int32Array':                (() => Int32Array),
      'Uint32Array':               (() => Uint32Array),
      'BigInt64Array':             (() => (typeof BigInt64Array  === 'undefined' ? undefined : BigInt64Array)),
      'BigUint64Array':            (() => (typeof BigUint64Array === 'undefined' ? undefined : BigUint64Array)),
      'Float16Array':              (() => (typeof Float16Array   === 'undefined' ? undefined : Float16Array)),  // Baseline 2025
      'Float32Array':              (() => Float32Array),
      'Float64Array':              (() => Float64Array),
      'Map':                       (() => Map),
      'Set':                       (() => Set),
      'WeakMap':                   (() => WeakMap),
      'WeakSet':                   (() => WeakSet),
      'ArrayBuffer':               (() => ArrayBuffer),
      'SharedArrayBuffer':        (() => (typeof SharedArrayBuffer === 'undefined' ? undefined : SharedArrayBuffer)),
      'DataView':                  (() => DataView),
      'Atomics':                   (() => (typeof Atomics === 'undefined' ? undefined : Atomics)),
      'JSON':                      (() => JSON),
      'WeakRef':                   (() => (typeof WeakRef === 'undefined' ? undefined : WeakRef)),
      'FinalizationRegistry':      (() => (typeof FinalizationRegistry === 'undefined' ? undefined : FinalizationRegistry)),
      'Iterator':                  (() => (typeof Iterator === 'undefined' ? undefined : Iterator)),
      'AsyncIterator':             (() => (typeof AsyncIterator === 'undefined' ? undefined : AsyncIterator)),
      'Promise':                   (() => Promise),
      'GeneratorFunction':         (() => (function*(){}).constructor),
      'AsyncGeneratorFunction':    (() => (async function*(){}).constructor),
      'Generator':                 (() => Object.getPrototypeOf(function*(){}())),
      'AsyncGenerator':            (() => Object.getPrototypeOf(async function*(){}())),
      'AsyncFunction':             (() => (async function(){}).constructor),
      'DisposableStack':           (() => (typeof DisposableStack === 'undefined' ? undefined : DisposableStack)),
      'AsyncDisposableStack':     (() => (typeof AsyncDisposableStack === 'undefined' ? undefined : AsyncDisposableStack)),
      'Reflect':                   (() => Reflect),
      'Proxy':                     (() => Proxy),
      'Intl':                      (() => Intl),
      'Intl.Collator':             (() => ('Collator' in Intl ? Intl.Collator : undefined)),
      'Intl.DateTimeFormat':       (() => ('DateTimeFormat' in Intl ? Intl.DateTimeFormat : undefined)),
      'Intl.DisplayNames':         (() => ('DisplayNames' in Intl ? Intl.DisplayNames : undefined)),
      'Intl.DurationFormat':       (() => ('DurationFormat' in Intl ? Intl.DurationFormat : undefined)),
      'Intl.ListFormat':           (() => ('ListFormat' in Intl ? Intl.ListFormat : undefined)),
      'Intl.Locale':               (() => ('Locale' in Intl ? Intl.Locale : undefined)),
      'Intl.NumberFormat':         (() => ('NumberFormat' in Intl ? Intl.NumberFormat : undefined)),
      'Intl.PluralRules':          (() => ('PluralRules' in Intl ? Intl.PluralRules : undefined)),
      'Intl.RelativeTimeFormat':   (() => ('RelativeTimeFormat' in Intl ? Intl.RelativeTimeFormat : undefined)),
      'Intl.Segmenter':            (() => ('Segmenter' in Intl ? Intl.Segmenter : undefined))
    },

    // Console FFI.
    'console': {
      'log':                       (args => call_console_fallback('log', null, from_fasl(args) || [])),
      'info':                      (args => call_console_fallback('info', 'log', from_fasl(args) || [])),
      'warn':                      (args => call_console_fallback('warn', 'log', from_fasl(args) || [])),
      'error':                     (args => call_console_fallback('error', 'log', from_fasl(args) || [])),
      'debug':                     (args => call_console_fallback('debug', 'log', from_fasl(args) || [])),
      'assert':                    (args => {
                                     const as = from_fasl(args) || [];
                                     call_console_fallback('assert', 'error', as);
                                   }),
      'clear':                     (() => call_console_fallback('clear', null, [])),
      'dir':                       (args => call_console_fallback('dir', 'log', from_fasl(args) || [])),
      'dirxml':                    (args => {
                                     const as = from_fasl(args) || [];
                                     call_console_fallback('dirxml', 'log', as);
                                   }),
      'table':                     (args => {
                                     const as = from_fasl(args) || [];
                                     call_console_fallback('table', 'log', as);
                                   }),
      'group':                     (args => call_console_fallback('group', 'log', from_fasl(args) || [])),
      'group-collapsed':           (args => call_console_fallback('groupCollapsed', 'log', from_fasl(args) || [])),
      'group-end':                 (() => call_console_fallback('groupEnd', null, [])),
      'count':                     (args => call_console_fallback('count', 'log', from_fasl(args) || [])),
      'count-reset':               (args => {
                                     const as = from_fasl(args) || [];
                                     call_console_fallback('countReset', 'count', as);
                                   }),
      'time':                      (args => call_console_fallback('time', null, from_fasl(args) || [])),
      'time-end':                  (args => call_console_fallback('timeEnd', null, from_fasl(args) || [])),
      'time-log':                  (args => call_console_fallback('timeLog', null, from_fasl(args) || [])),
      'time-stamp':                (args => call_console_fallback('timeStamp', null, from_fasl(args) || [])),
      'trace':                     (args => call_console_fallback('trace', 'log', from_fasl(args) || [])),
      'profile':                   (args => call_console_fallback('profile', null, from_fasl(args) || [])),
      'profile-end':               (args => call_console_fallback('profileEnd', null, from_fasl(args) || [])),
      'exception':                 (args => call_console_fallback('exception', 'error', from_fasl(args) || [])),
    },

    // Temporary/prototype FFI.
    'temp': {
      'x':                         ((o) => to_fasl(get_required_host_property(o, 'x', 'temp.x'))),
      'set-x!':                    ((o, v) => { set_required_host_property(o, 'x', from_fasl(v), 'temp.x'); }),
    },

    // JavaScript Math FFI.
    'math': {
        'abs':    ((x)       => Math.abs(x)),
        'acos':   ((x)       => Math.acos(x)),
        'acosh':  ((x)       => Math.acosh(x)),
        'asin':   ((x)       => Math.asin(x)),
        'asinh':  ((x)       => Math.asinh(x)),
        'atan':   ((x)       => Math.atan(x)),
        'atan2':  ((y, x)    => Math.atan2(y, x)),
        'atanh':  ((x)       => Math.atanh(x)),
        'cbrt':   ((x)       => Math.cbrt(x)),
        'ceil':   ((x)       => Math.ceil(x)),
        'clz32':  ((x)       => Math.clz32(x)),
        'cos':    ((x)       => Math.cos(x)),
        'cosh':   ((x)       => Math.cosh(x)),
        'exp':    ((x)       => Math.exp(x)),
        'expm1':  ((x)       => Math.expm1(x)),
        'floor':  ((x)       => Math.floor(x)),
        'fround': ((x)       => Math.fround(x)),
        'hypot':  ((x, y)    => Math.hypot(x, y)),
        'imul':   ((a, b)    => Math.imul(a, b)),
        'log':    ((x)       => Math.log(x)),
        'log10':  ((x)       => Math.log10(x)),
        'log1p':  ((x)       => Math.log1p(x)),
        'log2':   ((x)       => Math.log2(x)),
        'max':    ((x, y)    => Math.max(x, y)),
        'min':    ((x, y)    => Math.min(x, y)),
        'pow':    ((x, y)    => Math.pow(x, y)),
        'random': (()        => Math.random()),
        'round':  ((x)       => Math.round(x)),
        'sign':   ((x)       => Math.sign(x)),
        'sin':    ((x)       => Math.sin(x)),
        'sinh':   ((x)       => Math.sinh(x)),
        'sqrt':   ((x)       => Math.sqrt(x)),
        'tan':    ((x)       => Math.tan(x)),
        'tanh':   ((x)       => Math.tanh(x)),
        'trunc':  ((x)       => Math.trunc(x))
    },

    // JavaScript Number FFI.
    'number': {
        // Machine epsilon constant.
        'epsilon':           (() => Number.EPSILON),
        // Largest safe integer.
        'max-safe-integer':  (() => Number.MAX_SAFE_INTEGER),
        // Greatest finite number.
        'max-value':         (() => Number.MAX_VALUE),
        // Smallest safe integer.
        'min-safe-integer':  (() => Number.MIN_SAFE_INTEGER),
        // Smallest positive non-zero number.
        'min-value':         (() => Number.MIN_VALUE),
        // IEEE NaN value.
        'nan':               (() => Number.NaN),
        // Negative infinity constant.
        'negative-infinity': (() => Number.NEGATIVE_INFINITY),
        // Positive infinity constant.
        'positive-infinity': (() => Number.POSITIVE_INFINITY),
        // Test whether a value is finite.
        'is-finite':         (x => boolean_to_i32(Number.isFinite(x))),
        // Test whether a value is an integer.
        'is-integer':        (x => boolean_to_i32(Number.isInteger(x))),
        // Test whether a value is NaN.
        'is-nan':            (x => boolean_to_i32(Number.isNaN(x))),
        // Test whether a value is a safe integer.
        'is-safe-integer':   (x => boolean_to_i32(Number.isSafeInteger(x))),
        // Parse string into floating-point number.
        'parse-float':       (s => Number.parseFloat(from_fasl(s))),
        // Parse string into integer.
        'parse-int':         (s => Number.parseInt(from_fasl(s))),
        // Convert number to exponential notation.
        'to-exponential':    ((x, fd) => {
                                 const d = from_fasl(fd);
                                 return d === undefined
                                   ? call_number_method(x, 'toExponential')
                                   : call_number_method(x, 'toExponential', [d]);
                               }),
        // Format number with fixed-point notation.
        'to-fixed':          ((x, digits) => {
                                 const d = from_fasl(digits);
                                 return d === undefined
                                   ? call_number_method(x, 'toFixed')
                                   : call_number_method(x, 'toFixed', [d]);
                               }),
        // Format number using locale-specific rules.
        'to-locale-string':  ((x, locales, options) => call_number_method(x,
                                                                          'toLocaleString',
                                                                          [from_fasl(locales),
                                                                           from_fasl(options)])),
        // Format number with specified precision.
        'to-precision':      ((x, precision) => {
                                 const p = from_fasl(precision);
                                 return p === undefined
                                   ? call_number_method(x, 'toPrecision')
                                   : call_number_method(x, 'toPrecision', [p]);
                               }),
        // Convert number to string with optional radix.
        'to-string':         ((x, radix) => {
                                 const r = from_fasl(radix);
                                 return r === undefined
                                   ? call_number_method(x, 'toString')
                                   : call_number_method(x, 'toString', [r]);
                               }),
        // Extract primitive numeric value.
        'value-of':          (x => call_number_method(x, 'valueOf'))
    },

    // JavaScript Array FFI.
    'array': {
        'length':            (arr => get_required_host_property(arr, 'length', 'Array.length')),
        'set-length!':       ((arr, len) => { set_required_host_property(arr, 'length', len, 'Array.length'); }),
        'from':              ((arrLike, mapFn, thisArg) => {
                const a = from_fasl(arrLike);
                const m = mapFn;
                const t = from_fasl(thisArg);
                if (m === undefined) {
                    return call_array_static_method('from', [a]);
                } else if (t === undefined) {
                    return call_array_static_method('from', [a, m]);
                } else {
                    return call_array_static_method('from', [a, m, t]);
                }
        }),
        'from-async':        ((arrLike, mapFn, thisArg) => {
                const a = from_fasl(arrLike);
                const m = mapFn;
                const t = from_fasl(thisArg);
                if (m === undefined) {
                    return call_array_static_method('fromAsync', [a]);
                } else if (t === undefined) {
                    return call_array_static_method('fromAsync', [a, m]);
                } else {
                    return call_array_static_method('fromAsync', [a, m, t]);
                }
        }),
        'is-array':          (v => call_array_static_method('isArray', [from_fasl(v)]) ? 1 : 0),
        'to-vector':         (arr => to_fasl(call_array_static_method('from', [arr]))),
        'to-bytes':          (arr => to_fasl(Uint8Array.from(arr))),
        'of':                (items => call_array_static_method('of', from_fasl(items) || [])),
        'at':                ((arr, index) => call_array_method(arr, 'at', [index])),
        'concat':            ((arr, items) => call_array_method(arr, 'concat', from_fasl(items) || [])),
        'copy-within':       ((arr, target, start, end) => {
                const e = from_fasl(end);
                return e === undefined
                  ? call_array_method(arr, 'copyWithin', [target, start])
                  : call_array_method(arr, 'copyWithin', [target, start, e]);
        }),
        'entries':           (arr => call_array_method(arr, 'entries')),
        'every':             ((arr, fn, thisArg) => call_array_method(arr, 'every', [fn, from_fasl(thisArg)]) ? 1 : 0),
        'fill':              ((arr, value, start, end) => call_array_method(arr, 'fill', [from_fasl(value), from_fasl(start), from_fasl(end)])),
        'filter':            ((arr, fn, thisArg) => call_array_method(arr, 'filter', [fn, from_fasl(thisArg)])),
        'find':              ((arr, fn, thisArg) => call_array_method(arr, 'find', [fn, from_fasl(thisArg)])),
        'find-index':        ((arr, fn, thisArg) => call_array_method(arr, 'findIndex', [fn, from_fasl(thisArg)])),
        'find-last':         ((arr, fn, thisArg) => call_array_method(arr, 'findLast', [fn, from_fasl(thisArg)])),
        'find-last-index':   ((arr, fn, thisArg) => call_array_method(arr, 'findLastIndex', [fn, from_fasl(thisArg)])),
        'flat':              ((arr, depth) => call_array_method(arr, 'flat', [from_fasl(depth)])),
        'flat-map':          ((arr, fn, thisArg) => call_array_method(arr, 'flatMap', [fn, from_fasl(thisArg)])),
        'for-each':          ((arr, fn, thisArg) => { call_array_method(arr, 'forEach', [fn, from_fasl(thisArg)]); }),
        'includes':          ((arr, value, fromIndex) => call_array_method(arr, 'includes', [from_fasl(value), from_fasl(fromIndex)]) ? 1 : 0),
        'index-of':          ((arr, value, fromIndex) => call_array_method(arr, 'indexOf', [from_fasl(value), from_fasl(fromIndex)])),
        'join':              ((arr, sep) => call_array_method(arr, 'join', [from_fasl(sep)])),
        'keys':              (arr => call_array_method(arr, 'keys')),
        'last-index-of':     ((arr, value, fromIndex) => call_array_method(arr, 'lastIndexOf', [from_fasl(value), from_fasl(fromIndex)])),
        'map':               ((arr, fn, thisArg) => call_array_method(arr, 'map', [fn, from_fasl(thisArg)])),
        'pop':               (arr => call_array_method(arr, 'pop')),
        'push':              ((arr, items) => call_array_method(arr, 'push', from_fasl(items) || [])),
        'reduce':            ((arr, fn, init) => {
                const i = from_fasl(init);
                return i === undefined
                  ? call_array_method(arr, 'reduce', [fn])
                  : call_array_method(arr, 'reduce', [fn, i]);
        }),
        'reduce-right':      ((arr, fn, init) => {
                const i = from_fasl(init);
                return i === undefined
                  ? call_array_method(arr, 'reduceRight', [fn])
                  : call_array_method(arr, 'reduceRight', [fn, i]);
        }),
        'reverse':           (arr => call_array_method(arr, 'reverse')),
        'shift':             (arr => call_array_method(arr, 'shift')),
        'slice':             ((arr, start, end) => call_array_method(arr, 'slice', [from_fasl(start), from_fasl(end)])),
        'some':              ((arr, fn, thisArg) => call_array_method(arr, 'some', [fn, from_fasl(thisArg)]) ? 1 : 0),
        'sort':              ((arr, fn) => call_array_method(arr, 'sort', [fn])),
        'splice':            ((arr, items) => call_array_method(arr, 'splice', from_fasl(items) || [])),
        'to-locale-string':  ((arr, args) => call_array_method(arr, 'toLocaleString', from_fasl(args) || [])),
        'to-string':         (arr => call_array_method(arr, 'toString')),
        'unshift':           ((arr, items) => call_array_method(arr, 'unshift', from_fasl(items) || [])),
        'values':            (arr => call_array_method(arr, 'values')),
        'to-reversed':       (arr => (typeof arr.toReversed === 'function' ? arr.toReversed() : [...arr].reverse())),
        'to-sorted':         ((arr, fn) => (typeof arr.toSorted === 'function' ? arr.toSorted(fn) : [...arr].sort(fn))),
        'to-spliced':        ((arr, items) => (typeof arr.toSpliced === 'function' ? arr.toSpliced(...(from_fasl(items) || [])) : (() => { const b = call_array_method(arr, 'slice'); call_array_method(b, 'splice', from_fasl(items) || []); return b; })())),
        'with':              ((arr, index, value) => (typeof arr.with === 'function' ? arr.with(index, from_fasl(value)) : (() => { const b = call_array_method(arr, 'slice'); b[index] = from_fasl(value); return b; })())),
    },
    // Canvas
    'canvas': hasDOM ? {
        'capture-stream':                ((canvas, rate)                 => require_host_function(canvas,
                                                                                                    'captureStream',
                                                                                                    'canvas.captureStream')(rate)),
        'get-context':                   ((canvas, type, opts)           => require_host_function(canvas,
                                                                                                    'getContext',
                                                                                                    'canvas.getContext')(from_fasl(type), opts)),
        'height':                        ((canvas)                       => get_canvas_element_property(canvas, 'height')),
        'set-height!':                   ((canvas, h)                    => { set_canvas_element_property(canvas, 'height', h); }),
        'to-blob':                       ((canvas, cb, type, quality)    => require_host_function(canvas,
                                                                                                    'toBlob',
                                                                                                    'canvas.toBlob')(cb, from_fasl(type), quality)),
        'to-data-url':                   ((canvas, type, quality)        => require_host_function(canvas,
                                                                                                    'toDataURL',
                                                                                                    'canvas.toDataURL')(from_fasl(type), quality)),
        'transfer-control-to-offscreen': ((canvas)                       => require_host_function(canvas,
                                                                                                    'transferControlToOffscreen',
                                                                                                    'canvas.transferControlToOffscreen')()),
        'width':                         ((canvas)                       => get_canvas_element_property(canvas, 'width')),
        'set-width!':                    ((canvas, w)                    => { set_canvas_element_property(canvas, 'width', w); })
    } : {
        'capture-stream'()                { throw new Error('DOM not available in this environment'); },
        'get-context'()                   { throw new Error('DOM not available in this environment'); },
        'height'()                        { throw new Error('DOM not available in this environment'); },
        'set-height!'()                   { throw new Error('DOM not available in this environment'); },
        'to-blob'()                       { throw new Error('DOM not available in this environment'); },
        'to-data-url'()                   { throw new Error('DOM not available in this environment'); },
        'transfer-control-to-offscreen'() { throw new Error('DOM not available in this environment'); },
        'width'()                         { throw new Error('DOM not available in this environment'); },
        'set-width!'()                    { throw new Error('DOM not available in this environment'); }
    },
    // CanvasRenderingContext2D
    'canvas-rendering-context-2d': hasDOM ? {
        'canvas':                 (ctx => get_canvas_2d_property(ctx, 'canvas')),
        'direction':              (ctx => get_canvas_2d_property(ctx, 'direction')),
        'set-direction!':         ((ctx, dir) => { set_canvas_2d_property(ctx, 'direction', from_fasl(dir)); }),
        'fill-style':             (ctx => get_canvas_2d_property(ctx, 'fillStyle')),
        'set-fill-style!':        ((ctx, style) => { set_canvas_2d_property(ctx, 'fillStyle', from_fasl(style)); }),
        'filter':                 (ctx => get_canvas_2d_property(ctx, 'filter')),
        'set-filter!':            ((ctx, filter) => { set_canvas_2d_property(ctx, 'filter', from_fasl(filter)); }),
        'font':                   (ctx => get_canvas_2d_property(ctx, 'font')),
        'set-font!':              ((ctx, font) => { set_canvas_2d_property(ctx, 'font', from_fasl(font)); }),
        'global-alpha':           (ctx => get_canvas_2d_property(ctx, 'globalAlpha')),
        'set-global-alpha!':      ((ctx, a) => { set_canvas_2d_property(ctx, 'globalAlpha', a); }),
        'global-composite-operation': (ctx => get_canvas_2d_property(ctx, 'globalCompositeOperation')),
        'set-global-composite-operation!': ((ctx, op) => { set_canvas_2d_property(ctx, 'globalCompositeOperation', from_fasl(op)); }),
        'image-smoothing-enabled': (ctx => get_canvas_2d_property(ctx, 'imageSmoothingEnabled') ? 1 : 0),
        'set-image-smoothing-enabled!': ((ctx, flag) => { set_canvas_2d_property(ctx, 'imageSmoothingEnabled', !!flag); }),
        'image-smoothing-quality': (ctx => get_canvas_2d_property(ctx, 'imageSmoothingQuality')),
        'set-image-smoothing-quality!': ((ctx, q) => { set_canvas_2d_property(ctx, 'imageSmoothingQuality', from_fasl(q)); }),
        'line-cap':               (ctx => get_canvas_2d_property(ctx, 'lineCap')),
        'set-line-cap!':          ((ctx, cap) => { set_canvas_2d_property(ctx, 'lineCap', from_fasl(cap)); }),
        'line-dash-offset':       (ctx => get_canvas_2d_property(ctx, 'lineDashOffset')),
        'set-line-dash-offset!':  ((ctx, off) => { set_canvas_2d_property(ctx, 'lineDashOffset', off); }),
        'line-join':              (ctx => get_canvas_2d_property(ctx, 'lineJoin')),
        'set-line-join!':         ((ctx, join) => { set_canvas_2d_property(ctx, 'lineJoin', from_fasl(join)); }),
        'line-width':             (ctx => get_canvas_2d_property(ctx, 'lineWidth')),
        'set-line-width!':        ((ctx, w) => { set_canvas_2d_property(ctx, 'lineWidth', w); }),
        'miter-limit':            (ctx => get_canvas_2d_property(ctx, 'miterLimit')),
        'set-miter-limit!':       ((ctx, m) => { set_canvas_2d_property(ctx, 'miterLimit', m); }),
        'shadow-blur':            (ctx => get_canvas_2d_property(ctx, 'shadowBlur')),
        'set-shadow-blur!':       ((ctx, b) => { set_canvas_2d_property(ctx, 'shadowBlur', b); }),
        'shadow-color':           (ctx => get_canvas_2d_property(ctx, 'shadowColor')),
        'set-shadow-color!':      ((ctx, c) => { set_canvas_2d_property(ctx, 'shadowColor', from_fasl(c)); }),
        'shadow-offset-x':        (ctx => get_canvas_2d_property(ctx, 'shadowOffsetX')),
        'set-shadow-offset-x!':   ((ctx, x) => { set_canvas_2d_property(ctx, 'shadowOffsetX', x); }),
        'shadow-offset-y':        (ctx => get_canvas_2d_property(ctx, 'shadowOffsetY')),
        'set-shadow-offset-y!':   ((ctx, y) => { set_canvas_2d_property(ctx, 'shadowOffsetY', y); }),
        'stroke-style':           (ctx => get_canvas_2d_property(ctx, 'strokeStyle')),
        'set-stroke-style!':      ((ctx, style) => { set_canvas_2d_property(ctx, 'strokeStyle', from_fasl(style)); }),
        'text-align':             (ctx => get_canvas_2d_property(ctx, 'textAlign')),
        'set-text-align!':        ((ctx, a) => { set_canvas_2d_property(ctx, 'textAlign', from_fasl(a)); }),
        'text-baseline':          (ctx => get_canvas_2d_property(ctx, 'textBaseline')),
        'set-text-baseline!':     ((ctx, b) => { set_canvas_2d_property(ctx, 'textBaseline', from_fasl(b)); }),
        'text-rendering':         (ctx => get_canvas_2d_property(ctx, 'textRendering')),
        'set-text-rendering!':    ((ctx, r) => { set_canvas_2d_property(ctx, 'textRendering', from_fasl(r)); }),
        'font-kerning':           (ctx => get_canvas_2d_property(ctx, 'fontKerning')),
        'set-font-kerning!':      ((ctx, k) => { set_canvas_2d_property(ctx, 'fontKerning', from_fasl(k)); }),
        'font-stretch':           (ctx => get_canvas_2d_property(ctx, 'fontStretch')),
        'set-font-stretch!':      ((ctx, s) => { set_canvas_2d_property(ctx, 'fontStretch', from_fasl(s)); }),
        'font-variant-caps':      (ctx => get_canvas_2d_property(ctx, 'fontVariantCaps')),
        'set-font-variant-caps!': ((ctx, v) => { set_canvas_2d_property(ctx, 'fontVariantCaps', from_fasl(v)); }),
        'font-variant-ligatures': (ctx => get_canvas_2d_property(ctx, 'fontVariantLigatures')),
        'set-font-variant-ligatures!': ((ctx, v) => { set_canvas_2d_property(ctx, 'fontVariantLigatures', from_fasl(v)); }),
        'font-variant-numeric':   (ctx => get_canvas_2d_property(ctx, 'fontVariantNumeric')),
        'set-font-variant-numeric!': ((ctx, v) => { set_canvas_2d_property(ctx, 'fontVariantNumeric', from_fasl(v)); }),
        'letter-spacing':         (ctx => get_canvas_2d_property(ctx, 'letterSpacing')),
        'set-letter-spacing!':    ((ctx, v) => { set_canvas_2d_property(ctx, 'letterSpacing', from_fasl(v)); }),
        'word-spacing':           (ctx => get_canvas_2d_property(ctx, 'wordSpacing')),
        'set-word-spacing!':      ((ctx, v) => { set_canvas_2d_property(ctx, 'wordSpacing', from_fasl(v)); }),
        'arc': ((ctx, x, y, r, sa, ea, ccw) => require_host_function(ctx,
                                                                      'arc',
                                                                      'CanvasRenderingContext2D.arc')(x, y, r, sa, ea, !!ccw)),
        'arc-to': ((ctx, x1, y1, x2, y2, r) => require_host_function(ctx,
                                                                     'arcTo',
                                                                     'CanvasRenderingContext2D.arcTo')(x1, y1, x2, y2, r)),
        'begin-path': (ctx => require_host_function(ctx,
                                                    'beginPath',
                                                    'CanvasRenderingContext2D.beginPath')()),
        'bezier-curve-to': ((ctx, cp1x, cp1y, cp2x, cp2y, x, y) => require_host_function(ctx,
                                                                                         'bezierCurveTo',
                                                                                         'CanvasRenderingContext2D.bezierCurveTo')(cp1x, cp1y, cp2x, cp2y, x, y)),
        'clear-rect': ((ctx, x, y, w, h) => require_host_function(ctx,
                                                                  'clearRect',
                                                                  'CanvasRenderingContext2D.clearRect')(x, y, w, h)),
        'clip': ((ctx, path, rule) => {
          const clip = require_host_function(ctx,
                                             'clip',
                                             'CanvasRenderingContext2D.clip');
          // `(void)` is decoded as `undefined`
          const p = from_fasl(path);
          const r = from_fasl(rule);
          if (p === undefined && r === undefined) {
            clip();
          } else if (p === undefined) {
            clip(r);
          } else if (r === undefined) {
            clip(p);
          } else {
            clip(p, r);
          }
        }),
        'close-path': (ctx => require_host_function(ctx,
                                                    'closePath',
                                                    'CanvasRenderingContext2D.closePath')()),
        'create-image-data': ((ctx, sw, sh) => require_host_function(ctx,
                                                                     'createImageData',
                                                                     'CanvasRenderingContext2D.createImageData')(sw, sh)),
        'create-image-data-from': ((ctx, data) => require_host_function(ctx,
                                                                        'createImageData',
                                                                        'CanvasRenderingContext2D.createImageData')(data)),
        'image-data-width': ((data) => get_image_data_property(data, 'width')),
        'image-data-height': ((data) => get_image_data_property(data, 'height')),
        'image-data-data': ((data) => get_image_data_property(data, 'data')),
        'text-metrics-width': ((metrics) => get_text_metrics_property(metrics, 'width')),
        'dom-matrix-a': ((matrix) => get_dom_matrix_property(matrix, 'a')),
        'dom-matrix-b': ((matrix) => get_dom_matrix_property(matrix, 'b')),
        'dom-matrix-c': ((matrix) => get_dom_matrix_property(matrix, 'c')),
        'dom-matrix-d': ((matrix) => get_dom_matrix_property(matrix, 'd')),
        'dom-matrix-e': ((matrix) => get_dom_matrix_property(matrix, 'e')),
        'dom-matrix-f': ((matrix) => get_dom_matrix_property(matrix, 'f')),
        'create-linear-gradient': ((ctx, x0, y0, x1, y1) => require_host_function(ctx,
                                                                                  'createLinearGradient',
                                                                                  'CanvasRenderingContext2D.createLinearGradient')(x0, y0, x1, y1)),
        'create-pattern': ((ctx, img, rep) => require_host_function(ctx,
                                                                    'createPattern',
                                                                    'CanvasRenderingContext2D.createPattern')(img, from_fasl(rep))),
        'create-radial-gradient': ((ctx, x0, y0, r0, x1, y1, r1) => require_host_function(ctx,
                                                                                         'createRadialGradient',
                                                                                         'CanvasRenderingContext2D.createRadialGradient')(x0, y0, r0, x1, y1, r1)),
        'create-conic-gradient': ((ctx, sa, x, y) => require_host_function(ctx,
                                                                            'createConicGradient',
                                                                            'CanvasRenderingContext2D.createConicGradient')(sa, x, y)),
        'draw-focus-if-needed!': ((ctx, elem) => require_host_function(ctx,
                                                                        'drawFocusIfNeeded',
                                                                        'CanvasRenderingContext2D.drawFocusIfNeeded')(elem)),
        'draw-focus-if-needed-path!': ((ctx, path, elem) => require_host_function(ctx,
                                                                                   'drawFocusIfNeeded',
                                                                                   'CanvasRenderingContext2D.drawFocusIfNeeded')(path, elem)),
        'draw-image': ((ctx, img, dx, dy) => require_host_function(ctx,
                                                                   'drawImage',
                                                                   'CanvasRenderingContext2D.drawImage')(img, dx, dy)),
        'draw-image-5': ((ctx, img, dx, dy, dw, dh) => require_host_function(ctx,
                                                                            'drawImage',
                                                                            'CanvasRenderingContext2D.drawImage')(img, dx, dy, dw, dh)),
        'draw-image-9': ((ctx, img, sx, sy, sw, sh, dx, dy, dw, dh) => require_host_function(ctx,
                                                                                            'drawImage',
                                                                                            'CanvasRenderingContext2D.drawImage')(img, sx, sy, sw, sh, dx, dy, dw, dh)),
        'ellipse': ((ctx, x, y, rx, ry, rot, sa, ea, ccw) => require_host_function(ctx,
                                                                                  'ellipse',
                                                                                  'CanvasRenderingContext2D.ellipse')(x, y, rx, ry, rot, sa, ea, !!ccw)),
        'fill': ((ctx, path, rule) => {
          const fill = require_host_function(ctx,
                                             'fill',
                                             'CanvasRenderingContext2D.fill');
          // `(void)` is decoded as `undefined`
          const p = from_fasl(path);
          const r = from_fasl(rule);
          if (p === undefined && r === undefined) {
            fill();
          } else if (p === undefined) {
            fill(r);
          } else if (r === undefined) {
            fill(p);
          } else {
            fill(p, r);
          }
        }),
        'fill-rect': ((ctx, x, y, w, h) => require_host_function(ctx,
                                                                 'fillRect',
                                                                 'CanvasRenderingContext2D.fillRect')(x, y, w, h)),
        'fill-text': ((ctx, text, x, y, mw) => {
          const fillText = require_host_function(ctx,
                                                 'fillText',
                                                 'CanvasRenderingContext2D.fillText');
          const m = from_fasl(mw);
          if (m === undefined) {
            fillText(from_fasl(text), x, y);
          } else {
            fillText(from_fasl(text), x, y, m);
          }
        }),
        'get-image-data': ((ctx, sx, sy, sw, sh, opts) => {
          const getImageData = require_host_function(ctx,
                                                     'getImageData',
                                                     'CanvasRenderingContext2D.getImageData');
          const o = from_fasl(opts);
          if (o === undefined) {
            return getImageData(sx, sy, sw, sh);
          } else {
            return getImageData(sx, sy, sw, sh, o);
          }
        }),
        'get-line-dash': (ctx => require_host_function(ctx,
                                                       'getLineDash',
                                                       'CanvasRenderingContext2D.getLineDash')()),
        'get-transform': (ctx => require_host_function(ctx,
                                                       'getTransform',
                                                       'CanvasRenderingContext2D.getTransform')()),
        'is-point-in-path': ((ctx, path, x, y, rule) => {
          const isPointInPath = require_host_function(ctx,
                                                      'isPointInPath',
                                                      'CanvasRenderingContext2D.isPointInPath');
          const p = from_fasl(path);
          const r = from_fasl(rule);
          if (p === undefined && r === undefined) {
            return isPointInPath(x, y) ? 1 : 0;
          } else if (p === undefined) {
            return isPointInPath(x, y, r) ? 1 : 0;
          } else if (r === undefined) {
            return isPointInPath(p, x, y) ? 1 : 0;
          } else {
            return isPointInPath(p, x, y, r) ? 1 : 0;
          }
        }),
        'is-point-in-stroke': ((ctx, path, x, y) => {
          const isPointInStroke = require_host_function(ctx,
                                                        'isPointInStroke',
                                                        'CanvasRenderingContext2D.isPointInStroke');
          const p = from_fasl(path);
          if (p === undefined) {
            return isPointInStroke(x, y) ? 1 : 0;
          } else {
            return isPointInStroke(p, x, y) ? 1 : 0;
          }
        }),
        'line-to': ((ctx, x, y) => require_host_function(ctx,
                                                         'lineTo',
                                                         'CanvasRenderingContext2D.lineTo')(x, y)),
        'measure-text': ((ctx, text) => require_host_function(ctx,
                                                              'measureText',
                                                              'CanvasRenderingContext2D.measureText')(from_fasl(text))),
        'move-to': ((ctx, x, y) => require_host_function(ctx,
                                                         'moveTo',
                                                         'CanvasRenderingContext2D.moveTo')(x, y)),
        'put-image-data': ((ctx, data, dx, dy, dirtyX, dirtyY, dirtyW, dirtyH) => {
          const putImageData = require_host_function(ctx,
                                                     'putImageData',
                                                     'CanvasRenderingContext2D.putImageData');
          const dX = from_fasl(dirtyX);
          const dY = from_fasl(dirtyY);
          const dW = from_fasl(dirtyW);
          const dH = from_fasl(dirtyH);
          if (dX === undefined && dY === undefined && dW === undefined && dH === undefined) {
            putImageData(data, dx, dy);
          } else {
            putImageData(data, dx, dy, dX, dY, dW, dH);
          }
        }),
        'quadratic-curve-to': ((ctx, cpx, cpy, x, y) => require_host_function(ctx,
                                                                              'quadraticCurveTo',
                                                                              'CanvasRenderingContext2D.quadraticCurveTo')(cpx, cpy, x, y)),
        'rect': ((ctx, x, y, w, h) => require_host_function(ctx,
                                                            'rect',
                                                            'CanvasRenderingContext2D.rect')(x, y, w, h)),
        'reset': (ctx => require_host_function(ctx,
                                                'reset',
                                                'CanvasRenderingContext2D.reset')()),
        'reset-transform': (ctx => require_host_function(ctx,
                                                          'resetTransform',
                                                          'CanvasRenderingContext2D.resetTransform')()),
        'restore': (ctx => require_host_function(ctx,
                                                 'restore',
                                                 'CanvasRenderingContext2D.restore')()),
        'rotate': ((ctx, angle) => require_host_function(ctx,
                                                         'rotate',
                                                         'CanvasRenderingContext2D.rotate')(angle)),
        'round-rect': ((ctx, x, y, w, h, r) => {
          const roundRect = require_host_function(ctx,
                                                  'roundRect',
                                                  'CanvasRenderingContext2D.roundRect');
          const rad = from_fasl(r);
          if (rad === undefined) {
            roundRect(x, y, w, h);
          } else {
            roundRect(x, y, w, h, rad);
          }
        }),
        'save': (ctx => require_host_function(ctx,
                                              'save',
                                              'CanvasRenderingContext2D.save')()),
        'scale': ((ctx, x, y) => require_host_function(ctx,
                                                       'scale',
                                                       'CanvasRenderingContext2D.scale')(x, y)),
        'set-line-dash': ((ctx, arr) => require_host_function(ctx,
                                                              'setLineDash',
                                                              'CanvasRenderingContext2D.setLineDash')(arr)),
        'set-transform!': ((ctx, a, b, c, d, e, f) => require_host_function(ctx,
                                                                            'setTransform',
                                                                            'CanvasRenderingContext2D.setTransform')(a, b, c, d, e, f)),
        'set-transform-matrix!': ((ctx, m) => require_host_function(ctx,
                                                                    'setTransform',
                                                                    'CanvasRenderingContext2D.setTransform')(m)),
        'stroke': ((ctx, path) => {
          const stroke = require_host_function(ctx,
                                               'stroke',
                                               'CanvasRenderingContext2D.stroke');
          const p = from_fasl(path);
          if (p === undefined) {
            stroke();
          } else {
            stroke(p);
          }
        }),
        'stroke-rect': ((ctx, x, y, w, h) => require_host_function(ctx,
                                                                   'strokeRect',
                                                                   'CanvasRenderingContext2D.strokeRect')(x, y, w, h)),
        'stroke-text': ((ctx, text, x, y, mw) => {
          const strokeText = require_host_function(ctx,
                                                   'strokeText',
                                                   'CanvasRenderingContext2D.strokeText');
          const m = from_fasl(mw);
          if (m === undefined) {
            strokeText(from_fasl(text), x, y);
          } else {
            strokeText(from_fasl(text), x, y, m);
          }
        }),
        'transform': ((ctx, a, b, c, d, e, f) => require_host_function(ctx,
                                                                       'transform',
                                                                       'CanvasRenderingContext2D.transform')(a, b, c, d, e, f)),
        'translate': ((ctx, x, y) => require_host_function(ctx,
                                                           'translate',
                                                           'CanvasRenderingContext2D.translate')(x, y)),
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    'image-data': hasDOM ? {
        'width':   (data => get_image_data_property(data, 'width')),
        'height':  (data => get_image_data_property(data, 'height')),
        'data':    (data => get_image_data_property(data, 'data'))
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    'text-metrics': hasDOM ? {
        'width':   (metrics => get_text_metrics_property(metrics, 'width'))
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    'dom-matrix': hasDOM ? {
        'a':       (matrix => get_dom_matrix_property(matrix, 'a')),
        'b':       (matrix => get_dom_matrix_property(matrix, 'b')),
        'c':       (matrix => get_dom_matrix_property(matrix, 'c')),
        'd':       (matrix => get_dom_matrix_property(matrix, 'd')),
        'e':       (matrix => get_dom_matrix_property(matrix, 'e')),
        'f':       (matrix => get_dom_matrix_property(matrix, 'f'))
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    // Window
    'window': hasDOM ? {
        'window':               (() => get_window_property('window')),
        'self':                 (() => get_window_property('self')),
        'document':             (() => require_window_value('document',
                                                            'window.document')),
        'name':                 (() => get_window_property('name')),
        'set-name!':            (n => { set_window_property('name', from_fasl(n)); }),
        'location':             (() => get_window_property('location')),
        'set-location!':        (loc => { set_window_property('location', from_fasl(loc)); }),
        'custom-elements':      (() => require_window_value('customElements',
                                                            'window.customElements')),
        'history':              (() => require_window_value('history',
                                                            'window.history')),
        'locationbar':          (() => get_window_property('locationbar')),
        'menubar':              (() => get_window_property('menubar')),
        'personalbar':          (() => get_window_property('personalbar')),
        'scrollbars':           (() => get_window_property('scrollbars')),
        'statusbar':            (() => get_window_property('statusbar')),
        'toolbar':              (() => get_window_property('toolbar')),
        'status':               (() => get_window_property('status')),
        'set-status!':          (s => { set_window_property('status', from_fasl(s)); }),
        'closed':               (() => get_window_property('closed') ? 1 : 0),
        'frames':               (() => get_window_property('frames')),
        'length':               (() => get_window_property('length')),
        'opener':               (() => get_window_property('opener')),
        'set-opener!':          (o => { set_window_property('opener', o); }),
        'parent':               (() => get_window_property('parent')),
        'top':                  (() => get_window_property('top')),
        'visual-viewport':      (() => require_window_value('visualViewport',
                                                            'window.visualViewport')),
        'navigator':            (() => require_window_value('navigator',
                                                            'window.navigator')),
        'origin':               (() => get_window_property('origin')),
        'crypto':               (() => require_window_value('crypto',
                                                            'window.crypto')),
        'device-pixel-ratio':   (() => get_window_property('devicePixelRatio')),
        'event':                (() => get_window_property('event')),
        'frame-element':        (() => get_window_property('frameElement')),
        'inner-height':         (() => get_window_property('innerHeight')),
        'inner-width':          (() => get_window_property('innerWidth')),
        'outer-height':         (() => get_window_property('outerHeight')),
        'outer-width':          (() => get_window_property('outerWidth')),
        'screen-x':             (() => get_window_property('screenX')),
        'screen-y':             (() => get_window_property('screenY')),
        'screen-left':          (() => get_window_property('screenLeft')),
        'screen-top':           (() => get_window_property('screenTop')),
        'page-x-offset':        (() => get_window_property('pageXOffset')),
        'page-y-offset':        (() => get_window_property('pageYOffset')),
        'scroll-x':             (() => get_window_property('scrollX')),
        'scroll-y':             (() => get_window_property('scrollY')),
        'screen':               (() => require_window_value('screen',
                                                            'window.screen')),
        'local-storage':        (() => require_window_value('localStorage',
                                                            'window.localStorage')),
        'session-storage':      (() => require_window_value('sessionStorage',
                                                            'window.sessionStorage')),
        'performance':          (() => require_window_value('performance',
                                                            'window.performance')),
        'indexed-db':           (() => require_window_value('indexedDB',
                                                            'window.indexedDB')),
        'is-secure-context':    (() => get_window_property('isSecureContext') ? 1 : 0),
        'cross-origin-isolated':(() => get_window_property('crossOriginIsolated') ? 1 : 0),
        'caches':               (() => require_window_value('caches',
                                                            'window.caches')),
        'speech-synthesis':     (() => require_window_value('speechSynthesis',
                                                            'window.speechSynthesis')),
        'style-media':          (() => require_window_value('styleMedia',
                                                            'window.styleMedia')),
        'alert':                (msg => require_window_function('alert',
                                                                'window.alert')(from_fasl(msg))),
        'atob':                 (s => require_window_function('atob',
                                                              'window.atob')(from_fasl(s))),
        'btoa':                 (s => require_window_function('btoa',
                                                              'window.btoa')(from_fasl(s))),
        'blur':                 (() => require_window_function('blur',
                                                              'window.blur')()),
        'cancel-animation-frame': (id => require_window_function('cancelAnimationFrame',
                                                                 'window.cancelAnimationFrame')(id)),
        'cancel-idle-callback': (id => require_window_function('cancelIdleCallback',
                                                              'window.cancelIdleCallback')(id)),
        'clear-interval':       (id => require_window_function('clearInterval',
                                                              'window.clearInterval')(id)),
        'clear-timeout':        (id => require_window_function('clearTimeout',
                                                              'window.clearTimeout')(id)),
        'close':                (() => require_window_function('close',
                                                              'window.close')()),
        'confirm':              (msg => require_window_function('confirm',
                                                               'window.confirm')(from_fasl(msg)) ? 1 : 0),
        'create-image-bitmap':  ((image, sx, sy, sw, sh, opts) => {
            const createImageBitmap = require_window_function('createImageBitmap',
                                                              'window.createImageBitmap');
            const Sx = from_fasl(sx);
            const Sy = from_fasl(sy);
            const Sw = from_fasl(sw);
            const Sh = from_fasl(sh);
            const o  = from_fasl(opts);
            if (Sx === undefined) {
                return createImageBitmap(image);
            } else if (o === undefined) {
                return createImageBitmap(image, Sx, Sy, Sw, Sh);
            } else {
                return createImageBitmap(image, Sx, Sy, Sw, Sh, o);
            }
        }),
        'fetch': ((input, init) => {
            const windowFetch = require_window_function('fetch', 'window.fetch');
            const inp = from_fasl(input);
            const i   = from_fasl(init);
            if (i === undefined) {
                return windowFetch(inp);
            } else {
                return windowFetch(inp, i);
            }
        }),
        'focus':                (() => require_window_function('focus',
                                                              'window.focus')()),
        'get-computed-style':   ((elt, pseudo) => {
            const getComputedStyle = require_window_function('getComputedStyle',
                                                            'window.getComputedStyle');
            const p = from_fasl(pseudo);
            return getComputedStyle(elt, p);
        }),
        'get-selection':        (() => require_window_function('getSelection',
                                                              'window.getSelection')()),
        'match-media':          (q => require_window_function('matchMedia',
                                                             'window.matchMedia')(from_fasl(q))),
        'move-by':              ((x, y) => require_window_function('moveBy',
                                                                  'window.moveBy')(x, y)),
        'move-to':              ((x, y) => require_window_function('moveTo',
                                                                  'window.moveTo')(x, y)),
        'open':                 ((url, target, features, replace) => {
            const windowOpen = require_window_function('open', 'window.open');
            const u = from_fasl(url);
            const t = from_fasl(target);
            const f = from_fasl(features);
            const r = from_fasl(replace);
            if (t === undefined && f === undefined && r === undefined) {
                return windowOpen(u);
            } else if (f === undefined && r === undefined) {
                return windowOpen(u, t);
            } else if (r === undefined) {
                return windowOpen(u, t, f);
            } else {
                return windowOpen(u, t, f, r);
            }
        }),
        'post-message':        ((msg, target, transfer) => {
            const postMessage = require_window_function('postMessage',
                                                       'window.postMessage');
            const t = from_fasl(transfer);
            if (t === undefined) {
                postMessage(from_fasl(msg), from_fasl(target));
            } else {
                postMessage(from_fasl(msg), from_fasl(target), t);
            }
        }),
        'print':               (() => require_window_function('print',
                                                             'window.print')()),
        'prompt':              ((msg, def) => require_window_function('prompt',
                                                                     'window.prompt')(from_fasl(msg), from_fasl(def))),
        'request-animation-frame': (cb => require_window_function('requestAnimationFrame',
                                                                  'window.requestAnimationFrame')(cb)),
        'request-idle-callback': ((cb, opts) => {
            const requestIdleCallback = require_window_function('requestIdleCallback',
                                                               'window.requestIdleCallback');
            const o = from_fasl(opts);
            if (o === undefined) {
                return requestIdleCallback(cb);
            } else {
                return requestIdleCallback(cb, o);
            }
        }),
        'resize-by':           ((x, y) => require_window_function('resizeBy',
                                                                 'window.resizeBy')(x, y)),
        'resize-to':           ((w, h) => require_window_function('resizeTo',
                                                                 'window.resizeTo')(w, h)),
        'scroll':              ((x, y, opts) => {
            const scroll = require_window_function('scroll', 'window.scroll');
            const o = from_fasl(opts);
            if (o === undefined) {
                scroll(x, y);
            } else {
                scroll(o);
            }
        }),
        'scroll-by':           ((x, y, opts) => {
            const scrollBy = require_window_function('scrollBy', 'window.scrollBy');
            const o = from_fasl(opts);
            if (o === undefined) {
                scrollBy(x, y);
            } else {
                scrollBy(o);
            }
        }),
        'scroll-to':           ((x, y, opts) => {
            const scrollTo = require_window_function('scrollTo', 'window.scrollTo');
            const o = from_fasl(opts);
            if (o === undefined) {
                scrollTo(x, y);
            } else {
                scrollTo(o);
            }
        }),
        'set-interval':        ((handler, delay) => require_window_function('setInterval',
                                                                           'window.setInterval')(handler, delay)),
        'set-timeout':         ((handler)        => require_window_function('setTimeout',
                                                                           'window.setTimeout')(handler)),
        'set-timeout/delay':   ((handler, delay) => require_window_function('setTimeout',
                                                                           'window.setTimeout')(handler, delay)),
        'stop':                (() => require_window_function('stop',
                                                             'window.stop')()),
        'structured-clone':    ((value, options) => {
            const structuredClone = require_window_function('structuredClone',
                                                           'window.structuredClone');
            const o = from_fasl(options);
            if (o === undefined) {
                return structuredClone(from_fasl(value));
            } else {
                return structuredClone(from_fasl(value), o);
            }
        }),
        'queue-microtask':     (cb => require_window_function('queueMicrotask',
                                                             'window.queueMicrotask')(cb)),
        'report-error':        (err => require_window_function('reportError',
                                                              'window.reportError')(from_fasl(err)))
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    // Performance
    'performance': hasPerformance ? {
        'event-counts':        (() => get_performance_property('eventCounts')),
        'interaction-count':   (() => get_performance_property('interactionCount')),
        'memory':              (() => get_performance_property('memory')),
        'time-origin':         (() => get_performance_property('timeOrigin')),
        'now':                 (() => require_host_function(performance,
                                                             'now',
                                                             'performance.now')()),
        'clear-marks':         ((markName) => {
            const clearMarks = require_host_function(performance,
                                                     'clearMarks',
                                                     'performance.clearMarks');
            const n = from_fasl(markName);
            if (n === undefined) {
                clearMarks();
            } else {
                clearMarks(n);
            }
        }),
        'clear-measures':      ((measureName) => {
            const clearMeasures = require_host_function(performance,
                                                        'clearMeasures',
                                                        'performance.clearMeasures');
            const n = from_fasl(measureName);
            if (n === undefined) {
                clearMeasures();
            } else {
                clearMeasures(n);
            }
        }),
        'clear-resource-timings': (() => require_host_function(performance,
                                                               'clearResourceTimings',
                                                               'performance.clearResourceTimings')()),
        'get-entries':         (() => require_host_function(performance,
                                                            'getEntries',
                                                            'performance.getEntries')()),
        'get-entries-by-name': ((name, entryType) => {
            const getEntriesByName = require_host_function(performance,
                                                           'getEntriesByName',
                                                           'performance.getEntriesByName');
            const t = from_fasl(entryType);
            if (t === undefined) {
                return getEntriesByName(from_fasl(name));
            } else {
                return getEntriesByName(from_fasl(name), t);
            }
        }),
        'get-entries-by-type':  ((entryType) => require_host_function(performance,
                                                                      'getEntriesByType',
                                                                      'performance.getEntriesByType')(from_fasl(entryType))),
        'mark':                ((name, options) => {
            const mark = require_host_function(performance,
                                               'mark',
                                               'performance.mark');
            const o = from_fasl(options);
            if (o === undefined) {
                return mark(from_fasl(name));
            } else {
                return mark(from_fasl(name), o);
            }
        }),
        'measure':             ((name, startOrOptions, endMark) => {
            const measure = require_host_function(performance,
                                                  'measure',
                                                  'performance.measure');
            const s = from_fasl(startOrOptions);
            const e = from_fasl(endMark);
            if (s === undefined && e === undefined) {
                return measure(from_fasl(name));
            } else if (e === undefined) {
                return measure(from_fasl(name), s);
            } else {
                return measure(from_fasl(name), s, e);
            }
        }),
        'measure-user-agent-specific-memory': (() => require_host_function(performance,
                                                                           'measureUserAgentSpecificMemory',
                                                                           'performance.measureUserAgentSpecificMemory')()),
        'set-resource-timing-buffer-size': ((size) => require_host_function(performance,
                                                                            'setResourceTimingBufferSize',
                                                                            'performance.setResourceTimingBufferSize')(size)),
        'to-json':             (() => require_host_function(performance,
                                                            'toJSON',
                                                            'performance.toJSON')())
    } : new Proxy({}, { get() { throw new Error('Performance API not available in this environment'); } }),
    'performance-event-count-map': hasPerformance ? {
        'size':                (list => get_performance_event_counts_property(list, 'size'))
    } : new Proxy({}, { get() { throw new Error('Performance API not available in this environment'); } }),
    'performance-memory-info': hasPerformance ? {
        'js-heap-size-limit':  (mem => get_performance_memory_info_property(mem, 'jsHeapSizeLimit')),
        'total-js-heap-size':  (mem => get_performance_memory_info_property(mem, 'totalJSHeapSize')),
        'used-js-heap-size':   (mem => get_performance_memory_info_property(mem, 'usedJSHeapSize'))
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    'websocket': websocket,
    'audio': audio,
    // Document
    'document': hasDOM ? {
        'document':                 (()                               => require_document_target('document')),
        'head':                     (()                               => require_document_value('head',
                                                                                                 'document.head')),
        'body':                     (()                               => require_document_value('body',
                                                                                                 'document.body')),
        'document-element':         (()                               => require_document_value('documentElement',
                                                                                                 'document.documentElement')),
        'create-element':           ((local_name)                     => require_document_function('createElement',
                                                                                                    'document.createElement')(from_fasl(local_name))),
        'create-text-node':         ((fasl_start)                     => require_document_function('createTextNode',
                                                                                                    'document.createTextNode')(from_fasl(fasl_start))),
        'adopt-node':               ((node)                           => require_document_function('adoptNode',
                                                                                                    'document.adoptNode')(node)),
        'caret-range-from-point':   ((x, y)                           => require_document_function('caretRangeFromPoint',
                                                                                                    'document.caretRangeFromPoint')(x, y)),
        'capture-events':           (()                               => require_document_function('captureEvents',
                                                                                                    'document.captureEvents')()),
        'clear':                    (()                               => require_document_function('clear',
                                                                                                    'document.clear')()),
        'close':                    (()                               => require_document_function('close',
                                                                                                    'document.close')()),
        'create-attribute':         ((name)                           => require_document_function('createAttribute',
                                                                                                    'document.createAttribute')(from_fasl(name))),
        'create-attribute-ns':      ((ns, name)                      => require_document_function('createAttributeNS',
                                                                                                   'document.createAttributeNS')(from_fasl(ns), from_fasl(name))),
        'create-cdata-section':     ((data)                           => require_document_function('createCDATASection',
                                                                                                    'document.createCDATASection')(from_fasl(data))),
        'create-comment':           ((data)                           => require_document_function('createComment',
                                                                                                    'document.createComment')(from_fasl(data))),
        'create-document-fragment': (()                               => require_document_function('createDocumentFragment',
                                                                                                    'document.createDocumentFragment')()),
        'create-element-ns':        ((ns, name)                       => require_document_function('createElementNS',
                                                                                                    'document.createElementNS')(from_fasl(ns), from_fasl(name))),
        'create-event':             ((type)                           => require_document_function('createEvent',
                                                                                                    'document.createEvent')(from_fasl(type))),
        'create-expression':        ((expr, resolver)                 => require_document_function('createExpression',
                                                                                                    'document.createExpression')(from_fasl(expr), resolver)),
        'create-ns-resolver':       ((node)                           => require_document_function('createNSResolver',
                                                                                                    'document.createNSResolver')(node)),
        'create-node-iterator':     ((root, what, filter)             => require_document_function('createNodeIterator',
                                                                                                    'document.createNodeIterator')(root, what, filter)),
        'create-processing-instruction': ((target, data)             => require_document_function('createProcessingInstruction',
                                                                                                   'document.createProcessingInstruction')(from_fasl(target), from_fasl(data))),
        'create-range':             (()                               => require_document_function('createRange',
                                                                                                    'document.createRange')()),
        'create-tree-walker':       ((root, what, filter)             => require_document_function('createTreeWalker',
                                                                                                    'document.createTreeWalker')(root, what, filter)),
        'element-from-point':       ((x, y)                           => require_document_function('elementFromPoint',
                                                                                                    'document.elementFromPoint')(x, y)),
        'elements-from-point':      ((x, y)                           => require_document_function('elementsFromPoint',
                                                                                                    'document.elementsFromPoint')(x, y)),
        'enable-style-sheets-for-set': ((name)                        => require_document_function('enableStyleSheetsForSet',
                                                                                                    'document.enableStyleSheetsForSet')(from_fasl(name))),
        'evaluate':                 ((expr, ctx, resolver, type, result) => require_document_function('evaluate',
                                                                                                       'document.evaluate')(from_fasl(expr), ctx, resolver, type, result)),
        'exec-command':             ((cmd, show_ui, value)            => require_document_function('execCommand',
                                                                                                    'document.execCommand')(from_fasl(cmd), !!show_ui, from_fasl(value)) ? 1 : 0),
        'exit-fullscreen':          (()                               => require_document_function('exitFullscreen',
                                                                                                    'document.exitFullscreen')()),
        'exit-picture-in-picture':  (()                               => require_document_function('exitPictureInPicture',
                                                                                                    'document.exitPictureInPicture')()),
        'exit-pointer-lock':        (()                               => require_document_function('exitPointerLock',
                                                                                                    'document.exitPointerLock')()),
        'get-element-by-id':        ((id)                             => require_document_function('getElementById',
                                                                                                    'document.getElementById')(from_fasl(id))),
        'get-elements-by-class-name': ((class_name)                   => require_document_function('getElementsByClassName',
                                                                                                   'document.getElementsByClassName')(from_fasl(class_name))),
        'get-elements-by-name':     ((name)                           => require_document_function('getElementsByName',
                                                                                                    'document.getElementsByName')(from_fasl(name))),
        'get-elements-by-tag-name': ((name)                           => require_document_function('getElementsByTagName',
                                                                                                    'document.getElementsByTagName')(from_fasl(name))),
        'get-elements-by-tag-name-ns': ((ns, name)                    => require_document_function('getElementsByTagNameNS',
                                                                                                    'document.getElementsByTagNameNS')(from_fasl(ns), from_fasl(name))),
        'get-selection':            (()                               => require_document_function('getSelection',
                                                                                                    'document.getSelection')()),
        'has-focus':                (()                               => require_document_function('hasFocus',
                                                                                                    'document.hasFocus')() ? 1 : 0),
        'import-node':              ((node, deep)                     => require_document_function('importNode',
                                                                                                    'document.importNode')(node, !!deep)),
        'open':                     (()                               => require_document_function('open',
                                                                                                    'document.open')()),
        // Deprecated:
        // 'query-command-enabled':    ((cmd)                            => document.queryCommandEnabled(from_fasl(cmd)) ? 1 : 0),
        // 'query-command-indeterm':   ((cmd)                            => document.queryCommandIndeterm(from_fasl(cmd)) ? 1 : 0),
        // 'query-command-state':      ((cmd)                            => document.queryCommandState(from_fasl(cmd)) ? 1 : 0),
        // 'query-command-supported':  ((cmd)                            => document.queryCommandSupported(from_fasl(cmd)) ? 1 : 0),
        // 'query-command-value':      ((cmd)                            => document.queryCommandValue(from_fasl(cmd))),
        'query-selector':           ((sel)                            => require_document_function('querySelector',
                                                                                                    'document.querySelector')(from_fasl(sel))),
        'query-selector-all':       ((sel)                            => require_document_function('querySelectorAll',
                                                                                                    'document.querySelectorAll')(from_fasl(sel))),
        'release-events':           (()                               => require_document_function('releaseEvents',
                                                                                                    'document.releaseEvents')()),
        // Deprecated
        // 'write':                    ((text)                           => document.write(from_fasl(text))),
        // 'writeln':                  ((text)                           => document.writeln(from_fasl(text))),
    }
    : { // Node
        'document'()                 { throw new Error('DOM not available in this environment'); },
        'head'()                     { throw new Error('DOM not available in this environment'); },
        'body'()                     { throw new Error('DOM not available in this environment'); },
        'document-element'()         { throw new Error('DOM not available in this environment'); },
        'create-element'()           { throw new Error('DOM not available in this environment'); },
        'create-text-node'()         { throw new Error('DOM not available in this environment'); },
        'adopt-node'()               { throw new Error('DOM not available in this environment'); },
        'caret-range-from-point'()   { throw new Error('DOM not available in this environment'); },
        'capture-events'()           { throw new Error('DOM not available in this environment'); },
        'clear'()                    { throw new Error('DOM not available in this environment'); },
        'close'()                    { throw new Error('DOM not available in this environment'); },
        'create-attribute'()         { throw new Error('DOM not available in this environment'); },
        'create-attribute-ns'()      { throw new Error('DOM not available in this environment'); },
        'create-cdata-section'()     { throw new Error('DOM not available in this environment'); },
        'create-comment'()           { throw new Error('DOM not available in this environment'); },
        'create-document-fragment'() { throw new Error('DOM not available in this environment'); },
        'create-element-ns'()        { throw new Error('DOM not available in this environment'); },
        'create-event'()             { throw new Error('DOM not available in this environment'); },
        'create-expression'()        { throw new Error('DOM not available in this environment'); },
        'create-ns-resolver'()       { throw new Error('DOM not available in this environment'); },
        'create-node-iterator'()     { throw new Error('DOM not available in this environment'); },
        'create-processing-instruction'() { throw new Error('DOM not available in this environment'); },
        'create-range'()             { throw new Error('DOM not available in this environment'); },
        'create-tree-walker'()       { throw new Error('DOM not available in this environment'); },
        'element-from-point'()       { throw new Error('DOM not available in this environment'); },
        'elements-from-point'()      { throw new Error('DOM not available in this environment'); },
        'enable-style-sheets-for-set'() { throw new Error('DOM not available in this environment'); },
        'evaluate'()                 { throw new Error('DOM not available in this environment'); },
        'exec-command'()             { throw new Error('DOM not available in this environment'); },
        'exit-fullscreen'()          { throw new Error('DOM not available in this environment'); },
        'exit-picture-in-picture'()  { throw new Error('DOM not available in this environment'); },
        'exit-pointer-lock'()        { throw new Error('DOM not available in this environment'); },
        'get-element-by-id'()        { throw new Error('DOM not available in this environment'); },
        'get-elements-by-class-name'() { throw new Error('DOM not available in this environment'); },
        'get-elements-by-name'()     { throw new Error('DOM not available in this environment'); },
        'get-elements-by-tag-name'() { throw new Error('DOM not available in this environment'); },
        'get-elements-by-tag-name-ns'() { throw new Error('DOM not available in this environment'); },
        'get-selection'()            { throw new Error('DOM not available in this environment'); },
        'has-focus'()                { throw new Error('DOM not available in this environment'); },
        'import-node'()              { throw new Error('DOM not available in this environment'); },
        'open'()                     { throw new Error('DOM not available in this environment'); },
        'query-command-enabled'()    { throw new Error('DOM not available in this environment'); },
        'query-command-indeterm'()   { throw new Error('DOM not available in this environment'); },
        'query-command-state'()      { throw new Error('DOM not available in this environment'); },
        'query-command-supported'()  { throw new Error('DOM not available in this environment'); },
        'query-command-value'()      { throw new Error('DOM not available in this environment'); },
        'query-selector'()           { throw new Error('DOM not available in this environment'); },
        'query-selector-all'()       { throw new Error('DOM not available in this environment'); },
        'release-events'()           { throw new Error('DOM not available in this environment'); },
        'write'()                    { throw new Error('DOM not available in this environment'); },
        'writeln'()                  { throw new Error('DOM not available in this environment'); },
    },
    // Media
    'media': hasDOM ? {
        'audio-tracks': (m => get_media_property(m, 'audioTracks')),
        'autoplay': (m => get_media_property(m, 'autoplay') ? 1 : 0),
        'set-autoplay!': ((m, flag) => { set_media_property(m, 'autoplay', !!flag); }),
        'buffered': (m => get_media_property(m, 'buffered')),
        'controls': (m => get_media_property(m, 'controls') ? 1 : 0),
        'set-controls!': ((m, flag) => { set_media_property(m, 'controls', !!flag); }),
        'controls-list': (m => get_media_property(m, 'controlsList')),
        'cross-origin': (m => to_fasl(get_media_property(m, 'crossOrigin'))),
        'set-cross-origin!': ((m, o) => { set_media_property(m, 'crossOrigin', from_fasl(o)); }),
        'current-src': (m => get_media_property(m, 'currentSrc')),
        'current-time': (m => get_media_property(m, 'currentTime')),
        'set-current-time!': ((m, t) => { set_media_property(m, 'currentTime', t); }),
        'default-muted': (m => get_media_property(m, 'defaultMuted') ? 1 : 0),
        'set-default-muted!': ((m, flag) => { set_media_property(m, 'defaultMuted', !!flag); }),
        'default-playback-rate': (m => get_media_property(m, 'defaultPlaybackRate')),
        'set-default-playback-rate!': ((m, r) => { set_media_property(m, 'defaultPlaybackRate', r); }),
        'disable-remote-playback': (m => get_media_property(m, 'disableRemotePlayback') ? 1 : 0),
        'set-disable-remote-playback!': ((m, flag) => { set_media_property(m, 'disableRemotePlayback', !!flag); }),
        'duration': (m => get_media_property(m, 'duration')),
        'ended': (m => get_media_property(m, 'ended') ? 1 : 0),
        'error': (m => get_media_property(m, 'error')),
        'loop': (m => get_media_property(m, 'loop') ? 1 : 0),
        'set-loop!': ((m, flag) => { set_media_property(m, 'loop', !!flag); }),
        'media-keys': (m => get_media_property(m, 'mediaKeys')),
        'media-group': (m => get_media_property(m, 'mediaGroup')),
        'set-media-group!': ((m, g) => { set_media_property(m, 'mediaGroup', from_fasl(g)); }),
        'muted': (m => get_media_property(m, 'muted') ? 1 : 0),
        'set-muted!': ((m, flag) => { set_media_property(m, 'muted', !!flag); }),
        'network-state': (m => get_media_property(m, 'networkState')),
        'paused': (m => get_media_property(m, 'paused') ? 1 : 0),
        'playback-rate': (m => get_media_property(m, 'playbackRate')),
        'set-playback-rate!': ((m, r) => { set_media_property(m, 'playbackRate', r); }),
        'played': (m => get_media_property(m, 'played')),
        'preload': (m => get_media_property(m, 'preload')),
        'set-preload!': ((m, p) => { set_media_property(m, 'preload', from_fasl(p)); }),
        'preserves-pitch': (m => get_media_property(m, 'preservesPitch') ? 1 : 0),
        'set-preserves-pitch!': ((m, flag) => { set_media_property(m, 'preservesPitch', !!flag); }),
        'ready-state': (m => get_media_property(m, 'readyState')),
        'seekable': (m => get_media_property(m, 'seekable')),
        'seeking': (m => get_media_property(m, 'seeking') ? 1 : 0),
        'sink-id': (m => get_media_property(m, 'sinkId')),
        'src': (m => get_media_property(m, 'src')),
        'set-src!': ((m, s) => { set_media_property(m, 'src', from_fasl(s)); }),
        'src-object': (m => get_media_property(m, 'srcObject')),
        'set-src-object!': ((m, obj) => { set_media_property(m, 'srcObject', obj); }),
        'text-tracks': (m => get_media_property(m, 'textTracks')),
        'video-tracks': (m => get_media_property(m, 'videoTracks')),
        'volume': (m => get_media_property(m, 'volume')),
        'set-volume!': ((m, v) => { set_media_property(m, 'volume', v); }),
        'add-text-track!': ((m, kind, label, lang) => {
            const addTextTrack = require_host_function(m,
                                                       'addTextTrack',
                                                       'HTMLMediaElement.addTextTrack');
            const l = from_fasl(label);
            const g = from_fasl(lang);
            if (l === undefined && g === undefined) {
                return addTextTrack(from_fasl(kind));
            } else if (g === undefined) {
                return addTextTrack(from_fasl(kind), from_fasl(label));
            } else {
                return addTextTrack(from_fasl(kind), from_fasl(label), from_fasl(lang));
            }
        }),
        'can-play-type': ((m, type) => require_host_function(m,
                                                             'canPlayType',
                                                             'HTMLMediaElement.canPlayType')(from_fasl(type))),
        'capture-stream': ((m, rate) => {
            const captureStream = require_host_function(m,
                                                        'captureStream',
                                                        'HTMLMediaElement.captureStream');
            const r = from_fasl(rate);
            if (r === undefined) {
                return captureStream();
            } else {
                return captureStream(r);
            }
        }),
        'fast-seek!': ((m, t) => { require_host_function(m,
                                                          'fastSeek',
                                                          'HTMLMediaElement.fastSeek')(t); }),
        'load!': (m => { require_host_function(m,
                                                'load',
                                                'HTMLMediaElement.load')(); }),
        'pause': (m => require_host_function(m,
                                             'pause',
                                             'HTMLMediaElement.pause')()),
        'play': (m => require_host_function(m,
                                            'play',
                                            'HTMLMediaElement.play')()),
        'set-media-keys!': ((m, keys) => require_host_function(m,
                                                                'setMediaKeys',
                                                                'HTMLMediaElement.setMediaKeys')(keys)),
        'set-sink-id!': ((m, id) => require_host_function(m,
                                                           'setSinkId',
                                                           'HTMLMediaElement.setSinkId')(from_fasl(id))),
    } : {
        'audio-tracks'() { throw new Error('DOM not available in this environment'); },
        'autoplay'() { throw new Error('DOM not available in this environment'); },
        'set-autoplay!'() { throw new Error('DOM not available in this environment'); },
        'buffered'() { throw new Error('DOM not available in this environment'); },
        'controls'() { throw new Error('DOM not available in this environment'); },
        'set-controls!'() { throw new Error('DOM not available in this environment'); },
        'controls-list'() { throw new Error('DOM not available in this environment'); },
        'cross-origin'() { throw new Error('DOM not available in this environment'); },
        'set-cross-origin!'() { throw new Error('DOM not available in this environment'); },
        'current-src'() { throw new Error('DOM not available in this environment'); },
        'current-time'() { throw new Error('DOM not available in this environment'); },
        'set-current-time!'() { throw new Error('DOM not available in this environment'); },
        'default-muted'() { throw new Error('DOM not available in this environment'); },
        'set-default-muted!'() { throw new Error('DOM not available in this environment'); },
        'default-playback-rate'() { throw new Error('DOM not available in this environment'); },
        'set-default-playback-rate!'() { throw new Error('DOM not available in this environment'); },
        'disable-remote-playback'() { throw new Error('DOM not available in this environment'); },
        'set-disable-remote-playback!'() { throw new Error('DOM not available in this environment'); },
        'duration'() { throw new Error('DOM not available in this environment'); },
        'ended'() { throw new Error('DOM not available in this environment'); },
        'error'() { throw new Error('DOM not available in this environment'); },
        'loop'() { throw new Error('DOM not available in this environment'); },
        'set-loop!'() { throw new Error('DOM not available in this environment'); },
        'media-keys'() { throw new Error('DOM not available in this environment'); },
        'media-group'() { throw new Error('DOM not available in this environment'); },
        'set-media-group!'() { throw new Error('DOM not available in this environment'); },
        'muted'() { throw new Error('DOM not available in this environment'); },
        'set-muted!'() { throw new Error('DOM not available in this environment'); },
        'network-state'() { throw new Error('DOM not available in this environment'); },
        'paused'() { throw new Error('DOM not available in this environment'); },
        'playback-rate'() { throw new Error('DOM not available in this environment'); },
        'set-playback-rate!'() { throw new Error('DOM not available in this environment'); },
        'played'() { throw new Error('DOM not available in this environment'); },
        'preload'() { throw new Error('DOM not available in this environment'); },
        'set-preload!'() { throw new Error('DOM not available in this environment'); },
        'preserves-pitch'() { throw new Error('DOM not available in this environment'); },
        'set-preserves-pitch!'() { throw new Error('DOM not available in this environment'); },
        'ready-state'() { throw new Error('DOM not available in this environment'); },
        'seekable'() { throw new Error('DOM not available in this environment'); },
        'seeking'() { throw new Error('DOM not available in this environment'); },
        'sink-id'() { throw new Error('DOM not available in this environment'); },
        'src'() { throw new Error('DOM not available in this environment'); },
        'set-src!'() { throw new Error('DOM not available in this environment'); },
        'src-object'() { throw new Error('DOM not available in this environment'); },
        'set-src-object!'() { throw new Error('DOM not available in this environment'); },
        'text-tracks'() { throw new Error('DOM not available in this environment'); },
        'video-tracks'() { throw new Error('DOM not available in this environment'); },
        'volume'() { throw new Error('DOM not available in this environment'); },
        'set-volume!'() { throw new Error('DOM not available in this environment'); },
        'add-text-track!'() { throw new Error('DOM not available in this environment'); },
        'can-play-type'() { throw new Error('DOM not available in this environment'); },
        'capture-stream'() { throw new Error('DOM not available in this environment'); },
        'fast-seek!'() { throw new Error('DOM not available in this environment'); },
        'load!'() { throw new Error('DOM not available in this environment'); },
        'pause'() { throw new Error('DOM not available in this environment'); },
        'play'() { throw new Error('DOM not available in this environment'); },
        'set-media-keys!'() { throw new Error('DOM not available in this environment'); },
        'set-sink-id!'() { throw new Error('DOM not available in this environment'); },
    },
    // Image
    'image': hasDOM ? {
        'new': ((width, height) => {
            const ImageCtor = require_host_constructor('Image', 'Image', 'new');
            const w = from_fasl(width);
            const h = from_fasl(height);
            if (w === undefined && h === undefined) {
                return new ImageCtor();
            } else if (h === undefined) {
                return new ImageCtor(w);
            } else {
                return new ImageCtor(w, h);
            }
        }),
        'alt': (img => get_image_property(img, 'alt')),
        'set-alt!': ((img, alt) => { set_image_property(img, 'alt', from_fasl(alt)); }),
        'src': (img => get_image_property(img, 'src')),
        'set-src!': ((img, src) => { set_image_property(img, 'src', from_fasl(src)); }),
        'srcset': (img => get_image_property(img, 'srcset')),
        'set-srcset!': ((img, s) => { set_image_property(img, 'srcset', from_fasl(s)); }),
        'sizes': (img => get_image_property(img, 'sizes')),
        'set-sizes!': ((img, s) => { set_image_property(img, 'sizes', from_fasl(s)); }),
        'cross-origin': (img => to_fasl(get_image_property(img, 'crossOrigin'))),
        'set-cross-origin!': ((img, o) => { set_image_property(img, 'crossOrigin', from_fasl(o)); }),
        'use-map': (img => get_image_property(img, 'useMap')),
        'set-use-map!': ((img, m) => { set_image_property(img, 'useMap', from_fasl(m)); }),
        'is-map': (img => get_image_property(img, 'isMap') ? 1 : 0),
        'set-is-map!': ((img, flag) => { set_image_property(img, 'isMap', !!flag); }),
        'width': (img => get_image_property(img, 'width')),
        'set-width!': ((img, w) => { set_image_property(img, 'width', w); }),
        'height': (img => get_image_property(img, 'height')),
        'set-height!': ((img, h) => { set_image_property(img, 'height', h); }),
        'natural-width': (img => get_image_property(img, 'naturalWidth')),
        'natural-height': (img => get_image_property(img, 'naturalHeight')),
        'complete': (img => get_image_property(img, 'complete') ? 1 : 0),
        'current-src': (img => get_image_property(img, 'currentSrc')),
        'decoding': (img => get_image_property(img, 'decoding')),
        'set-decoding!': ((img, d) => { set_image_property(img, 'decoding', from_fasl(d)); }),
        'fetch-priority': (img => get_image_property(img, 'fetchPriority')),
        'set-fetch-priority!': ((img, p) => { set_image_property(img, 'fetchPriority', from_fasl(p)); }),
        'loading': (img => get_image_property(img, 'loading')),
        'set-loading!': ((img, l) => { set_image_property(img, 'loading', from_fasl(l)); }),
        'referrer-policy': (img => get_image_property(img, 'referrerPolicy')),
        'set-referrer-policy!': ((img, p) => { set_image_property(img, 'referrerPolicy', from_fasl(p)); }),
        'name': (img => get_image_property(img, 'name')),
        'set-name!': ((img, n) => { set_image_property(img, 'name', from_fasl(n)); }),
        'x': (img => get_image_property(img, 'x')),
        'y': (img => get_image_property(img, 'y')),
        'decode': (img => require_host_function(img,
                                                 'decode',
                                                 'HTMLImageElement.decode')())
    } : {
        'new'() { throw new Error('DOM not available in this environment'); },
        'alt'() { throw new Error('DOM not available in this environment'); },
        'set-alt!'() { throw new Error('DOM not available in this environment'); },
        'src'() { throw new Error('DOM not available in this environment'); },
        'set-src!'() { throw new Error('DOM not available in this environment'); },
        'srcset'() { throw new Error('DOM not available in this environment'); },
        'set-srcset!'() { throw new Error('DOM not available in this environment'); },
        'sizes'() { throw new Error('DOM not available in this environment'); },
        'set-sizes!'() { throw new Error('DOM not available in this environment'); },
        'cross-origin'() { throw new Error('DOM not available in this environment'); },
        'set-cross-origin!'() { throw new Error('DOM not available in this environment'); },
        'use-map'() { throw new Error('DOM not available in this environment'); },
        'set-use-map!'() { throw new Error('DOM not available in this environment'); },
        'is-map'() { throw new Error('DOM not available in this environment'); },
        'set-is-map!'() { throw new Error('DOM not available in this environment'); },
        'width'() { throw new Error('DOM not available in this environment'); },
        'set-width!'() { throw new Error('DOM not available in this environment'); },
        'height'() { throw new Error('DOM not available in this environment'); },
        'set-height!'() { throw new Error('DOM not available in this environment'); },
        'natural-width'() { throw new Error('DOM not available in this environment'); },
        'natural-height'() { throw new Error('DOM not available in this environment'); },
        'complete'() { throw new Error('DOM not available in this environment'); },
        'current-src'() { throw new Error('DOM not available in this environment'); },
        'decoding'() { throw new Error('DOM not available in this environment'); },
        'set-decoding!'() { throw new Error('DOM not available in this environment'); },
        'fetch-priority'() { throw new Error('DOM not available in this environment'); },
        'set-fetch-priority!'() { throw new Error('DOM not available in this environment'); },
        'loading'() { throw new Error('DOM not available in this environment'); },
        'set-loading!'() { throw new Error('DOM not available in this environment'); },
        'referrer-policy'() { throw new Error('DOM not available in this environment'); },
        'set-referrer-policy!'() { throw new Error('DOM not available in this environment'); },
        'name'() { throw new Error('DOM not available in this environment'); },
        'set-name!'() { throw new Error('DOM not available in this environment'); },
        'x'() { throw new Error('DOM not available in this environment'); },
        'y'() { throw new Error('DOM not available in this environment'); },
        'decode'() { throw new Error('DOM not available in this environment'); }
    },
    // Event
    'event': hasDOM ? {
        'new': ((type, init) => {
            const EventCtor = require_host_constructor('Event', 'Event', 'new');
            const t = from_fasl(type);
            const i = from_fasl(init);
            if (i === undefined) {
                return new EventCtor(t);
            } else {
                return new EventCtor(t, i);
            }
        }),
        'event?': (evt => (typeof Event !== 'undefined') && (evt instanceof Event)),
        'type': (evt => get_event_property(evt, 'type')),
        'target': (evt => get_event_property(evt, 'target')),
        'current-target': (evt => get_event_property(evt, 'currentTarget')),
        'event-phase': (evt => get_event_property(evt, 'eventPhase')),
        'bubbles': (evt => get_event_property(evt, 'bubbles') ? 1 : 0),
        'cancelable': (evt => get_event_property(evt, 'cancelable') ? 1 : 0),
        'default-prevented': (evt => get_event_property(evt, 'defaultPrevented') ? 1 : 0),
        'composed': (evt => get_event_property(evt, 'composed') ? 1 : 0),
        'is-trusted': (evt => get_event_property(evt, 'isTrusted') ? 1 : 0),
        'time-stamp': (evt => get_event_property(evt, 'timeStamp')),
        'composed-path': (evt => require_host_function(evt,
                                                        'composedPath',
                                                        'Event.composedPath')()),
        'prevent-default': (evt => require_host_function(evt,
                                                         'preventDefault',
                                                         'Event.preventDefault')()),
        'mouse-offset-x': (evt => get_mouse_event_property(evt, 'offsetX')),
        'mouse-offset-y': (evt => get_mouse_event_property(evt, 'offsetY')),
        'mouse-client-x': (evt => get_mouse_event_property(evt, 'clientX')),
        'mouse-client-y': (evt => get_mouse_event_property(evt, 'clientY')),
        'mouse-page-x': (evt => get_mouse_event_property(evt, 'pageX')),
        'mouse-page-y': (evt => get_mouse_event_property(evt, 'pageY')),
        'mouse-screen-x': (evt => get_mouse_event_property(evt, 'screenX')),
        'mouse-screen-y': (evt => get_mouse_event_property(evt, 'screenY')),
        'mouse-button': (evt => get_mouse_event_property(evt, 'button')),
        'mouse-buttons': (evt => get_mouse_event_property(evt, 'buttons')),
        'mouse-alt-key': (evt => get_mouse_event_property(evt, 'altKey') ? 1 : 0),
        'mouse-ctrl-key': (evt => get_mouse_event_property(evt, 'ctrlKey') ? 1 : 0),
        'mouse-meta-key': (evt => get_mouse_event_property(evt, 'metaKey') ? 1 : 0),
        'mouse-shift-key': (evt => get_mouse_event_property(evt, 'shiftKey') ? 1 : 0),
        'mouse-event?': (evt => (typeof MouseEvent !== 'undefined') && (evt instanceof MouseEvent)),
        'keyboard-key': (evt => get_keyboard_event_property(evt, 'key')),
        'keyboard-code': (evt => get_keyboard_event_property(evt, 'code')),
        'keyboard-event?': (evt => (typeof KeyboardEvent !== 'undefined') && (evt instanceof KeyboardEvent)),
        'alt-key': (evt => get_keyboard_event_property(evt, 'altKey') ? 1 : 0),
        'ctrl-key': (evt => get_keyboard_event_property(evt, 'ctrlKey') ? 1 : 0),
        'meta-key': (evt => get_keyboard_event_property(evt, 'metaKey') ? 1 : 0),
        'shift-key': (evt => get_keyboard_event_property(evt, 'shiftKey') ? 1 : 0),
        'keyboard-repeat': (evt => get_keyboard_event_property(evt, 'repeat') ? 1 : 0),
        'pointer-event?': (evt => (typeof PointerEvent !== 'undefined') && (evt instanceof PointerEvent)),
        'focus-event?': (evt => (typeof FocusEvent !== 'undefined') && (evt instanceof FocusEvent)),
        'input-event?': (evt => (typeof InputEvent !== 'undefined') && (evt instanceof InputEvent)),
        'submit-event?': (evt => (typeof SubmitEvent !== 'undefined') && (evt instanceof SubmitEvent)),
        'touch-event?': (evt => (typeof TouchEvent !== 'undefined') && (evt instanceof TouchEvent)),
        'touches': (evt => get_touch_event_property(evt, 'touches')),
        'target-touches': (evt => get_touch_event_property(evt, 'targetTouches')),
        'changed-touches': (evt => get_touch_event_property(evt, 'changedTouches')),
        'wheel-event?': (evt => (typeof WheelEvent !== 'undefined') && (evt instanceof WheelEvent)),
        'stop-propagation': (evt => require_host_function(evt,
                                                          'stopPropagation',
                                                          'Event.stopPropagation')()),
        'stop-immediate-propagation': (evt => require_host_function(evt,
                                                                    'stopImmediatePropagation',
                                                                    'Event.stopImmediatePropagation')())
    } : {
        'new'() { throw new Error('DOM not available in this environment'); },
        'event?'() { throw new Error('DOM not available in this environment'); },
        'type'() { throw new Error('DOM not available in this environment'); },
        'target'() { throw new Error('DOM not available in this environment'); },
        'current-target'() { throw new Error('DOM not available in this environment'); },
        'event-phase'() { throw new Error('DOM not available in this environment'); },
        'bubbles'() { throw new Error('DOM not available in this environment'); },
        'cancelable'() { throw new Error('DOM not available in this environment'); },
        'default-prevented'() { throw new Error('DOM not available in this environment'); },
        'composed'() { throw new Error('DOM not available in this environment'); },
        'is-trusted'() { throw new Error('DOM not available in this environment'); },
        'time-stamp'() { throw new Error('DOM not available in this environment'); },
        'composed-path'() { throw new Error('DOM not available in this environment'); },
        'prevent-default'() { throw new Error('DOM not available in this environment'); },
        'mouse-offset-x'() { throw new Error('DOM not available in this environment'); },
        'mouse-offset-y'() { throw new Error('DOM not available in this environment'); },
        'mouse-client-x'() { throw new Error('DOM not available in this environment'); },
        'mouse-client-y'() { throw new Error('DOM not available in this environment'); },
        'mouse-page-x'() { throw new Error('DOM not available in this environment'); },
        'mouse-page-y'() { throw new Error('DOM not available in this environment'); },
        'mouse-screen-x'() { throw new Error('DOM not available in this environment'); },
        'mouse-screen-y'() { throw new Error('DOM not available in this environment'); },
        'mouse-button'() { throw new Error('DOM not available in this environment'); },
        'mouse-buttons'() { throw new Error('DOM not available in this environment'); },
        'mouse-alt-key'() { throw new Error('DOM not available in this environment'); },
        'mouse-ctrl-key'() { throw new Error('DOM not available in this environment'); },
        'mouse-meta-key'() { throw new Error('DOM not available in this environment'); },
        'mouse-shift-key'() { throw new Error('DOM not available in this environment'); },
        'mouse-event?'() { throw new Error('DOM not available in this environment'); },
        'keyboard-key'() { throw new Error('DOM not available in this environment'); },
        'keyboard-code'() { throw new Error('DOM not available in this environment'); },
        'keyboard-event?'() { throw new Error('DOM not available in this environment'); },
        'alt-key'() { throw new Error('DOM not available in this environment'); },
        'ctrl-key'() { throw new Error('DOM not available in this environment'); },
        'meta-key'() { throw new Error('DOM not available in this environment'); },
        'shift-key'() { throw new Error('DOM not available in this environment'); },
        'keyboard-repeat'() { throw new Error('DOM not available in this environment'); },
        'pointer-event?'() { throw new Error('DOM not available in this environment'); },
        'focus-event?'() { throw new Error('DOM not available in this environment'); },
        'input-event?'() { throw new Error('DOM not available in this environment'); },
        'submit-event?'() { throw new Error('DOM not available in this environment'); },
        'touch-event?'() { throw new Error('DOM not available in this environment'); },
        'touches'() { throw new Error('DOM not available in this environment'); },
        'target-touches'() { throw new Error('DOM not available in this environment'); },
        'changed-touches'() { throw new Error('DOM not available in this environment'); },
        'wheel-event?'() { throw new Error('DOM not available in this environment'); },
        'stop-propagation'() { throw new Error('DOM not available in this environment'); },
        'stop-immediate-propagation'() { throw new Error('DOM not available in this environment'); }
    },
    // MessageEvent
    'message-event': hasDOM ? {
        'message-event?': (evt => (typeof MessageEvent !== 'undefined') && (evt instanceof MessageEvent)),
        'data': (evt => get_message_event_property(evt, 'data')),
        'origin': (evt => get_message_event_property(evt, 'origin')),
        'last-event-id': (evt => get_message_event_property(evt, 'lastEventId')),
        'source': (evt => get_message_event_property(evt, 'source')),
        'ports': (evt => get_message_event_property(evt, 'ports'))
    } : {
        'message-event?'() { throw new Error('DOM not available in this environment'); },
        'data'() { throw new Error('DOM not available in this environment'); },
        'origin'() { throw new Error('DOM not available in this environment'); },
        'last-event-id'() { throw new Error('DOM not available in this environment'); },
        'source'() { throw new Error('DOM not available in this environment'); },
        'ports'() { throw new Error('DOM not available in this environment'); }
    },
    // CloseEvent
    'close-event': hasDOM ? {
        'close-event?': (evt => (typeof CloseEvent !== 'undefined') && (evt instanceof CloseEvent)),
        'was-clean': (evt => get_close_event_property(evt, 'wasClean') ? 1 : 0),
        'code': (evt => get_close_event_property(evt, 'code')),
        'reason': (evt => get_close_event_property(evt, 'reason'))
    } : {
        'close-event?'() { throw new Error('DOM not available in this environment'); },
        'was-clean'() { throw new Error('DOM not available in this environment'); },
        'code'() { throw new Error('DOM not available in this environment'); },
        'reason'() { throw new Error('DOM not available in this environment'); }
    },
    // TouchList
    'touch-list': hasDOM ? {
        'touch-list?': (xs => (typeof TouchList !== 'undefined') && (xs instanceof TouchList)),
        'length': (xs => get_touch_list_property(xs, 'length')),
        'ref': ((xs, i) => require_host_function(xs,
                                                  'item',
                                                  'TouchList.item')(i))
    } : {
        'touch-list?'() { throw new Error('DOM not available in this environment'); },
        'length'() { throw new Error('DOM not available in this environment'); },
        'ref'() { throw new Error('DOM not available in this environment'); }
    },
    // Touch
    'touch': hasDOM ? {
        'touch?': (t => (typeof Touch !== 'undefined') && (t instanceof Touch)),
        'identifier': (t => get_touch_property(t, 'identifier')),
        'client-x': (t => get_touch_property(t, 'clientX')),
        'client-y': (t => get_touch_property(t, 'clientY')),
        'page-x': (t => get_touch_property(t, 'pageX')),
        'page-y': (t => get_touch_property(t, 'pageY')),
        'screen-x': (t => get_touch_property(t, 'screenX')),
        'screen-y': (t => get_touch_property(t, 'screenY'))
    } : {
        'touch?'() { throw new Error('DOM not available in this environment'); },
        'identifier'() { throw new Error('DOM not available in this environment'); },
        'client-x'() { throw new Error('DOM not available in this environment'); },
        'client-y'() { throw new Error('DOM not available in this environment'); },
        'page-x'() { throw new Error('DOM not available in this environment'); },
        'page-y'() { throw new Error('DOM not available in this environment'); },
        'screen-x'() { throw new Error('DOM not available in this environment'); },
        'screen-y'() { throw new Error('DOM not available in this environment'); }
    },
    // DOMRect
    'dom-rect': hasDOM ? {
        'left':   (rect => get_dom_rect_property(rect, 'left')),
        'top':    (rect => get_dom_rect_property(rect, 'top')),
        'width':  (rect => get_dom_rect_property(rect, 'width')),
        'height': (rect => get_dom_rect_property(rect, 'height'))
    } : {
        'left'()   { throw new Error('DOM not available in this environment'); },
        'top'()    { throw new Error('DOM not available in this environment'); },
        'width'()  { throw new Error('DOM not available in this environment'); },
        'height'() { throw new Error('DOM not available in this environment'); }
    },
    // EventTarget
    'event-target': hasDOM ? {
        'add-event-listener!': ((target, type, listener) => require_host_function(target,
                                                                                  'addEventListener',
                                                                                  'EventTarget.addEventListener')(from_fasl(type), listener))
    } : {
        'add-event-listener!'() { throw new Error('DOM not available in this environment'); }
    },
    // Element
    'element': hasDOM ? {
        'class-list':              (elem => get_element_property(elem, 'classList')),
        'id':                      (elem => get_element_property(elem, 'id')),
        'set-id!':                 ((elem, id) => { set_element_property(elem, 'id', from_fasl(id)); }),
        'class-name':              (elem => get_element_property(elem, 'className')),
        'set-class-name!':         ((elem, name) => { set_element_property(elem, 'className', from_fasl(name)); }),
        'tag-name':                (elem => get_element_property(elem, 'tagName')),
        'local-name':              (elem => get_element_property(elem, 'localName')),
        'namespace-uri':           (elem => get_element_property(elem, 'namespaceURI')),
        'prefix':                  (elem => get_element_property(elem, 'prefix')),
        'is-connected':            (elem => get_element_property(elem, 'isConnected') ? 1 : 0),
        'children':                (elem => get_element_property(elem, 'children')),
        'scroll-top':              (elem => get_element_property(elem, 'scrollTop')),
        'set-scroll-top!':         ((elem, value) => { set_element_property(elem, 'scrollTop', from_fasl(value)); }),
        'scroll-left':             (elem => get_element_property(elem, 'scrollLeft')),
        'set-scroll-left!':        ((elem, value) => { set_element_property(elem, 'scrollLeft', from_fasl(value)); }),
        'scroll-width':            (elem => get_element_property(elem, 'scrollWidth')),
        'scroll-height':           (elem => get_element_property(elem, 'scrollHeight')),
        'client-width':            (elem => get_element_property(elem, 'clientWidth')),
        'client-height':           (elem => get_element_property(elem, 'clientHeight')),
        'offset-width':            (elem => get_element_property(elem, 'offsetWidth')),
        'offset-height':           (elem => get_element_property(elem, 'offsetHeight')),
        'child-element-count':      (elem => get_element_property(elem, 'childElementCount')),
        'first-element-child':     (elem => get_element_property(elem, 'firstElementChild')),
        'last-element-child':      (elem => get_element_property(elem, 'lastElementChild')),
        'parent-element':          (elem => get_element_property(elem, 'parentElement')),
        'previous-element-sibling': (elem => get_element_property(elem, 'previousElementSibling')),
        'next-element-sibling':    (elem => get_element_property(elem, 'nextElementSibling')),
        'inner-html':              (elem => get_element_property(elem, 'innerHTML')),
        'set-inner-html!':         ((elem, html) => { set_element_property(elem, 'innerHTML', from_fasl(html)); }),
        'outer-html':              (elem => get_element_property(elem, 'outerHTML')),
        'set-outer-html!':         ((elem, html) => { set_element_property(elem, 'outerHTML', from_fasl(html)); }),
        'text-content':            (elem => get_element_property(elem, 'textContent')),
        'set-text-content!':       ((elem, text) => { set_element_property(elem, 'textContent', from_fasl(text)); }),
        'shadow-root':             (elem => get_element_property(elem, 'shadowRoot')),
        'dom-token-list-value':    (list => get_dom_token_list_property(list, 'value')),
        'dom-token-list-length':   (list => get_dom_token_list_property(list, 'length')),
        'dom-token-list-item':     ((list, index)         => require_host_function(list,
                                                                                   'item',
                                                                                   'DOMTokenList.item')(index)),
        'node-list-length':       (list => get_node_list_property(list, 'length')),
        'node-list-item':         ((list, index)         => require_host_function(list,
                                                                                 'item',
                                                                                 'NodeList.item')(index)),
        'html-collection-length': (list => get_html_collection_property(list, 'length')),
        'html-collection-item':   ((list, index)         => require_host_function(list,
                                                                                 'item',
                                                                                 'HTMLCollection.item')(index)),
        'html-collection-named-item': ((list, name)      => require_host_function(list,
                                                                                  'namedItem',
                                                                                  'HTMLCollection.namedItem')(from_fasl(name))),
        'shadow-root-host':       (root => get_shadow_root_property(root, 'host')),
        'shadow-root-mode':       (root => get_shadow_root_property(root, 'mode')),
        'shadow-root-delegates-focus': (root => get_shadow_root_property(root, 'delegatesFocus') ? 1 : 0),
        'dom-rect-list-length':   (list => get_dom_rect_list_property(list, 'length')),
        'dom-rect-list-item':     ((list, index)         => require_host_function(list,
                                                                                 'item',
                                                                                 'DOMRectList.item')(index)),
        'append-child!':           ((parent, child)          => require_host_function(parent,
                                                                                      'appendChild',
                                                                                      'Node.appendChild')(child)),
        'set-attribute!':          ((elem, name, value)      => require_host_function(elem,
                                                                                      'setAttribute',
                                                                                      'Element.setAttribute')(from_fasl(name), from_fasl(value))),
        'after!':                  ((elem, node)            => require_host_function(elem,
                                                                                     'after',
                                                                                     'Element.after')(node)),
        'animate':                 ((elem, keyframes, opts) => require_host_function(elem,
                                                                                      'animate',
                                                                                      'Element.animate')(keyframes, opts)),
        'append!':                 ((elem, node)            => require_host_function(elem,
                                                                                     'append',
                                                                                     'Element.append')(node)),
        'attach-shadow!':          ((elem, init)            => require_host_function(elem,
                                                                                     'attachShadow',
                                                                                     'Element.attachShadow')(init)),
        'before!':                 ((elem, node)            => require_host_function(elem,
                                                                                     'before',
                                                                                     'Element.before')(node)),
        'closest':                 ((elem, sel)             => require_host_function(elem,
                                                                                     'closest',
                                                                                     'Element.closest')(from_fasl(sel))),
        'computed-style-map':      ((elem)                  => require_host_function(elem,
                                                                                     'computedStyleMap',
                                                                                     'Element.computedStyleMap')()),
        'get-animations':          ((elem)                  => require_host_function(elem,
                                                                                     'getAnimations',
                                                                                     'Element.getAnimations')()),
        'get-attribute':           ((elem, name)            => require_host_function(elem,
                                                                                     'getAttribute',
                                                                                     'Element.getAttribute')(from_fasl(name))),
        'get-attribute-ns':        ((elem, ns, name)       => require_host_function(elem,
                                                                                    'getAttributeNS',
                                                                                    'Element.getAttributeNS')(from_fasl(ns), from_fasl(name))),
        'get-attribute-names':     ((elem)                  => require_host_function(elem,
                                                                                     'getAttributeNames',
                                                                                     'Element.getAttributeNames')()),
        'get-attribute-node':      ((elem, name)            => require_host_function(elem,
                                                                                     'getAttributeNode',
                                                                                     'Element.getAttributeNode')(from_fasl(name))),
        'get-attribute-node-ns':   ((elem, ns, name)       => require_host_function(elem,
                                                                                    'getAttributeNodeNS',
                                                                                    'Element.getAttributeNodeNS')(from_fasl(ns), from_fasl(name))),
        'get-bounding-client-rect':((elem)                  => require_host_function(elem,
                                                                                     'getBoundingClientRect',
                                                                                     'Element.getBoundingClientRect')()),
        'get-client-rects':        ((elem)                  => require_host_function(elem,
                                                                                     'getClientRects',
                                                                                     'Element.getClientRects')()),
        'get-elements-by-class-name': ((elem, class_name)   => require_host_function(elem,
                                                                                     'getElementsByClassName',
                                                                                     'Element.getElementsByClassName')(from_fasl(class_name))),
        'get-elements-by-tag-name':  ((elem, name)          => require_host_function(elem,
                                                                                    'getElementsByTagName',
                                                                                    'Element.getElementsByTagName')(from_fasl(name))),
        'get-elements-by-tag-name-ns': ((elem, ns, name)    => require_host_function(elem,
                                                                                     'getElementsByTagNameNS',
                                                                                     'Element.getElementsByTagNameNS')(from_fasl(ns), from_fasl(name))),
        'has-attribute':           ((elem, name)            => require_host_function(elem,
                                                                                     'hasAttribute',
                                                                                     'Element.hasAttribute')(from_fasl(name)) ? 1 : 0),
        'has-attribute-ns':        ((elem, ns, name)       => require_host_function(elem,
                                                                                    'hasAttributeNS',
                                                                                    'Element.hasAttributeNS')(from_fasl(ns), from_fasl(name)) ? 1 : 0),
        'has-attributes':          ((elem)                  => require_host_function(elem,
                                                                                     'hasAttributes',
                                                                                     'Element.hasAttributes')() ? 1 : 0),
        'has-pointer-capture':     ((elem, id)             => require_host_function(elem,
                                                                                    'hasPointerCapture',
                                                                                    'Element.hasPointerCapture')(id) ? 1 : 0),
        'insert-adjacent-element!':((elem, pos, newElem)   => require_host_function(elem,
                                                                                    'insertAdjacentElement',
                                                                                    'Element.insertAdjacentElement')(from_fasl(pos), newElem)),
        'insert-adjacent-html!':   ((elem, pos, data)      => require_host_function(elem,
                                                                                    'insertAdjacentHTML',
                                                                                    'Element.insertAdjacentHTML')(from_fasl(pos), from_fasl(data))),
        'insert-adjacent-text!':   ((elem, pos, data)      => require_host_function(elem,
                                                                                    'insertAdjacentText',
                                                                                    'Element.insertAdjacentText')(from_fasl(pos), from_fasl(data))),
        'matches':                 ((elem, sel)            => require_host_function(elem,
                                                                                    'matches',
                                                                                    'Element.matches')(from_fasl(sel)) ? 1 : 0),
        'prepend!':                ((elem, node)           => require_host_function(elem,
                                                                                    'prepend',
                                                                                    'Element.prepend')(node)),
        'query-selector':          ((elem, sel)            => require_host_function(elem,
                                                                                    'querySelector',
                                                                                    'Element.querySelector')(from_fasl(sel))),
        'query-selector-all':      ((elem, sel)            => require_host_function(elem,
                                                                                    'querySelectorAll',
                                                                                    'Element.querySelectorAll')(from_fasl(sel))),
        'release-pointer-capture!':((elem, id)             => require_host_function(elem,
                                                                                    'releasePointerCapture',
                                                                                    'Element.releasePointerCapture')(id)),
        'remove!':                 ((elem)                  => require_host_function(elem,
                                                                                     'remove',
                                                                                     'Element.remove')()),
        'remove-attribute!':       ((elem, name)            => require_host_function(elem,
                                                                                     'removeAttribute',
                                                                                     'Element.removeAttribute')(from_fasl(name))),
        'remove-attribute-ns!':    ((elem, ns, name)       => require_host_function(elem,
                                                                                    'removeAttributeNS',
                                                                                    'Element.removeAttributeNS')(from_fasl(ns), from_fasl(name))),
        'remove-attribute-node!':  ((elem, attr)           => require_host_function(elem,
                                                                                    'removeAttributeNode',
                                                                                    'Element.removeAttributeNode')(attr)),
        'replace-children!':       ((elem, node)           => require_host_function(elem,
                                                                                    'replaceChildren',
                                                                                    'Element.replaceChildren')(node)),
        'replace-with!':           ((elem, node)           => require_host_function(elem,
                                                                                    'replaceWith',
                                                                                    'Element.replaceWith')(node)),
        'request-fullscreen':      ((elem)                  => require_host_function(elem,
                                                                                     'requestFullscreen',
                                                                                     'Element.requestFullscreen')()),
        'request-pointer-lock':    ((elem)                  => require_host_function(elem,
                                                                                     'requestPointerLock',
                                                                                     'Element.requestPointerLock')()),
        'scroll!':                 ((elem, x, y)           => require_host_function(elem,
                                                                                    'scroll',
                                                                                    'Element.scroll')(x, y)),
        'scroll-by!':              ((elem, x, y)           => require_host_function(elem,
                                                                                    'scrollBy',
                                                                                    'Element.scrollBy')(x, y)),
        'scroll-into-view!':       ((elem, b)              => require_host_function(elem,
                                                                                    'scrollIntoView',
                                                                                    'Element.scrollIntoView')(!!b)),
        'scroll-to!':              ((elem, x, y)           => require_host_function(elem,
                                                                                    'scrollTo',
                                                                                    'Element.scrollTo')(x, y)),
        'set-attribute-ns!':       ((elem, ns, name, value)=> require_host_function(elem,
                                                                                    'setAttributeNS',
                                                                                    'Element.setAttributeNS')(from_fasl(ns), from_fasl(name), from_fasl(value))),
        'set-attribute-node!':     ((elem, attr)           => require_host_function(elem,
                                                                                    'setAttributeNode',
                                                                                    'Element.setAttributeNode')(attr)),
        'set-attribute-node-ns!':  ((elem, attr)           => require_host_function(elem,
                                                                                    'setAttributeNodeNS',
                                                                                    'Element.setAttributeNodeNS')(attr)),
        'set-pointer-capture!':    ((elem, id)             => require_host_function(elem,
                                                                                    'setPointerCapture',
                                                                                    'Element.setPointerCapture')(id)),
        'toggle-attribute!':       ((elem, name, force)    => require_host_function(elem,
                                                                                    'toggleAttribute',
                                                                                    'Element.toggleAttribute')(from_fasl(name), !!force) ? 1 : 0),
        'toggle-attribute':        ((elem, name)           => require_host_function(elem,
                                                                                    'toggleAttribute',
                                                                                    'Element.toggleAttribute')(from_fasl(name)) ? 1 : 0),
    } : {
        'class-list'() { throw new Error('DOM not available in this environment'); },
        'id'() { throw new Error('DOM not available in this environment'); },
        'set-id!'() { throw new Error('DOM not available in this environment'); },
        'class-name'() { throw new Error('DOM not available in this environment'); },
        'set-class-name!'() { throw new Error('DOM not available in this environment'); },
        'tag-name'() { throw new Error('DOM not available in this environment'); },
        'local-name'() { throw new Error('DOM not available in this environment'); },
        'namespace-uri'() { throw new Error('DOM not available in this environment'); },
        'prefix'() { throw new Error('DOM not available in this environment'); },
        'is-connected'() { throw new Error('DOM not available in this environment'); },
        'children'() { throw new Error('DOM not available in this environment'); },
        'scroll-top'() { throw new Error('DOM not available in this environment'); },
        'set-scroll-top!'() { throw new Error('DOM not available in this environment'); },
        'scroll-left'() { throw new Error('DOM not available in this environment'); },
        'set-scroll-left!'() { throw new Error('DOM not available in this environment'); },
        'scroll-width'() { throw new Error('DOM not available in this environment'); },
        'scroll-height'() { throw new Error('DOM not available in this environment'); },
        'client-width'() { throw new Error('DOM not available in this environment'); },
        'client-height'() { throw new Error('DOM not available in this environment'); },
        'offset-width'() { throw new Error('DOM not available in this environment'); },
        'offset-height'() { throw new Error('DOM not available in this environment'); },
        'child-element-count'() { throw new Error('DOM not available in this environment'); },
        'first-element-child'() { throw new Error('DOM not available in this environment'); },
        'last-element-child'() { throw new Error('DOM not available in this environment'); },
        'parent-element'() { throw new Error('DOM not available in this environment'); },
        'previous-element-sibling'() { throw new Error('DOM not available in this environment'); },
        'next-element-sibling'() { throw new Error('DOM not available in this environment'); },
        'inner-html'() { throw new Error('DOM not available in this environment'); },
        'set-inner-html!'() { throw new Error('DOM not available in this environment'); },
        'outer-html'() { throw new Error('DOM not available in this environment'); },
        'set-outer-html!'() { throw new Error('DOM not available in this environment'); },
        'text-content'() { throw new Error('DOM not available in this environment'); },
        'set-text-content!'() { throw new Error('DOM not available in this environment'); },
        'shadow-root'() { throw new Error('DOM not available in this environment'); },
        'dom-token-list-value'() { throw new Error('DOM not available in this environment'); },
        'dom-token-list-length'() { throw new Error('DOM not available in this environment'); },
        'dom-token-list-item'() { throw new Error('DOM not available in this environment'); },
        'node-list-length'() { throw new Error('DOM not available in this environment'); },
        'node-list-item'() { throw new Error('DOM not available in this environment'); },
        'html-collection-length'() { throw new Error('DOM not available in this environment'); },
        'html-collection-item'() { throw new Error('DOM not available in this environment'); },
        'html-collection-named-item'() { throw new Error('DOM not available in this environment'); },
        'shadow-root-host'() { throw new Error('DOM not available in this environment'); },
        'shadow-root-mode'() { throw new Error('DOM not available in this environment'); },
        'shadow-root-delegates-focus'() { throw new Error('DOM not available in this environment'); },
        'dom-rect-list-length'() { throw new Error('DOM not available in this environment'); },
        'dom-rect-list-item'() { throw new Error('DOM not available in this environment'); },
        'append-child!'()             { throw new Error('DOM not available in this environment'); },
        'set-attribute!'()            { throw new Error('DOM not available in this environment'); },
        'after!'()                    { throw new Error('DOM not available in this environment'); },
        'animate'()                   { throw new Error('DOM not available in this environment'); },
        'append!'()                   { throw new Error('DOM not available in this environment'); },
        'attach-shadow!'()            { throw new Error('DOM not available in this environment'); },
        'before!'()                   { throw new Error('DOM not available in this environment'); },
        'closest'()                   { throw new Error('DOM not available in this environment'); },
        'computed-style-map'()        { throw new Error('DOM not available in this environment'); },
        'get-animations'()            { throw new Error('DOM not available in this environment'); },
        'get-attribute'()             { throw new Error('DOM not available in this environment'); },
        'get-attribute-ns'()          { throw new Error('DOM not available in this environment'); },
        'get-attribute-names'()       { throw new Error('DOM not available in this environment'); },
        'get-attribute-node'()        { throw new Error('DOM not available in this environment'); },
        'get-attribute-node-ns'()     { throw new Error('DOM not available in this environment'); },
        'get-bounding-client-rect'()  { throw new Error('DOM not available in this environment'); },
        'get-client-rects'()          { throw new Error('DOM not available in this environment'); },
        'get-elements-by-class-name'(){ throw new Error('DOM not available in this environment'); },
        'get-elements-by-tag-name'()  { throw new Error('DOM not available in this environment'); },
        'get-elements-by-tag-name-ns'(){ throw new Error('DOM not available in this environment'); },
        'has-attribute'()             { throw new Error('DOM not available in this environment'); },
        'has-attribute-ns'()          { throw new Error('DOM not available in this environment'); },
        'has-attributes'()            { throw new Error('DOM not available in this environment'); },
        'has-pointer-capture'()       { throw new Error('DOM not available in this environment'); },
        'insert-adjacent-element!'()  { throw new Error('DOM not available in this environment'); },
        'insert-adjacent-html!'()     { throw new Error('DOM not available in this environment'); },
        'insert-adjacent-text!'()     { throw new Error('DOM not available in this environment'); },
        'matches'()                   { throw new Error('DOM not available in this environment'); },
        'prepend!'()                  { throw new Error('DOM not available in this environment'); },
        'query-selector'()            { throw new Error('DOM not available in this environment'); },
        'query-selector-all'()        { throw new Error('DOM not available in this environment'); },
        'release-pointer-capture!'()  { throw new Error('DOM not available in this environment'); },
        'remove!'()                   { throw new Error('DOM not available in this environment'); },
        'remove-attribute!'()         { throw new Error('DOM not available in this environment'); },
        'remove-attribute-ns!'()      { throw new Error('DOM not available in this environment'); },
        'remove-attribute-node!'()    { throw new Error('DOM not available in this environment'); },
        'replace-children!'()         { throw new Error('DOM not available in this environment'); },
        'replace-with!'()             { throw new Error('DOM not available in this environment'); },
        'request-fullscreen'()        { throw new Error('DOM not available in this environment'); },
        'request-pointer-lock'()      { throw new Error('DOM not available in this environment'); },
        'scroll!'()                   { throw new Error('DOM not available in this environment'); },
        'scroll-by!'()                { throw new Error('DOM not available in this environment'); },
        'scroll-into-view!'()         { throw new Error('DOM not available in this environment'); },
        'scroll-to!'()                { throw new Error('DOM not available in this environment'); },
        'set-attribute-ns!'()         { throw new Error('DOM not available in this environment'); },
        'set-attribute-node!'()       { throw new Error('DOM not available in this environment'); },
        'set-attribute-node-ns!'()    { throw new Error('DOM not available in this environment'); },
        'set-pointer-capture!'()      { throw new Error('DOM not available in this environment'); },
        'toggle-attribute!'()         { throw new Error('DOM not available in this environment'); },
        'toggle-attribute'()          { throw new Error('DOM not available in this environment'); },
    },
    'xterm-terminal': {
        'create': (options => {
            const TerminalCtor = require_xterm_terminal();
            const opts = from_fasl(options);
            return opts === undefined ? new TerminalCtor() : new TerminalCtor(opts);
        }),
        'buffer': (term => get_xterm_terminal_property(term, 'buffer')),
        'cols': (term => get_xterm_terminal_property(term, 'cols')),
        'rows': (term => get_xterm_terminal_property(term, 'rows')),
        'element': (term => get_xterm_terminal_property(term, 'element')),
        'textarea': (term => get_xterm_terminal_property(term, 'textarea')),
        'markers':  (term => get_xterm_terminal_property(term, 'markers')),
        'modes':    (term => get_xterm_terminal_property(term, 'modes')),
        'options': (term => get_xterm_terminal_property(term, 'options')),
        'set-options!': ((term, options) => {
            const opts = from_fasl(options);
            if (opts !== undefined) {
                set_xterm_terminal_property(term, 'options', opts);
            }
        }),
        'parser': (term => get_xterm_terminal_property(term, 'parser')),
        'unicode': (term => get_xterm_terminal_property(term, 'unicode')),
        'on-bell': (term => get_xterm_terminal_property(term, 'onBell')),
        'on-binary': (term => get_xterm_terminal_property(term, 'onBinary')),
        'on-cursor-move': (term => get_xterm_terminal_property(term, 'onCursorMove')),
        'on-data': (term => get_xterm_terminal_property(term, 'onData')),
        'on-key': (term => get_xterm_terminal_property(term, 'onKey')),
        'on-line-feed': (term => get_xterm_terminal_property(term, 'onLineFeed')),
        'on-render': (term => get_xterm_terminal_property(term, 'onRender')),
        'on-resize': (term => get_xterm_terminal_property(term, 'onResize')),
        'on-scroll': (term => get_xterm_terminal_property(term, 'onScroll')),
        'on-selection-change': (term => get_xterm_terminal_property(term, 'onSelectionChange')),
        'on-title-change': (term => get_xterm_terminal_property(term, 'onTitleChange')),
        'on-write-parsed': (term => get_xterm_terminal_property(term, 'onWriteParsed')),
        'attach-custom-key-event-handler': ((term, handler) => {
            require_host_function(term,
                                  'attachCustomKeyEventHandler',
                                  'xterm.js Terminal.attachCustomKeyEventHandler')(handler);
        }),
        'attach-custom-wheel-event-handler': ((term, handler) => {
            require_host_function(term,
                                  'attachCustomWheelEventHandler',
                                  'xterm.js Terminal.attachCustomWheelEventHandler')(handler);
        }),
        'blur': (term => {
            require_host_function(term,
                                  'blur',
                                  'xterm.js Terminal.blur')();
        }),
        'focus': (term => {
            require_host_function(term,
                                  'focus',
                                  'xterm.js Terminal.focus')();
        }),
        'dispose': (term => {
            require_host_function(term,
                                  'dispose',
                                  'xterm.js Terminal.dispose')();
        }),
        'clear': (term => {
            require_host_function(term,
                                  'clear',
                                  'xterm.js Terminal.clear')();
        }),
        'clear-selection': (term => {
            require_host_function(term,
                                  'clearSelection',
                                  'xterm.js Terminal.clearSelection')();
        }),
        'clear-texture-atlas': (term => {
            require_host_function(term,
                                  'clearTextureAtlas',
                                  'xterm.js Terminal.clearTextureAtlas')();
        }),
        'deregister-character-joiner': ((term, joinerId) => {
            require_host_function(term,
                                  'deregisterCharacterJoiner',
                                  'xterm.js Terminal.deregisterCharacterJoiner')(joinerId);
        }),
        'get-selection': (term => require_host_function(term,
                                                        'getSelection',
                                                        'xterm.js Terminal.getSelection')()),
        'get-selection-position': (term => require_host_function(term,
                                                                 'getSelectionPosition',
                                                                 'xterm.js Terminal.getSelectionPosition')()),
        'has-selection': (term => require_host_function(term,
                                                        'hasSelection',
                                                        'xterm.js Terminal.hasSelection')() ? 1 : 0),
        'input': ((term, data, wasUserInput) => {
            const input = require_host_function(term,
                                                'input',
                                                'xterm.js Terminal.input');
            const d = from_fasl(data);
            const w = from_fasl(wasUserInput);
            if (w === undefined) {
                input(d);
            } else {
                input(d, w);
            }
        }),
        'load-addon': ((term, addon) => {
            require_host_function(term,
                                  'loadAddon',
                                  'xterm.js Terminal.loadAddon')(addon);
        }),
        'open': ((term, parent) => {
            require_host_function(term,
                                  'open',
                                  'xterm.js Terminal.open')(parent);
        }),
        'paste': ((term, data) => {
            require_host_function(term,
                                  'paste',
                                  'xterm.js Terminal.paste')(from_fasl(data));
        }),
        'refresh': ((term, start, end) => {
            require_host_function(term,
                                  'refresh',
                                  'xterm.js Terminal.refresh')(start, end);
        }),
        'register-character-joiner': ((term, handler) => require_host_function(term,
                                                                               'registerCharacterJoiner',
                                                                               'xterm.js Terminal.registerCharacterJoiner')(handler)),
        'register-decoration': ((term, options) => require_host_function(term,
                                                                         'registerDecoration',
                                                                         'xterm.js Terminal.registerDecoration')(options)),
        'register-link-provider': ((term, provider) => require_host_function(term,
                                                                             'registerLinkProvider',
                                                                             'xterm.js Terminal.registerLinkProvider')(provider)),
        'register-marker': ((term, cursorYOffset) => {
            const registerMarker = require_host_function(term,
                                                         'registerMarker',
                                                         'xterm.js Terminal.registerMarker');
            const offset = from_fasl(cursorYOffset);
            return offset === undefined ? registerMarker() : registerMarker(offset);
        }),
        'reset': (term => {
            require_host_function(term,
                                  'reset',
                                  'xterm.js Terminal.reset')();
        }),
        'resize': ((term, columns, rows) => {
            require_host_function(term,
                                  'resize',
                                  'xterm.js Terminal.resize')(columns, rows);
        }),
        'scroll-lines': ((term, amount) => {
            require_host_function(term,
                                  'scrollLines',
                                  'xterm.js Terminal.scrollLines')(amount);
        }),
        'scroll-pages': ((term, pageCount) => {
            require_host_function(term,
                                  'scrollPages',
                                  'xterm.js Terminal.scrollPages')(pageCount);
        }),
        'scroll-to-bottom': (term => {
            require_host_function(term,
                                  'scrollToBottom',
                                  'xterm.js Terminal.scrollToBottom')();
        }),
        'scroll-to-line': ((term, line) => {
            require_host_function(term,
                                  'scrollToLine',
                                  'xterm.js Terminal.scrollToLine')(line);
        }),
        'scroll-to-top': (term => {
            require_host_function(term,
                                  'scrollToTop',
                                  'xterm.js Terminal.scrollToTop')();
        }),
        'select': ((term, column, row, length) => {
            require_host_function(term,
                                  'select',
                                  'xterm.js Terminal.select')(column, row, length);
        }),
        'select-all': (term => {
            require_host_function(term,
                                  'selectAll',
                                  'xterm.js Terminal.selectAll')();
        }),
        'select-lines': ((term, start, end) => {
            require_host_function(term,
                                  'selectLines',
                                  'xterm.js Terminal.selectLines')(start, end);
        }),
        'write': ((term, data, callback) => {
            const write = require_host_function(term,
                                                'write',
                                                'xterm.js Terminal.write');
            const d = from_fasl(data);
            const cb = from_fasl(callback);
            if (cb === undefined) {
                write(d);
            } else {
                write(d, cb);
            }
        }),
        'writeln': ((term, data, callback) => {
            const writeln = require_host_function(term,
                                                  'writeln',
                                                  'xterm.js Terminal.writeln');
            const d = from_fasl(data);
            const cb = from_fasl(callback);
            if (cb === undefined) {
                writeln(d);
            } else {
                writeln(d, cb);
            }
        })
    },
    // Fit AddOn for xterm.js.
    'xterm-fit-addon': {
        'create':   (()                => {
            const FitAddonCtor = require_xterm_fit_addon();
            return new FitAddonCtor();
        }),
        'activate': ((addon, terminal) => {
            require_host_function(addon,
                                  'activate',
                                  'xterm.js FitAddon.activate')(terminal);
        }),
        'dispose':   (addon            => {
            require_host_function(addon,
                                  'dispose',
                                  'xterm.js FitAddon.dispose')();
        }),
        'fit':       (addon            => {
            require_host_function(addon,
                                  'fit',
                                  'xterm.js FitAddon.fit')();
        }),
        'propose-dimensions': (addon => {
            const dims = require_host_function(addon,
                                               'proposeDimensions',
                                               'xterm.js FitAddon.proposeDimensions')();
            if (dims === undefined || dims === null) {
                return to_fasl(undefined);
            }
            const colsPair = { tag: 'pair', car: Symbol.for('cols'), cdr: dims.cols };
            const rowsPair = { tag: 'pair', car: Symbol.for('rows'), cdr: dims.rows };
            const alist = {
                tag: 'pair',
                car: colsPair,
                cdr: { tag: 'pair', car: rowsPair, cdr: null }
            };
            return to_fasl(alist);
        })
    },
    // JSXGraph Board
    'jsx-board': hasDOM ? {
        'init-board':                ((containerId, attrs) => require_jsxgraph_api().initBoard(from_fasl(containerId), from_fasl(attrs))),
        'create':                    ((board, elementType, parents, attrs) => call_jsxgraph_board_create(board, from_fasl(elementType), parents, attrs)),
        'create-point':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'point', parents, attrs)),
        'create-line':               ((board, parents, attrs) => call_jsxgraph_board_create(board, 'line', parents, attrs)),
        'create-segment':            ((board, parents, attrs) => call_jsxgraph_board_create(board, 'segment', parents, attrs)),
        'create-arc':                ((board, parents, attrs) => call_jsxgraph_board_create(board, 'arc', parents, attrs)),
        'create-angle':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'angle', parents, attrs)),
        'create-sector':             ((board, parents, attrs) => call_jsxgraph_board_create(board, 'sector', parents, attrs)),
        'create-glider':             ((board, parents, attrs) => call_jsxgraph_board_create(board, 'glider', parents, attrs)),
        'create-circle':             ((board, parents, attrs) => call_jsxgraph_board_create(board, 'circle', parents, attrs)),
        'create-conic':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'conic', parents, attrs)),
        'create-ellipse':            ((board, parents, attrs) => call_jsxgraph_board_create(board, 'ellipse', parents, attrs)),
        'create-curve':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'curve', parents, attrs)),
        'create-functiongraph':      ((board, parents, attrs) => call_jsxgraph_board_create(board, 'functiongraph', parents, attrs)),
        'create-polygon':            ((board, parents, attrs) => call_jsxgraph_board_create(board, 'polygon', parents, attrs)),
        'create-midpoint':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'midpoint', parents, attrs)),
        'create-parallel':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'parallel', parents, attrs)),
        'create-arrowparallel':      ((board, parents, attrs) => call_jsxgraph_board_create(board, 'arrowparallel', parents, attrs)),
        'create-axis':               ((board, parents, attrs) => call_jsxgraph_board_create(board, 'axis', parents, attrs)),
        'create-grid':               ((board, parents, attrs) => call_jsxgraph_board_create(board, 'grid', parents, attrs)),
        'create-boxplot':            ((board, parents, attrs) => call_jsxgraph_board_create(board, 'boxplot', parents, attrs)),
        'create-tangent':            ((board, parents, attrs) => call_jsxgraph_board_create(board, 'tangent', parents, attrs)),
        'create-tangentto':          ((board, parents, attrs) => call_jsxgraph_board_create(board, 'tangentto', parents, attrs)),
        'create-polarline':          ((board, parents, attrs) => call_jsxgraph_board_create(board, 'polarline', parents, attrs)),
        'create-polepoint':          ((board, parents, attrs) => call_jsxgraph_board_create(board, 'polepoint', parents, attrs)),
        'create-radicalaxis':        ((board, parents, attrs) => call_jsxgraph_board_create(board, 'radicalaxis', parents, attrs)),
        'create-circumcircle':       ((board, parents, attrs) => call_jsxgraph_board_create(board, 'circumcircle', parents, attrs)),
        'create-incircle':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'incircle', parents, attrs)),
        'create-incenter':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'incenter', parents, attrs)),
        'create-minorarc':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'minorarc', parents, attrs)),
        'create-minorsector':        ((board, parents, attrs) => call_jsxgraph_board_create(board, 'minorsector', parents, attrs)),
        'create-circumcirclearc':    ((board, parents, attrs) => call_jsxgraph_board_create(board, 'circumcirclearc', parents, attrs)),
        'create-circumcirclesector': ((board, parents, attrs) => call_jsxgraph_board_create(board, 'circumcirclesector', parents, attrs)),
        'create-semicircle':         ((board, parents, attrs) => call_jsxgraph_board_create(board, 'semicircle', parents, attrs)),
        'create-majorarc':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'majorarc', parents, attrs)),
        'create-majorsector':        ((board, parents, attrs) => call_jsxgraph_board_create(board, 'majorsector', parents, attrs)),
        'create-curveintersection':  ((board, parents, attrs) => call_jsxgraph_board_create(board, 'curveintersection', parents, attrs)),
        'create-curvedifference':    ((board, parents, attrs) => call_jsxgraph_board_create(board, 'curvedifference', parents, attrs)),
        'create-curveunion':         ((board, parents, attrs) => call_jsxgraph_board_create(board, 'curveunion', parents, attrs)),
        'create-derivative':         ((board, parents, attrs) => call_jsxgraph_board_create(board, 'derivative', parents, attrs)),
        'create-integral':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'integral', parents, attrs)),
        'create-riemannsum':         ((board, parents, attrs) => call_jsxgraph_board_create(board, 'riemannsum', parents, attrs)),
        'create-slopefield':         ((board, parents, attrs) => call_jsxgraph_board_create(board, 'slopefield', parents, attrs)),
        'create-vectorfield':        ((board, parents, attrs) => call_jsxgraph_board_create(board, 'vectorfield', parents, attrs)),
        'create-implicitcurve':      ((board, parents, attrs) => call_jsxgraph_board_create(board, 'implicitcurve', parents, attrs)),
        'create-spline':             ((board, parents, attrs) => call_jsxgraph_board_create(board, 'spline', parents, attrs)),
        'create-cardinalspline':     ((board, parents, attrs) => call_jsxgraph_board_create(board, 'cardinalspline', parents, attrs)),
        'create-comb':               ((board, parents, attrs) => call_jsxgraph_board_create(board, 'comb', parents, attrs)),
        'create-metapostspline':     ((board, parents, attrs) => call_jsxgraph_board_create(board, 'metapostspline', parents, attrs)),
        'create-polygonalchain':     ((board, parents, attrs) => call_jsxgraph_board_create(board, 'polygonalchain', parents, attrs)),
        'create-regularpolygon':     ((board, parents, attrs) => call_jsxgraph_board_create(board, 'regularpolygon', parents, attrs)),
        'create-hyperbola':          ((board, parents, attrs) => call_jsxgraph_board_create(board, 'hyperbola', parents, attrs)),
        'create-parabola':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'parabola', parents, attrs)),
        'create-stepfunction':       ((board, parents, attrs) => call_jsxgraph_board_create(board, 'stepfunction', parents, attrs)),
        'create-inequality':         ((board, parents, attrs) => call_jsxgraph_board_create(board, 'inequality', parents, attrs)),
        'create-turtle':             ((board, parents, attrs) => call_jsxgraph_board_create(board, 'turtle', parents, attrs)),
        'create-nonreflexangle':     ((board, parents, attrs) => call_jsxgraph_board_create(board, 'nonreflexangle', parents, attrs)),
        'create-perpendicular':      ((board, parents, attrs) => call_jsxgraph_board_create(board, 'perpendicular', parents, attrs)),
        'create-reflection':         ((board, parents, attrs) => call_jsxgraph_board_create(board, 'reflection', parents, attrs)),
        'create-bisector':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'bisector', parents, attrs)),
        'create-normal':             ((board, parents, attrs) => call_jsxgraph_board_create(board, 'normal', parents, attrs)),
        'create-intersection':       ((board, parents, attrs) => call_jsxgraph_board_create(board, 'intersection', parents, attrs)),
        'create-arrow':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'arrow', parents, attrs)),
        'create-button':             ((board, parents, attrs) => call_jsxgraph_board_create(board, 'button', parents, attrs)),
        'create-checkbox':           ((board, parents, attrs) => call_jsxgraph_board_create(board, 'checkbox', parents, attrs)),
        'create-input':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'input', parents, attrs)),
        'create-slider':             ((board, parents, attrs) => call_jsxgraph_board_create(board, 'slider', parents, attrs)),
        'create-chart':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'chart', parents, attrs)),
        'create-legend':             ((board, parents, attrs) => call_jsxgraph_board_create(board, 'legend', parents, attrs)),
        'create-smartlabel':         ((board, parents, attrs) => call_jsxgraph_board_create(board, 'smartlabel', parents, attrs)),
        'create-foreignobject':      ((board, parents, attrs) => call_jsxgraph_board_create(board, 'foreignobject', parents, attrs)),
        'create-tapemeasure':        ((board, parents, attrs) => call_jsxgraph_board_create(board, 'tapemeasure', parents, attrs)),
        'create-ticks':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'ticks', parents, attrs)),
        'create-hatch':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'hatch', parents, attrs)),
        'create-transformation':     ((board, parents, attrs) => call_jsxgraph_board_create(board, 'transform', parents, attrs)),
        'create-tracecurve':         ((board, parents, attrs) => call_jsxgraph_board_create(board, 'tracecurve', parents, attrs)),
        'create-slopetriangle':      ((board, parents, attrs) => call_jsxgraph_board_create(board, 'slopetriangle', parents, attrs)),
        'create-parallelogram':      ((board, parents, attrs) => call_jsxgraph_board_create(board, 'parallelogram', parents, attrs)),
        'create-reflexangle':        ((board, parents, attrs) => call_jsxgraph_board_create(board, 'reflexangle', parents, attrs)),
        'create-measurement':        ((board, parents, attrs) => call_jsxgraph_board_create(board, 'measurement', parents, attrs)),
        'create-circumcenter':       ((board, parents, attrs) => call_jsxgraph_board_create(board, 'circumcenter', parents, attrs)),
        'create-mirrorelement':      ((board, parents, attrs) => call_jsxgraph_board_create(board, 'mirrorelement', parents, attrs)),
        'create-text':               ((board, parents, attrs) => call_jsxgraph_board_create(board, 'text', parents, attrs)),
        'create-image':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'image', parents, attrs)),
        'create-group':              ((board, parents, attrs) => call_jsxgraph_board_create(board, 'group', parents, attrs)),
        'create-bisectorlines':      ((board, parents, attrs) => call_jsxgraph_board_create(board, 'bisectorlines', parents, attrs)),
        'create-perpendicularsegment': ((board, parents, attrs) => call_jsxgraph_board_create(board, 'perpendicularsegment', parents, attrs)),
        'add-grid!':                 (board => { call_jsxgraph_board_method(board, 'addGrid'); }),
        'remove-grids!':             (board => { call_jsxgraph_board_method(board, 'removeGrids'); }),
        'add-animation!':            ((board, element) => { call_jsxgraph_board_method(board, 'addAnimation', [from_fasl(element)]); }),
        'add-conditions!':           ((board, str) => { call_jsxgraph_board_method(board, 'addConditions', [from_fasl(str)]); }),
        'add-event-handlers!':       (board => { call_jsxgraph_board_method(board, 'addEventHandlers'); }),
        'add-fullscreen-event-handlers!': (board => { call_jsxgraph_board_method(board, 'addFullscreenEventHandlers'); }),
        'add-hook!':                 ((board, hook, m, context) => call_jsxgraph_board_method(board, 'addHook', [hook, from_fasl(m), from_fasl(context)])),
        'add-keyboard-event-handlers!': (board => { call_jsxgraph_board_method(board, 'addKeyboardEventHandlers'); }),
        'add-mouse-event-handlers!': (board => { call_jsxgraph_board_method(board, 'addMouseEventHandlers'); }),
        'add-pointer-event-handlers!': (board => { call_jsxgraph_board_method(board, 'addPointerEventHandlers'); }),
        'add-resize-event-handlers!': (board => { call_jsxgraph_board_method(board, 'addResizeEventHandlers'); }),
        'add-touch-event-handlers!': ((board, appleGestures) => { call_jsxgraph_board_method(board, 'addTouchEventHandlers', [from_fasl(appleGestures)]); }),
        'add-wheel-event-handlers!': (board => { call_jsxgraph_board_method(board, 'addWheelEventHandlers'); }),
        'add-child!':               ((board, child) => { call_jsxgraph_board_method(board, 'addChild', [from_fasl(child)]); }),
        'apply-zoom!':              (board => { call_jsxgraph_board_method(board, 'applyZoom'); }),
        'calculate-snap-sizes!':    (board => { call_jsxgraph_board_method(board, 'calculateSnapSizes'); }),
        'clear-traces!':            (board => { call_jsxgraph_board_method(board, 'clearTraces'); }),
        'create-roulette!':         ((board, c1, c2, startC1, stepsize, direction, time, pointlist) =>
                                      call_jsxgraph_board_method(board, 'createRoulette',
                                                                 [from_fasl(c1), from_fasl(c2), from_fasl(startC1),
                                                                  from_fasl(stepsize), from_fasl(direction),
                                                                  from_fasl(time), from_fasl(pointlist)])),
        'dehighlight-all!':         (board => { call_jsxgraph_board_method(board, 'dehighlightAll'); }),
        'finalize-adding!':         ((board, obj) => { call_jsxgraph_board_method(board, 'finalizeAdding', [from_fasl(obj)]); }),
        'generate-id':              (board => call_jsxgraph_board_method(board, 'generateId')),
        'generate-name':            ((board, object) => call_jsxgraph_board_method(board, 'generateName', [from_fasl(object)])),
        'get-all-objects-under-mouse': ((board, evt) => call_jsxgraph_board_method(board, 'getAllObjectsUnderMouse', [from_fasl(evt)])),
        'get-all-under-mouse':      ((board, evt) => call_jsxgraph_board_method(board, 'getAllUnderMouse', [from_fasl(evt)])),
        'get-bounding-box':         (board => call_jsxgraph_board_method(board, 'getBoundingBox')),
        'get-coords-top-left-corner': (board => call_jsxgraph_board_method(board, 'getCoordsTopLeftCorner')),
        'get-mouse-position':       ((board, evt) => call_jsxgraph_board_method(board, 'getMousePosition', [from_fasl(evt)])),
        'get-mouse-position/index':  ((board, evt, i) => call_jsxgraph_board_method(board, 'getMousePosition', [from_fasl(evt), from_fasl(i)])),
        'get-scr-coords-of-mouse':  ((board, x, y) => call_jsxgraph_board_method(board, 'getScrCoordsOfMouse', [from_fasl(x), from_fasl(y)])),
        'get-usr-coords-of-mouse':  ((board, evt) => call_jsxgraph_board_method(board, 'getUsrCoordsOfMouse', [from_fasl(evt)])),
        'has-point!':               ((board, x, y) => call_jsxgraph_board_method(board, 'hasPoint', [from_fasl(x), from_fasl(y)])),
        'highlight-custom-infobox!': ((board, text) => { call_jsxgraph_board_method(board, 'highlightCustomInfobox', [from_fasl(text)]); }),
        'highlight-custom-infobox/element!': ((board, text, el) => { call_jsxgraph_board_method(board, 'highlightCustomInfobox', [from_fasl(text), from_fasl(el)]); }),
        'highlight-infobox!':       ((board, x, y) => { call_jsxgraph_board_method(board, 'highlightInfobox', [from_fasl(x), from_fasl(y)]); }),
        'highlight-infobox/element!': ((board, x, y, el) => { call_jsxgraph_board_method(board, 'highlightInfobox', [from_fasl(x), from_fasl(y), from_fasl(el)]); }),
        'init-geonext-board!':      (board => { call_jsxgraph_board_method(board, 'initGeonextBoard'); }),
        'init-infobox!':            ((board, attributes) => { call_jsxgraph_board_method(board, 'initInfobox', [from_fasl(attributes)]); }),
        'init-move-object!':        ((board, x, y, evt, type) => { call_jsxgraph_board_method(board, 'initMoveObject', [from_fasl(x), from_fasl(y), from_fasl(evt), from_fasl(type)]); }),
        'init-move-origin!':        ((board, x, y) => { call_jsxgraph_board_method(board, 'initMoveOrigin', [from_fasl(x), from_fasl(y)]); }),
        'move-object!':             ((board, x, y, o, evt, type) => { call_jsxgraph_board_method(board, 'moveObject', [from_fasl(x), from_fasl(y), from_fasl(o), from_fasl(evt), from_fasl(type)]); }),
        'move-origin!':             ((board, x, y, diff) => { call_jsxgraph_board_method(board, 'moveOrigin', [from_fasl(x), from_fasl(y), from_fasl(diff)]); }),
        'off':                      ((board, event, handler) => { call_jsxgraph_board_method(board, 'off', [from_fasl(event), from_fasl(handler)]); }),
        'on':                       ((board, event, handler) => { call_jsxgraph_board_method(board, 'on', [from_fasl(event), from_fasl(handler)]); }),
        'remove-event-handlers!':   (board => { call_jsxgraph_board_method(board, 'removeEventHandlers'); }),
        'remove-hook!':             ((board, id) => { call_jsxgraph_board_method(board, 'removeHook', [from_fasl(id)]); }),
        'remove-keyboard-event-handlers!': (board => { call_jsxgraph_board_method(board, 'removeKeyboardEventHandlers'); }),
        'remove-mouse-event-handlers!': (board => { call_jsxgraph_board_method(board, 'removeMouseEventHandlers'); }),
        'remove-pointer-event-handlers!': (board => { call_jsxgraph_board_method(board, 'removePointerEventHandlers'); }),
        'remove-resize-event-handlers!': (board => { call_jsxgraph_board_method(board, 'removeResizeEventHandlers'); }),
        'remove-touch-event-handlers!': (board => { call_jsxgraph_board_method(board, 'removeTouchEventHandlers'); }),
        'resize-container!':        ((board, width, height, dontset, dontSetBoundingBox) =>
                                      { call_jsxgraph_board_method(board, 'resizeContainer', [from_fasl(width), from_fasl(height), from_fasl(dontset), from_fasl(dontSetBoundingBox)]); }),
        'select':                   ((board, str, onlyByIdOrName) => call_jsxgraph_board_method(board, 'select', [from_fasl(str), from_fasl(onlyByIdOrName)])),
        'set-attribute!':           ((board, attributes) => { call_jsxgraph_board_method(board, 'setAttribute', [from_fasl(attributes)]); }),
        'set-bounding-box!':        ((board, bbox, keepaspectratio, setZoom) => { call_jsxgraph_board_method(board, 'setBoundingBox', [from_fasl(bbox), from_fasl(keepaspectratio), from_fasl(setZoom)]); }),
        'set-id!':                  ((board, obj, type) => { call_jsxgraph_board_method(board, 'setId', [from_fasl(obj), from_fasl(type)]); }),
        'set-zoom!':                ((board, fX, fY) => { call_jsxgraph_board_method(board, 'setZoom', [from_fasl(fX), from_fasl(fY)]); }),
        'show-dependencies!':       (board => { call_jsxgraph_board_method(board, 'showDependencies'); }),
        'show-xml!':                (board => { call_jsxgraph_board_method(board, 'showXML'); }),
        'start-intersection-observer!': (board => { call_jsxgraph_board_method(board, 'startIntersectionObserver'); }),
        'start-resize-observer!':   (board => { call_jsxgraph_board_method(board, 'startResizeObserver'); }),
        'start-selection-mode!':    (board => { call_jsxgraph_board_method(board, 'startSelectionMode'); }),
        'stop-all-animation!':      (board => { call_jsxgraph_board_method(board, 'stopAllAnimation'); }),
        'stop-intersection-observer!': (board => { call_jsxgraph_board_method(board, 'stopIntersectionObserver'); }),
        'stop-resize-observer!':    (board => { call_jsxgraph_board_method(board, 'stopResizeObserver'); }),
        'stop-selection-mode!':     (board => { call_jsxgraph_board_method(board, 'stopSelectionMode'); }),
        'suppress-default!':        ((board, e) => { call_jsxgraph_board_method(board, 'suppressDefault', [from_fasl(e)]); }),
        'to-fullscreen!':           ((board, id) => { call_jsxgraph_board_method(board, 'toFullscreen', [from_fasl(id)]); }),
        'update-conditions!':       (board => { call_jsxgraph_board_method(board, 'updateConditions'); }),
        'update-container-dims!':   (board => { call_jsxgraph_board_method(board, 'updateContainerDims'); }),
        'update-container-dims/size!': ((board, width, height) => { call_jsxgraph_board_method(board, 'updateContainerDims', [from_fasl(width), from_fasl(height)]); }),
        'update-coords!':           (board => { call_jsxgraph_board_method(board, 'updateCoords'); }),
        'update-csstransforms!':    (board => { call_jsxgraph_board_method(board, 'updateCSSTransforms'); }),
        'update-elements!':         ((board, drag) => { call_jsxgraph_board_method(board, 'updateElements', [from_fasl(drag)]); }),
        'update-hooks!':            ((board, m) => { call_jsxgraph_board_method(board, 'updateHooks', [from_fasl(m)]); }),
        'update-infobox!':          ((board, el) => { call_jsxgraph_board_method(board, 'updateInfobox', [from_fasl(el)]); }),
        'update-renderer!':         (board => { call_jsxgraph_board_method(board, 'updateRenderer'); }),
        'update-renderer-canvas!':  (board => { call_jsxgraph_board_method(board, 'updateRendererCanvas'); }),
        'zoom-all-points!':         (board => { call_jsxgraph_board_method(board, 'zoomAllPoints'); }),
        'zoom-elements!':           ((board, elements) => { call_jsxgraph_board_method(board, 'zoomElements', [from_fasl(elements)]); }),
        'zoom-in!':                 ((board, x, y) => { call_jsxgraph_board_method(board, 'zoomIn', [from_fasl(x), from_fasl(y)]); }),
        'zoom-out!':                ((board, x, y) => { call_jsxgraph_board_method(board, 'zoomOut', [from_fasl(x), from_fasl(y)]); }),
        'zoom100!':                 (board => { call_jsxgraph_board_method(board, 'zoom100'); }),
        'id':                        (board => get_jsxgraph_board_property(board, 'id')),
        'container':                 (board => get_jsxgraph_board_property(board, 'container')),
        'renderer':                  (board => get_jsxgraph_board_property(board, 'renderer')),
        'canvas-width':              (board => get_jsxgraph_board_property(board, 'canvasWidth')),
        'canvas-height':             (board => get_jsxgraph_board_property(board, 'canvasHeight')),
        'bounding-box':              (board => get_jsxgraph_board_property(board, 'boundingBox')),
        'update!':                   (board => call_jsxgraph_board_method(board, 'update')),
        'full-update!':              (board => call_jsxgraph_board_method(board, 'fullUpdate')),
        'remove-object!':            ((board, obj) => { call_jsxgraph_board_method(board, 'removeObject', [obj]); }),
        'suspend-update!':           (board => call_jsxgraph_board_method(board, 'suspendUpdate')),
        'unsuspend-update!':         (board => call_jsxgraph_board_method(board, 'unsuspendUpdate')),
        'num-objects':               (board => get_jsxgraph_board_property(board, 'numObjects')),
        'objects-list':              (board => Object.values(get_jsxgraph_board_property(board, 'objects')))
    } : {
        'init-board'()                { throw new Error('DOM not available in this environment'); },
        'create'()                    { throw new Error('DOM not available in this environment'); },
        'create-point'()              { throw new Error('DOM not available in this environment'); },
        'create-line'()               { throw new Error('DOM not available in this environment'); },
        'create-segment'()            { throw new Error('DOM not available in this environment'); },
        'create-arc'()                { throw new Error('DOM not available in this environment'); },
        'create-angle'()              { throw new Error('DOM not available in this environment'); },
        'create-sector'()             { throw new Error('DOM not available in this environment'); },
        'create-glider'()             { throw new Error('DOM not available in this environment'); },
        'create-circle'()             { throw new Error('DOM not available in this environment'); },
        'create-conic'()              { throw new Error('DOM not available in this environment'); },
        'create-ellipse'()            { throw new Error('DOM not available in this environment'); },
        'create-curve'()              { throw new Error('DOM not available in this environment'); },
        'create-functiongraph'()      { throw new Error('DOM not available in this environment'); },
        'create-polygon'()            { throw new Error('DOM not available in this environment'); },
        'create-midpoint'()           { throw new Error('DOM not available in this environment'); },
        'create-parallel'()           { throw new Error('DOM not available in this environment'); },
        'create-arrowparallel'()      { throw new Error('DOM not available in this environment'); },
        'create-axis'()               { throw new Error('DOM not available in this environment'); },
        'create-grid'()               { throw new Error('DOM not available in this environment'); },
        'create-boxplot'()            { throw new Error('DOM not available in this environment'); },
        'create-tangent'()            { throw new Error('DOM not available in this environment'); },
        'create-tangentto'()          { throw new Error('DOM not available in this environment'); },
        'create-polarline'()          { throw new Error('DOM not available in this environment'); },
        'create-polepoint'()          { throw new Error('DOM not available in this environment'); },
        'create-radicalaxis'()        { throw new Error('DOM not available in this environment'); },
        'create-circumcircle'()       { throw new Error('DOM not available in this environment'); },
        'create-incircle'()           { throw new Error('DOM not available in this environment'); },
        'create-incenter'()           { throw new Error('DOM not available in this environment'); },
        'create-minorarc'()           { throw new Error('DOM not available in this environment'); },
        'create-minorsector'()        { throw new Error('DOM not available in this environment'); },
        'create-circumcirclearc'()    { throw new Error('DOM not available in this environment'); },
        'create-circumcirclesector'() { throw new Error('DOM not available in this environment'); },
        'create-semicircle'()         { throw new Error('DOM not available in this environment'); },
        'create-majorarc'()           { throw new Error('DOM not available in this environment'); },
        'create-majorsector'()        { throw new Error('DOM not available in this environment'); },
        'create-perpendicular'()      { throw new Error('DOM not available in this environment'); },
        'create-reflection'()         { throw new Error('DOM not available in this environment'); },
        'create-bisector'()           { throw new Error('DOM not available in this environment'); },
        'create-normal'()             { throw new Error('DOM not available in this environment'); },
        'create-intersection'()       { throw new Error('DOM not available in this environment'); },
        'create-arrow'()              { throw new Error('DOM not available in this environment'); },
        'create-button'()             { throw new Error('DOM not available in this environment'); },
        'create-checkbox'()           { throw new Error('DOM not available in this environment'); },
        'create-input'()              { throw new Error('DOM not available in this environment'); },
        'create-slider'()             { throw new Error('DOM not available in this environment'); },
        'create-chart'()              { throw new Error('DOM not available in this environment'); },
        'create-legend'()             { throw new Error('DOM not available in this environment'); },
        'create-smartlabel'()         { throw new Error('DOM not available in this environment'); },
        'create-foreignobject'()      { throw new Error('DOM not available in this environment'); },
        'create-tapemeasure'()        { throw new Error('DOM not available in this environment'); },
        'create-ticks'()              { throw new Error('DOM not available in this environment'); },
        'create-hatch'()              { throw new Error('DOM not available in this environment'); },
        'create-transformation'()     { throw new Error('DOM not available in this environment'); },
        'create-tracecurve'()         { throw new Error('DOM not available in this environment'); },
        'create-slopetriangle'()      { throw new Error('DOM not available in this environment'); },
        'create-parallelogram'()      { throw new Error('DOM not available in this environment'); },
        'create-reflexangle'()        { throw new Error('DOM not available in this environment'); },
        'create-nonreflexangle'()     { throw new Error('DOM not available in this environment'); },
        'create-measurement'()        { throw new Error('DOM not available in this environment'); },
        'create-circumcenter'()       { throw new Error('DOM not available in this environment'); },
        'create-mirrorelement'()      { throw new Error('DOM not available in this environment'); },
        'create-text'()               { throw new Error('DOM not available in this environment'); },
        'create-image'()              { throw new Error('DOM not available in this environment'); },
        'create-group'()              { throw new Error('DOM not available in this environment'); },
        'create-bisectorlines'()      { throw new Error('DOM not available in this environment'); },
        'create-perpendicularsegment'() { throw new Error('DOM not available in this environment'); },
        'add-grid!'()                 { throw new Error('DOM not available in this environment'); },
        'remove-grids!'()             { throw new Error('DOM not available in this environment'); },
        'add-animation!'()            { throw new Error('DOM not available in this environment'); },
        'add-conditions!'()           { throw new Error('DOM not available in this environment'); },
        'add-event-handlers!'()       { throw new Error('DOM not available in this environment'); },
        'add-fullscreen-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'add-hook!'()                 { throw new Error('DOM not available in this environment'); },
        'add-keyboard-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'add-mouse-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'add-pointer-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'add-resize-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'add-touch-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'add-wheel-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'add-child!'()               { throw new Error('DOM not available in this environment'); },
        'apply-zoom!'()               { throw new Error('DOM not available in this environment'); },
        'calculate-snap-sizes!'()     { throw new Error('DOM not available in this environment'); },
        'clear-traces!'()             { throw new Error('DOM not available in this environment'); },
        'create-roulette!'()          { throw new Error('DOM not available in this environment'); },
        'dehighlight-all!'()          { throw new Error('DOM not available in this environment'); },
        'finalize-adding!'()          { throw new Error('DOM not available in this environment'); },
        'generate-id'()               { throw new Error('DOM not available in this environment'); },
        'generate-name'()             { throw new Error('DOM not available in this environment'); },
        'get-all-objects-under-mouse'() { throw new Error('DOM not available in this environment'); },
        'get-all-under-mouse'()       { throw new Error('DOM not available in this environment'); },
        'get-bounding-box'()          { throw new Error('DOM not available in this environment'); },
        'get-coords-top-left-corner'() { throw new Error('DOM not available in this environment'); },
        'get-mouse-position'()        { throw new Error('DOM not available in this environment'); },
        'get-mouse-position/index'()  { throw new Error('DOM not available in this environment'); },
        'get-scr-coords-of-mouse'()   { throw new Error('DOM not available in this environment'); },
        'get-usr-coords-of-mouse'()   { throw new Error('DOM not available in this environment'); },
        'has-point!'()                { throw new Error('DOM not available in this environment'); },
        'highlight-custom-infobox!'()  { throw new Error('DOM not available in this environment'); },
        'highlight-custom-infobox/element!'() { throw new Error('DOM not available in this environment'); },
        'highlight-infobox!'()         { throw new Error('DOM not available in this environment'); },
        'highlight-infobox/element!'() { throw new Error('DOM not available in this environment'); },
        'init-geonext-board!'()        { throw new Error('DOM not available in this environment'); },
        'init-infobox!'()              { throw new Error('DOM not available in this environment'); },
        'init-move-object!'()          { throw new Error('DOM not available in this environment'); },
        'init-move-origin!'()          { throw new Error('DOM not available in this environment'); },
        'move-object!'()              { throw new Error('DOM not available in this environment'); },
        'move-origin!'()              { throw new Error('DOM not available in this environment'); },
        'off'()                       { throw new Error('DOM not available in this environment'); },
        'on'()                        { throw new Error('DOM not available in this environment'); },
        'remove-event-handlers!'()    { throw new Error('DOM not available in this environment'); },
        'remove-hook!'()              { throw new Error('DOM not available in this environment'); },
        'remove-keyboard-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'remove-mouse-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'remove-pointer-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'remove-resize-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'remove-touch-event-handlers!'() { throw new Error('DOM not available in this environment'); },
        'resize-container!'()         { throw new Error('DOM not available in this environment'); },
        'select'()                    { throw new Error('DOM not available in this environment'); },
        'set-attribute!'()            { throw new Error('DOM not available in this environment'); },
        'set-bounding-box!'()         { throw new Error('DOM not available in this environment'); },
        'set-id!'()                   { throw new Error('DOM not available in this environment'); },
        'set-zoom!'()                 { throw new Error('DOM not available in this environment'); },
        'show-dependencies!'()        { throw new Error('DOM not available in this environment'); },
        'show-xml!'()                 { throw new Error('DOM not available in this environment'); },
        'start-intersection-observer!'() { throw new Error('DOM not available in this environment'); },
        'start-resize-observer!'()    { throw new Error('DOM not available in this environment'); },
        'start-selection-mode!'()     { throw new Error('DOM not available in this environment'); },
        'stop-all-animation!'()       { throw new Error('DOM not available in this environment'); },
        'stop-intersection-observer!'() { throw new Error('DOM not available in this environment'); },
        'stop-resize-observer!'()     { throw new Error('DOM not available in this environment'); },
        'stop-selection-mode!'()      { throw new Error('DOM not available in this environment'); },
        'suppress-default!'()         { throw new Error('DOM not available in this environment'); },
        'to-fullscreen!'()            { throw new Error('DOM not available in this environment'); },
        'update-conditions!'()        { throw new Error('DOM not available in this environment'); },
        'update-container-dims!'()    { throw new Error('DOM not available in this environment'); },
        'update-container-dims/size!'() { throw new Error('DOM not available in this environment'); },
        'update-coords!'()            { throw new Error('DOM not available in this environment'); },
        'update-csstransforms!'()     { throw new Error('DOM not available in this environment'); },
        'update-elements!'()          { throw new Error('DOM not available in this environment'); },
        'update-hooks!'()             { throw new Error('DOM not available in this environment'); },
        'update-infobox!'()           { throw new Error('DOM not available in this environment'); },
        'update-renderer!'()          { throw new Error('DOM not available in this environment'); },
        'update-renderer-canvas!'()   { throw new Error('DOM not available in this environment'); },
        'zoom-all-points!'()          { throw new Error('DOM not available in this environment'); },
        'zoom-elements!'()            { throw new Error('DOM not available in this environment'); },
        'zoom-in!'()                  { throw new Error('DOM not available in this environment'); },
        'zoom-out!'()                 { throw new Error('DOM not available in this environment'); },
        'zoom100!'()                  { throw new Error('DOM not available in this environment'); },
        'update!'()                   { throw new Error('DOM not available in this environment'); },
        'full-update!'()              { throw new Error('DOM not available in this environment'); },
        'remove-object!'()            { throw new Error('DOM not available in this environment'); },
        'suspend-update!'()           { throw new Error('DOM not available in this environment'); },
        'unsuspend-update!'()         { throw new Error('DOM not available in this environment'); },
        'id'()                        { throw new Error('DOM not available in this environment'); },
        'container'()                 { throw new Error('DOM not available in this environment'); },
        'renderer'()                  { throw new Error('DOM not available in this environment'); },
        'canvas-width'()              { throw new Error('DOM not available in this environment'); },
        'canvas-height'()             { throw new Error('DOM not available in this environment'); },
        'bounding-box'()              { throw new Error('DOM not available in this environment'); },
        'num-objects'()               { throw new Error('DOM not available in this environment'); },
        'objects-list'()              { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph GeometryElement
    'jsx-element': hasDOM ? {
        'call': ((element, method, args) => call_js_method(element, method, args, 'jsx-element.call')),
        'call/nullish': ((element, method, args) => { call_js_method(element, method, args, 'jsx-element.call/nullish'); }),
        'add-event': ((element, type, listener) => call_jsxgraph_method(element, 'GeometryElement', 'addEvent', [from_fasl(type), listener]))
    } : {
        'call'()                      { throw new Error('DOM not available in this environment'); },
        'call/nullish'()              { throw new Error('DOM not available in this environment'); },
        'add-event'()                 { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Text
    'jsx-text': hasDOM ? {
        '_createFctUpdateText': ((text, args) => call_jsxgraph_method(text, 'Text', '_createFctUpdateText', from_fasl(args))),
        '_setText':              ((text, args) => call_jsxgraph_method(text, 'Text', '_setText', from_fasl(args))),
        'bounds':                ((text, args) => call_jsxgraph_method(text, 'Text', 'bounds', from_fasl(args))),
        'checkForSizeUpdate':    ((text, args) => call_jsxgraph_method(text, 'Text', 'checkForSizeUpdate', from_fasl(args))),
        'convertGeonext2CSS':    ((text, args) => call_jsxgraph_method(text, 'Text', 'convertGeonext2CSS', from_fasl(args))),
        'convertGeonextAndSketchometry2CSS': ((text, args) => call_jsxgraph_method(text, 'Text', 'convertGeonextAndSketchometry2CSS', from_fasl(args))),
        'convertSketchometry2CSS': ((text, args) => call_jsxgraph_method(text, 'Text', 'convertSketchometry2CSS', from_fasl(args))),
        'crudeSizeEstimate':     ((text, args) => call_jsxgraph_method(text, 'Text', 'crudeSizeEstimate', from_fasl(args))),
        'escapeTicks':           ((text, args) => call_jsxgraph_method(text, 'Text', 'escapeTicks', from_fasl(args))),
        'expandShortMath':       ((text, args) => call_jsxgraph_method(text, 'Text', 'expandShortMath', from_fasl(args))),
        'generateTerm':          ((text, args) => call_jsxgraph_method(text, 'Text', 'generateTerm', from_fasl(args))),
        'getAnchorX':            ((text, args) => call_jsxgraph_method(text, 'Text', 'getAnchorX', from_fasl(args))),
        'getAnchorY':            ((text, args) => call_jsxgraph_method(text, 'Text', 'getAnchorY', from_fasl(args))),
        'getNumberOfConflicts':  ((text, args) => call_jsxgraph_method(text, 'Text', 'getNumberOfConflicts', from_fasl(args))),
        'getSize':               ((text, args) => call_jsxgraph_method(text, 'Text', 'getSize', from_fasl(args))),
        'hasPoint':              ((text, args) => call_jsxgraph_method(text, 'Text', 'hasPoint', from_fasl(args))),
        'notifyParents':         ((text, args) => call_jsxgraph_method(text, 'Text', 'notifyParents', from_fasl(args))),
        'poorMansTeX':           ((text, args) => call_jsxgraph_method(text, 'Text', 'poorMansTeX', from_fasl(args))),
        'replaceSub':            ((text, args) => call_jsxgraph_method(text, 'Text', 'replaceSub', from_fasl(args))),
        'replaceSup':            ((text, args) => call_jsxgraph_method(text, 'Text', 'replaceSup', from_fasl(args))),
        'setAutoPosition':       ((text, args) => call_jsxgraph_method(text, 'Text', 'setAutoPosition', from_fasl(args))),
        'setCoords':             ((text, args) => call_jsxgraph_method(text, 'Text', 'setCoords', from_fasl(args))),
        'setText':               ((text, args) => call_jsxgraph_method(text, 'Text', 'setText', from_fasl(args))),
        'setTextJessieCode':     ((text, args) => call_jsxgraph_method(text, 'Text', 'setTextJessieCode', from_fasl(args))),
        'unescapeTicks':         ((text, args) => call_jsxgraph_method(text, 'Text', 'unescapeTicks', from_fasl(args))),
        'updateSize':            ((text, args) => call_jsxgraph_method(text, 'Text', 'updateSize', from_fasl(args))),
        'updateText':            ((text, args) => call_jsxgraph_method(text, 'Text', 'updateText', from_fasl(args))),
        'utf8_decode':           ((text, args) => call_jsxgraph_method(text, 'Text', 'utf8_decode', from_fasl(args))),
        'valueTagToJessieCode':  ((text, args) => call_jsxgraph_method(text, 'Text', 'valueTagToJessieCode', from_fasl(args)))
    } : {
        '_createFctUpdateText'()     { throw new Error('DOM not available in this environment'); },
        '_setText'()                 { throw new Error('DOM not available in this environment'); },
        'bounds'()                   { throw new Error('DOM not available in this environment'); },
        'checkForSizeUpdate'()       { throw new Error('DOM not available in this environment'); },
        'convertGeonext2CSS'()       { throw new Error('DOM not available in this environment'); },
        'convertGeonextAndSketchometry2CSS'() { throw new Error('DOM not available in this environment'); },
        'convertSketchometry2CSS'()   { throw new Error('DOM not available in this environment'); },
        'crudeSizeEstimate'()        { throw new Error('DOM not available in this environment'); },
        'escapeTicks'()              { throw new Error('DOM not available in this environment'); },
        'expandShortMath'()          { throw new Error('DOM not available in this environment'); },
        'generateTerm'()             { throw new Error('DOM not available in this environment'); },
        'getAnchorX'()               { throw new Error('DOM not available in this environment'); },
        'getAnchorY'()               { throw new Error('DOM not available in this environment'); },
        'getNumberOfConflicts'()     { throw new Error('DOM not available in this environment'); },
        'getSize'()                  { throw new Error('DOM not available in this environment'); },
        'hasPoint'()                 { throw new Error('DOM not available in this environment'); },
        'notifyParents'()            { throw new Error('DOM not available in this environment'); },
        'poorMansTeX'()              { throw new Error('DOM not available in this environment'); },
        'replaceSub'()               { throw new Error('DOM not available in this environment'); },
        'replaceSup'()               { throw new Error('DOM not available in this environment'); },
        'setAutoPosition'()          { throw new Error('DOM not available in this environment'); },
        'setCoords'()                { throw new Error('DOM not available in this environment'); },
        'setText'()                  { throw new Error('DOM not available in this environment'); },
        'setTextJessieCode'()        { throw new Error('DOM not available in this environment'); },
        'unescapeTicks'()            { throw new Error('DOM not available in this environment'); },
        'updateSize'()               { throw new Error('DOM not available in this environment'); },
        'updateText'()               { throw new Error('DOM not available in this environment'); },
        'utf8_decode'()              { throw new Error('DOM not available in this environment'); },
        'valueTagToJessieCode'()     { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph ForeignObject
    'jsx-foreignobject': hasDOM ? {
        'H':                        (foreignobject => call_jsxgraph_method(foreignobject, 'ForeignObject', 'H')),
        'W':                        (foreignobject => call_jsxgraph_method(foreignobject, 'ForeignObject', 'W')),
        'hasPoint':                 ((foreignobject, x, y) => call_jsxgraph_method(foreignobject, 'ForeignObject', 'hasPoint', [from_fasl(x), from_fasl(y)])),
        'setSize':                  ((foreignobject, width, height) => call_jsxgraph_method(foreignobject, 'ForeignObject', 'setSize', [from_fasl(width), from_fasl(height)])),
        'update':                   (foreignobject => call_jsxgraph_method(foreignobject, 'ForeignObject', 'update')),
        'updateRenderer':           (foreignobject => call_jsxgraph_method(foreignobject, 'ForeignObject', 'updateRenderer')),
        'updateSize':               (foreignobject => call_jsxgraph_method(foreignobject, 'ForeignObject', 'updateSize')),
        'updateSpan':               (foreignobject => call_jsxgraph_method(foreignobject, 'ForeignObject', 'updateSpan'))
    } : {
        'H'()                       { throw new Error('DOM not available in this environment'); },
        'W'()                       { throw new Error('DOM not available in this environment'); },
        'hasPoint'()                { throw new Error('DOM not available in this environment'); },
        'setSize'()                 { throw new Error('DOM not available in this environment'); },
        'update'()                  { throw new Error('DOM not available in this environment'); },
        'updateRenderer'()          { throw new Error('DOM not available in this environment'); },
        'updateSize'()              { throw new Error('DOM not available in this environment'); },
        'updateSpan'()              { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Tapemeasure
    'jsx-tapemeasure': hasDOM ? {
        'Value':                    (tapemeasure => call_jsxgraph_method(tapemeasure, 'Tapemeasure', 'Value'))
    } : {
        'Value'()                   { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Ticks
    'jsx-ticks': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'ticks', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Transformation
    'jsx-transformation': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'transform', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Tracecurve
    'jsx-tracecurve': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'tracecurve', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Parallelogram
    'jsx-parallelogram': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'parallelogram', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph ReflexAngle
    'jsx-reflexangle': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'reflexangle', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Point Relation Helpers
    'jsx-mirrorpoint': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'mirrorpoint', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    'jsx-otherintersection': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'otherintersection', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    'jsx-orthogonalprojection': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'orthogonalprojection', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    'jsx-parallelpoint': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'parallelpoint', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    'jsx-perpendicularpoint': hasDOM ? {
        'create':                   ((board, parents, attrs) => call_jsxgraph_board_create(board, 'perpendicularpoint', parents, attrs))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Checkbox
    'jsx-checkbox': hasDOM ? {
        'Value':           ((checkbox, args) => call_jsxgraph_method(checkbox, 'Checkbox', 'Value', from_fasl(args)))
    } : {
        'Value'()          { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Input
    'jsx-input': hasDOM ? {
        'set':   ((input, args) => call_jsxgraph_method(input, 'Input', 'set', from_fasl(args))),
        'Value': ((input, args) => call_jsxgraph_method(input, 'Input', 'Value', from_fasl(args)))
    } : {
        'set'()   { throw new Error('DOM not available in this environment'); },
        'Value'() { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Slider
    'jsx-slider': hasDOM ? {
        'setMax':   ((slider, args) => call_jsxgraph_method(slider, 'Slider', 'setMax', from_fasl(args))),
        'setMin':   ((slider, args) => call_jsxgraph_method(slider, 'Slider', 'setMin', from_fasl(args))),
        'setValue': ((slider, args) => call_jsxgraph_method(slider, 'Slider', 'setValue', from_fasl(args))),
        'Value':    ((slider, args) => call_jsxgraph_method(slider, 'Slider', 'Value', from_fasl(args)))
    } : {
        'setMax'()   { throw new Error('DOM not available in this environment'); },
        'setMin'()   { throw new Error('DOM not available in this environment'); },
        'setValue'() { throw new Error('DOM not available in this environment'); },
        'Value'()    { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Chart
    'jsx-chart': hasDOM ? {
        'drawBar':       ((chart, args) => call_jsxgraph_method(chart, 'Chart', 'drawBar', from_fasl(args))),
        'drawFit':       ((chart, args) => call_jsxgraph_method(chart, 'Chart', 'drawFit', from_fasl(args))),
        'drawLine':      ((chart, args) => call_jsxgraph_method(chart, 'Chart', 'drawLine', from_fasl(args))),
        'drawPie':       ((chart, args) => call_jsxgraph_method(chart, 'Chart', 'drawPie', from_fasl(args))),
        'drawPoints':    ((chart, args) => call_jsxgraph_method(chart, 'Chart', 'drawPoints', from_fasl(args))),
        'drawRadar':     ((chart, args) => call_jsxgraph_method(chart, 'Chart', 'drawRadar', from_fasl(args))),
        'drawSpline':    ((chart, args) => call_jsxgraph_method(chart, 'Chart', 'drawSpline', from_fasl(args))),
        'updateDataArray': ((chart, args) => call_jsxgraph_method(chart, 'Chart', 'updateDataArray', from_fasl(args))),
        'updateRenderer':  ((chart, args) => call_jsxgraph_method(chart, 'Chart', 'updateRenderer', from_fasl(args)))
    } : {
        'drawBar'()        { throw new Error('DOM not available in this environment'); },
        'drawFit'()        { throw new Error('DOM not available in this environment'); },
        'drawLine'()       { throw new Error('DOM not available in this environment'); },
        'drawPie'()        { throw new Error('DOM not available in this environment'); },
        'drawPoints'()     { throw new Error('DOM not available in this environment'); },
        'drawRadar'()      { throw new Error('DOM not available in this environment'); },
        'drawSpline'()     { throw new Error('DOM not available in this environment'); },
        'updateDataArray'(){ throw new Error('DOM not available in this environment'); },
        'updateRenderer'() { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Image
    'jsx-image': hasDOM ? {
        'H':              ((image, args) => call_jsxgraph_method(image, 'Image', 'H', from_fasl(args))),
        'W':              ((image, args) => call_jsxgraph_method(image, 'Image', 'W', from_fasl(args))),
        'hasPoint':       ((image, args) => call_jsxgraph_method(image, 'Image', 'hasPoint', from_fasl(args))),
        'setSize':        ((image, args) => call_jsxgraph_method(image, 'Image', 'setSize', from_fasl(args))),
        'update':         ((image, args) => call_jsxgraph_method(image, 'Image', 'update', from_fasl(args))),
        'updateRenderer': ((image, args) => call_jsxgraph_method(image, 'Image', 'updateRenderer', from_fasl(args))),
        'updateSize':     ((image, args) => call_jsxgraph_method(image, 'Image', 'updateSize', from_fasl(args))),
        'updateSpan':     ((image, args) => call_jsxgraph_method(image, 'Image', 'updateSpan', from_fasl(args)))
    } : {
        'H'()             { throw new Error('DOM not available in this environment'); },
        'W'()             { throw new Error('DOM not available in this environment'); },
        'hasPoint'()      { throw new Error('DOM not available in this environment'); },
        'setSize'()       { throw new Error('DOM not available in this environment'); },
        'update'()        { throw new Error('DOM not available in this environment'); },
        'updateRenderer'(){ throw new Error('DOM not available in this environment'); },
        'updateSize'()    { throw new Error('DOM not available in this environment'); },
        'updateSpan'()    { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Group
    'jsx-group': hasDOM ? {
        'addParents':          ((group, args) => call_jsxgraph_method(group, 'Group', 'addParents', from_fasl(args))),
        'addPoint':            ((group, args) => call_jsxgraph_method(group, 'Group', 'addPoint', from_fasl(args))),
        'addPoints':           ((group, args) => call_jsxgraph_method(group, 'Group', 'addPoints', from_fasl(args))),
        'addRotationPoint':    ((group, args) => call_jsxgraph_method(group, 'Group', 'addRotationPoint', from_fasl(args))),
        'addScalePoint':       ((group, args) => call_jsxgraph_method(group, 'Group', 'addScalePoint', from_fasl(args))),
        'addTranslationPoint': ((group, args) => call_jsxgraph_method(group, 'Group', 'addTranslationPoint', from_fasl(args))),
        'addGroup':            ((group, args) => call_jsxgraph_method(group, 'Group', 'addGroup', from_fasl(args))),
        'removePoint':         ((group, args) => call_jsxgraph_method(group, 'Group', 'removePoint', from_fasl(args))),
        'removeRotationPoint': ((group, args) => call_jsxgraph_method(group, 'Group', 'removeRotationPoint', from_fasl(args))),
        'removeScalePoint':    ((group, args) => call_jsxgraph_method(group, 'Group', 'removeScalePoint', from_fasl(args))),
        'removeTranslationPoint': ((group, args) => call_jsxgraph_method(group, 'Group', 'removeTranslationPoint', from_fasl(args))),
        'setParents':          ((group, args) => call_jsxgraph_method(group, 'Group', 'setParents', from_fasl(args))),
        'setRotationCenter':   ((group, args) => call_jsxgraph_method(group, 'Group', 'setRotationCenter', from_fasl(args))),
        'setRotationPoints':   ((group, args) => call_jsxgraph_method(group, 'Group', 'setRotationPoints', from_fasl(args))),
        'setScaleCenter':      ((group, args) => call_jsxgraph_method(group, 'Group', 'setScaleCenter', from_fasl(args))),
        'setScalePoints':      ((group, args) => call_jsxgraph_method(group, 'Group', 'setScalePoints', from_fasl(args))),
        'setTranslationPoints': ((group, args) => call_jsxgraph_method(group, 'Group', 'setTranslationPoints', from_fasl(args))),
        'ungroup':             (group => call_jsxgraph_method(group, 'Group', 'ungroup')),
        'update':              (group => call_jsxgraph_method(group, 'Group', 'update'))
    } : {
        'addParents'()          { throw new Error('DOM not available in this environment'); },
        'addPoint'()            { throw new Error('DOM not available in this environment'); },
        'addPoints'()           { throw new Error('DOM not available in this environment'); },
        'addRotationPoint'()    { throw new Error('DOM not available in this environment'); },
        'addScalePoint'()       { throw new Error('DOM not available in this environment'); },
        'addTranslationPoint'() { throw new Error('DOM not available in this environment'); },
        'addGroup'()            { throw new Error('DOM not available in this environment'); },
        'removePoint'()         { throw new Error('DOM not available in this environment'); },
        'removeRotationPoint'() { throw new Error('DOM not available in this environment'); },
        'removeScalePoint'()    { throw new Error('DOM not available in this environment'); },
        'removeTranslationPoint'() { throw new Error('DOM not available in this environment'); },
        'setParents'()          { throw new Error('DOM not available in this environment'); },
        'setRotationCenter'()   { throw new Error('DOM not available in this environment'); },
        'setRotationPoints'()   { throw new Error('DOM not available in this environment'); },
        'setScaleCenter'()      { throw new Error('DOM not available in this environment'); },
        'setScalePoints'()      { throw new Error('DOM not available in this environment'); },
        'setTranslationPoints'() { throw new Error('DOM not available in this environment'); },
        'ungroup'()             { throw new Error('DOM not available in this environment'); },
        'update'()              { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Line
    'jsx-line': hasDOM ? {
        'call': ((line, method, args) => call_js_method(line, method, args, 'jsx-line.call')),
        'call/nullish': ((line, method, args) => { call_js_method(line, method, args, 'jsx-line.call/nullish'); })
    } : {
        'call'()                      { throw new Error('DOM not available in this environment'); },
        'call/nullish'()              { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Arc
    'jsx-arc': hasDOM ? {
        'get-radius':                 (arc => call_jsxgraph_method(arc, 'Arc', 'getRadius')),
        'has-point-sector':           ((arc, x, y) => call_jsxgraph_method(arc, 'Arc', 'hasPointSector', [x, y])),
        'radius':                     (arc => call_jsxgraph_method(arc, 'Arc', 'Radius')),
        'value':                      ((arc, unit, rad) => call_jsxgraph_method(arc, 'Arc', 'Value', [from_fasl(unit), from_fasl(rad)]))
    } : {
        'get-radius'()                { throw new Error('DOM not available in this environment'); },
        'has-point-sector'()          { throw new Error('DOM not available in this environment'); },
        'radius'()                    { throw new Error('DOM not available in this environment'); },
        'value'()                     { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Angle
    'jsx-angle': hasDOM ? {
        'free':                       (angle => call_jsxgraph_method(angle, 'Angle', 'free')),
        'set-angle!':                 ((angle, val) => { call_jsxgraph_method(angle, 'Angle', 'setAngle', [from_fasl(val)]); }),
        'value':                      ((angle, unit) => call_jsxgraph_method(angle, 'Angle', 'Value', [from_fasl(unit)]))
    } : {
        'free'()                      { throw new Error('DOM not available in this environment'); },
        'set-angle!'()                { throw new Error('DOM not available in this environment'); },
        'value'()                     { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Sector
    'jsx-sector': hasDOM ? {
        'area':                       (sector => call_jsxgraph_method(sector, 'Sector', 'Area')),
        'has-point-sector':           ((sector, x, y) => call_jsxgraph_method(sector, 'Sector', 'hasPointSector', [x, y])),
        'l':                          (sector => call_jsxgraph_method(sector, 'Sector', 'L')),
        'perimeter':                  (sector => call_jsxgraph_method(sector, 'Sector', 'Perimeter')),
        'radius':                     (sector => call_jsxgraph_method(sector, 'Sector', 'Radius')),
        'set-position-directly!':     ((sector, method, coords, oldcoords) => call_jsxgraph_method(sector, 'Sector', 'setPositionDirectly', [from_fasl(method), from_fasl(coords), from_fasl(oldcoords)])),
        'set-radius!':                ((sector, value) => call_jsxgraph_method(sector, 'Sector', 'setRadius', [from_fasl(value)]))
    } : {
        'area'()                      { throw new Error('DOM not available in this environment'); },
        'has-point-sector'()          { throw new Error('DOM not available in this environment'); },
        'l'()                         { throw new Error('DOM not available in this environment'); },
        'perimeter'()                 { throw new Error('DOM not available in this environment'); },
        'radius'()                    { throw new Error('DOM not available in this environment'); },
        'set-position-directly!'()    { throw new Error('DOM not available in this environment'); },
        'set-radius!'()               { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Glider
    'jsx-glider': hasDOM ? {
        'start-animation!':          ((glider, direction, stepCount, delay) => call_jsxgraph_method(glider, 'Glider', 'startAnimation', [from_fasl(direction), from_fasl(stepCount), from_fasl(delay)])),
        'stop-animation!':           ((glider) => call_jsxgraph_method(glider, 'Glider', 'stopAnimation'))
    } : {
        'start-animation!'()         { throw new Error('DOM not available in this environment'); },
        'stop-animation!'()          { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Circle
    'jsx-circle': hasDOM ? {
        'call': ((circle, method, args) => call_js_method(circle, method, args, 'jsx-circle.call')),
        'call/nullish': ((circle, method, args) => { call_js_method(circle, method, args, 'jsx-circle.call/nullish'); })
    } : {
        'call'()                      { throw new Error('DOM not available in this environment'); },
        'call/nullish'()              { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Curve
    'jsx-curve': hasDOM ? {
        'call': ((curve, method, args) => call_js_method(curve, method, args, 'jsx-curve.call')),
        'call/nullish': ((curve, method, args) => { call_js_method(curve, method, args, 'jsx-curve.call/nullish'); })
    } : {
        'call'()                      { throw new Error('DOM not available in this environment'); },
        'call/nullish'()              { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Riemannsum
    'jsx-riemannsum': hasDOM ? {
        'Value': ((riemannsum) => call_jsxgraph_method(riemannsum, 'Riemannsum', 'Value'))
    } : {
        'Value'()                     { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Slopefield
    'jsx-slopefield': hasDOM ? {
        'setF': ((field, func) => call_jsxgraph_method(field, 'Slopefield', 'setF', [from_fasl(func)]))
    } : {
        'setF'()                      { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Vectorfield
    'jsx-vectorfield': hasDOM ? {
        'setF': ((field, func) => call_jsxgraph_method(field, 'Vectorfield', 'setF', [from_fasl(func)]))
    } : {
        'setF'()                      { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Polygon
    'jsx-polygon': hasDOM ? {
        'call': ((polygon, method, args) => call_js_method(polygon, method, args, 'jsx-polygon.call')),
        'call/nullish': ((polygon, method, args) => { call_js_method(polygon, method, args, 'jsx-polygon.call/nullish'); })
    } : {
        'call'()                      { throw new Error('DOM not available in this environment'); },
        'call/nullish'()              { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Point
    'jsx-point': hasDOM ? {
        'is-point':                    (v => boolean_to_i32(require_jsxgraph_is_point()(v))),
        'attractor-distance':          (pt => get_jsxgraph_point_property(pt, 'attractorDistance')),
        'set-attractor-distance!':     ((pt, d) => { set_jsxgraph_point_property(pt, 'attractorDistance', d); }),
        'attractors':                  (pt => get_jsxgraph_point_property(pt, 'attractors')),
        'set-attractors!':             ((pt, a) => { set_jsxgraph_point_property(pt, 'attractors', a); }),
        'attractor-unit':              (pt => get_jsxgraph_point_property(pt, 'attractorUnit')),
        'set-attractor-unit!':         ((pt, u) => { set_jsxgraph_point_property(pt, 'attractorUnit', from_fasl(u)); }),
        'attract-to-grid':             (pt => get_jsxgraph_point_property(pt, 'attractToGrid') ? 1 : 0),
        'set-attract-to-grid!':        ((pt, flag) => { set_jsxgraph_point_property(pt, 'attractToGrid', !!flag); }),
        'face':                        (pt => get_jsxgraph_point_property(pt, 'face')),
        'set-face!':                   ((pt, f) => { set_jsxgraph_point_property(pt, 'face', from_fasl(f)); }),
        'ignored-snap-to-points':      (pt => get_jsxgraph_point_property(pt, 'ignoredSnapToPoints')),
        'set-ignored-snap-to-points!': ((pt, p) => { set_jsxgraph_point_property(pt, 'ignoredSnapToPoints', p); }),
        'infobox-digits':              (pt => get_jsxgraph_point_property(pt, 'infoboxDigits')),
        'set-infobox-digits!':         ((pt, n) => { set_jsxgraph_point_property(pt, 'infoboxDigits', n); }),
        'show-infobox':                (pt => get_jsxgraph_point_property(pt, 'showInfobox') ? 1 : 0),
        'set-show-infobox!':           ((pt, flag) => { set_jsxgraph_point_property(pt, 'showInfobox', !!flag); }),
        'size':                        (pt => get_jsxgraph_point_property(pt, 'size')),
        'set-size!':                   ((pt, s) => { set_jsxgraph_point_property(pt, 'size', s); }),
        'size-unit':                   (pt => get_jsxgraph_point_property(pt, 'sizeUnit')),
        'set-size-unit!':              ((pt, u) => { set_jsxgraph_point_property(pt, 'sizeUnit', from_fasl(u)); }),
        'snap-size-x':                 (pt => get_jsxgraph_point_property(pt, 'snapSizeX')),
        'set-snap-size-x!':            ((pt, x) => { set_jsxgraph_point_property(pt, 'snapSizeX', x); }),
        'snap-size-y':                 (pt => get_jsxgraph_point_property(pt, 'snapSizeY')),
        'set-snap-size-y!':            ((pt, y) => { set_jsxgraph_point_property(pt, 'snapSizeY', y); }),
        'snap-to-grid':                (pt => get_jsxgraph_point_property(pt, 'snapToGrid') ? 1 : 0),
        'set-snap-to-grid!':           ((pt, flag) => { set_jsxgraph_point_property(pt, 'snapToGrid', !!flag); }),
        'snap-to-points':              (pt => get_jsxgraph_point_property(pt, 'snapToPoints') ? 1 : 0),
        'set-snap-to-points!':         ((pt, flag) => { set_jsxgraph_point_property(pt, 'snapToPoints', !!flag); }),
        'snatch-distance':             (pt => get_jsxgraph_point_property(pt, 'snatchDistance')),
        'set-snatch-distance!':        ((pt, d) => { set_jsxgraph_point_property(pt, 'snatchDistance', d); }),
        'style':                       (pt => get_jsxgraph_point_property(pt, 'style')),
        'set-style!':                  ((pt, s) => { set_jsxgraph_point_property(pt, 'style', s); }),
        'x':                           (pt => call_jsxgraph_method(pt, 'Point', 'X')),
        'y':                           (pt => call_jsxgraph_method(pt, 'Point', 'Y')),
        'zoom':                        (pt => get_jsxgraph_point_property(pt, 'zoom') ? 1 : 0),
        'set-zoom!':                   ((pt, flag) => { set_jsxgraph_point_property(pt, 'zoom', !!flag); }),
        'has-point':                   ((pt, x, y) => call_jsxgraph_method(pt, 'Point', 'hasPoint', [x, y]) ? 1 : 0),
        'is-on':                       ((pt, el, tol) => call_jsxgraph_method(pt, 'Point', 'isOn', [el, tol]) ? 1 : 0),
        'make-intersection!':          ((pt, el1, el2, i, j) => { call_jsxgraph_method(pt, 'Point', 'makeIntersection', [el1, el2, i, j]); }),
        'normalize-face':              ((pt, s) => call_jsxgraph_method(pt, 'Point', 'normalizeFace', [from_fasl(s)])),
        'call-set-style!':             ((pt, i) => { call_jsxgraph_method(pt, 'Point', 'setStyle', [i]); }),
        'update!':                     ((pt, flag) => { call_jsxgraph_method(pt, 'Point', 'update', [!!flag]); }),
        'update-renderer!':            (pt => { call_jsxgraph_method(pt, 'Point', 'updateRenderer'); }),
        'update-transform!':           ((pt, flag) => call_jsxgraph_method(pt, 'Point', 'updateTransform', [!!flag]))
    } : {
        'is-point'()                    { throw new Error('DOM not available in this environment'); },
        'attractor-distance'()          { throw new Error('DOM not available in this environment'); },
        'set-attractor-distance!'()     { throw new Error('DOM not available in this environment'); },
        'attractors'()                  { throw new Error('DOM not available in this environment'); },
        'set-attractors!'()             { throw new Error('DOM not available in this environment'); },
        'attractor-unit'()              { throw new Error('DOM not available in this environment'); },
        'set-attractor-unit!'()         { throw new Error('DOM not available in this environment'); },
        'attract-to-grid'()             { throw new Error('DOM not available in this environment'); },
        'set-attract-to-grid!'()        { throw new Error('DOM not available in this environment'); },
        'face'()                        { throw new Error('DOM not available in this environment'); },
        'set-face!'()                   { throw new Error('DOM not available in this environment'); },
        'ignored-snap-to-points'()      { throw new Error('DOM not available in this environment'); },
        'set-ignored-snap-to-points!'() { throw new Error('DOM not available in this environment'); },
        'infobox-digits'()              { throw new Error('DOM not available in this environment'); },
        'set-infobox-digits!'()         { throw new Error('DOM not available in this environment'); },
        'show-infobox'()                { throw new Error('DOM not available in this environment'); },
        'set-show-infobox!'()           { throw new Error('DOM not available in this environment'); },
        'size'()                        { throw new Error('DOM not available in this environment'); },
        'set-size!'()                   { throw new Error('DOM not available in this environment'); },
        'size-unit'()                   { throw new Error('DOM not available in this environment'); },
        'set-size-unit!'()              { throw new Error('DOM not available in this environment'); },
        'snap-size-x'()                 { throw new Error('DOM not available in this environment'); },
        'set-snap-size-x!'()            { throw new Error('DOM not available in this environment'); },
        'snap-size-y'()                 { throw new Error('DOM not available in this environment'); },
        'set-snap-size-y!'()            { throw new Error('DOM not available in this environment'); },
        'snap-to-grid'()                { throw new Error('DOM not available in this environment'); },
        'set-snap-to-grid!'()           { throw new Error('DOM not available in this environment'); },
        'snap-to-points'()              { throw new Error('DOM not available in this environment'); },
        'set-snap-to-points!'()         { throw new Error('DOM not available in this environment'); },
        'snatch-distance'()             { throw new Error('DOM not available in this environment'); },
        'set-snatch-distance!'()        { throw new Error('DOM not available in this environment'); },
        'style'()                       { throw new Error('DOM not available in this environment'); },
        'set-style!'()                  { throw new Error('DOM not available in this environment'); },
        'x'()                           { throw new Error('DOM not available in this environment'); },
        'y'()                           { throw new Error('DOM not available in this environment'); },
        'zoom'()                        { throw new Error('DOM not available in this environment'); },
        'set-zoom!'()                   { throw new Error('DOM not available in this environment'); },
        'has-point'()                   { throw new Error('DOM not available in this environment'); },
        'is-on'()                       { throw new Error('DOM not available in this environment'); },
        'make-intersection!'()          { throw new Error('DOM not available in this environment'); },
        'normalize-face'()              { throw new Error('DOM not available in this environment'); },
        'call-set-style!'()             { throw new Error('DOM not available in this environment'); },
        'update!'()                     { throw new Error('DOM not available in this environment'); },
        'update-renderer!'()            { throw new Error('DOM not available in this environment'); },
        'update-transform!'()           { throw new Error('DOM not available in this environment'); }
    }
};

install_ffi_exception_bridge(imports);
