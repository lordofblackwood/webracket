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
  const method = typeof console[name] === 'function'
    ? console[name]
    : fallbackName && typeof console[fallbackName] === 'function'
      ? console[fallbackName]
      : null;
  if (method) {
    return method.apply(console, args);
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
      'log':                       (args => console.log(...(from_fasl(args) || []))),
      'info':                      (args => console.info(...(from_fasl(args) || []))),
      'warn':                      (args => console.warn(...(from_fasl(args) || []))),
      'error':                     (args => console.error(...(from_fasl(args) || []))),
      'debug':                     (args => console.debug(...(from_fasl(args) || []))),
      'assert':                    (args => {
                                     const as = from_fasl(args) || [];
                                     console.assert(...as);
                                   }),
      'clear':                     (() => console.clear()),
      'dir':                       (args => console.dir(...(from_fasl(args) || []))),
      'dirxml':                    (args => {
                                     const as = from_fasl(args) || [];
                                     call_console_fallback('dirxml', 'log', as);
                                   }),
      'table':                     (args => {
                                     const as = from_fasl(args) || [];
                                     call_console_fallback('table', 'log', as);
                                   }),
      'group':                     (args => console.group(...(from_fasl(args) || []))),
      'group-collapsed':           (args => console.groupCollapsed(...(from_fasl(args) || []))),
      'group-end':                 (() => console.groupEnd()),
      'count':                     (args => console.count(...(from_fasl(args) || []))),
      'count-reset':               (args => {
                                     const as = from_fasl(args) || [];
                                     call_console_fallback('countReset', 'count', as);
                                   }),
      'time':                      (args => console.time(...(from_fasl(args) || []))),
      'time-end':                  (args => console.timeEnd(...(from_fasl(args) || []))),
      'time-log':                  (args => console.timeLog(...(from_fasl(args) || []))),
      'time-stamp':                (args => call_console_fallback('timeStamp', null, from_fasl(args) || [])),
      'trace':                     (args => console.trace(...(from_fasl(args) || []))),
      'profile':                   (args => call_console_fallback('profile', null, from_fasl(args) || [])),
      'profile-end':               (args => call_console_fallback('profileEnd', null, from_fasl(args) || [])),
      'exception':                 (args => call_console_fallback('exception', 'error', from_fasl(args) || [])),
    },

    // Temporary/prototype FFI.
    'temp': {
      'x':                         ((o) => to_fasl(o.x)),
      'set-x!':                    ((o, v) => { o.x = from_fasl(v); }),
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
                                 return d === undefined ? x.toExponential() : x.toExponential(d);
                               }),
        // Format number with fixed-point notation.
        'to-fixed':          ((x, digits) => {
                                 const d = from_fasl(digits);
                                 return d === undefined ? x.toFixed() : x.toFixed(d);
                               }),
        // Format number using locale-specific rules.
        'to-locale-string':  ((x, locales, options) => x.toLocaleString(from_fasl(locales), from_fasl(options))),
        // Format number with specified precision.
        'to-precision':      ((x, precision) => {
                                 const p = from_fasl(precision);
                                 return p === undefined ? x.toPrecision() : x.toPrecision(p);
                               }),
        // Convert number to string with optional radix.
        'to-string':         ((x, radix) => {
                                 const r = from_fasl(radix);
                                 return r === undefined ? x.toString() : x.toString(r);
                               }),
        // Extract primitive numeric value.
        'value-of':          (x => x.valueOf())
    },

    // JavaScript Array FFI.
      'array': {
        'length':            (arr => arr.length),
        'set-length!':       ((arr, len) => { arr.length = len; }),
        'from':              ((arrLike, mapFn, thisArg) => {
            const a = from_fasl(arrLike);
            const m = mapFn;
            const t = from_fasl(thisArg);
            if (m === undefined) {
                return Array.from(a);
            } else if (t === undefined) {
                return Array.from(a, m);
            } else {
                return Array.from(a, m, t);
            }
        }),
        'from-async':        ((arrLike, mapFn, thisArg) => {
            const a = from_fasl(arrLike);
            const m = mapFn;
            const t = from_fasl(thisArg);
            if (m === undefined) {
                return Array.fromAsync(a);
            } else if (t === undefined) {
                return Array.fromAsync(a, m);
            } else {
                return Array.fromAsync(a, m, t);
            }
        }),
        'is-array':          (v => Array.isArray(from_fasl(v)) ? 1 : 0),
        'to-vector':         (arr => to_fasl(Array.from(arr))),
        'to-bytes':          (arr => to_fasl(Uint8Array.from(arr))),
        'of':                (items => Array.of(...(from_fasl(items) || []))),
        'at':                ((arr, index) => arr.at(index)),
        'concat':            ((arr, items) => arr.concat(...(from_fasl(items) || []))),
        'copy-within':       ((arr, target, start, end) => {
            const e = from_fasl(end);
            return e === undefined ? arr.copyWithin(target, start)
                                   : arr.copyWithin(target, start, e);
        }),
        'entries':           (arr => arr.entries()),
        'every':             ((arr, fn, thisArg) => arr.every(fn, from_fasl(thisArg)) ? 1 : 0),
        'fill':              ((arr, value, start, end) => arr.fill(from_fasl(value), from_fasl(start), from_fasl(end))),
        'filter':            ((arr, fn, thisArg) => arr.filter(fn, from_fasl(thisArg))),
        'find':              ((arr, fn, thisArg) => arr.find(fn, from_fasl(thisArg))),
        'find-index':        ((arr, fn, thisArg) => arr.findIndex(fn, from_fasl(thisArg))),
        'find-last':         ((arr, fn, thisArg) => arr.findLast(fn, from_fasl(thisArg))),
        'find-last-index':   ((arr, fn, thisArg) => arr.findLastIndex(fn, from_fasl(thisArg))),
        'flat':              ((arr, depth) => arr.flat(from_fasl(depth))),
        'flat-map':          ((arr, fn, thisArg) => arr.flatMap(fn, from_fasl(thisArg))),
        'for-each':          ((arr, fn, thisArg) => { arr.forEach(fn, from_fasl(thisArg)); }),
        'includes':          ((arr, value, fromIndex) => arr.includes(from_fasl(value), from_fasl(fromIndex)) ? 1 : 0),
        'index-of':          ((arr, value, fromIndex) => arr.indexOf(from_fasl(value), from_fasl(fromIndex))),
        'join':              ((arr, sep) => arr.join(from_fasl(sep))),
        'keys':              (arr => arr.keys()),
        'last-index-of':     ((arr, value, fromIndex) => arr.lastIndexOf(from_fasl(value), from_fasl(fromIndex))),
        'map':               ((arr, fn, thisArg) => arr.map(fn, from_fasl(thisArg))),
        'pop':               (arr => arr.pop()),
        'push':              ((arr, items) => arr.push(...(from_fasl(items) || []))),
        'reduce':            ((arr, fn, init) => {
            const i = from_fasl(init);
            return i === undefined ? arr.reduce(fn) : arr.reduce(fn, i);
        }),
        'reduce-right':      ((arr, fn, init) => {
            const i = from_fasl(init);
            return i === undefined ? arr.reduceRight(fn) : arr.reduceRight(fn, i);
        }),
        'reverse':           (arr => arr.reverse()),
        'shift':             (arr => arr.shift()),
        'slice':             ((arr, start, end) => arr.slice(from_fasl(start), from_fasl(end))),
        'some':              ((arr, fn, thisArg) => arr.some(fn, from_fasl(thisArg)) ? 1 : 0),
        'sort':              ((arr, fn) => arr.sort(fn)),
        'splice':            ((arr, items) => arr.splice(...(from_fasl(items) || []))),
        'to-locale-string':  ((arr, args) => arr.toLocaleString(...(from_fasl(args) || []))),
        'to-string':         (arr => arr.toString()),
        'unshift':           ((arr, items) => arr.unshift(...(from_fasl(items) || []))),
        'values':            (arr => arr.values()),
        'to-reversed':       (arr => (arr.toReversed ? arr.toReversed() : [...arr].reverse())),
        'to-sorted':         ((arr, fn) => (arr.toSorted ? arr.toSorted(fn) : [...arr].sort(fn))),
        'to-spliced':        ((arr, items) => (arr.toSpliced ? arr.toSpliced(...(from_fasl(items) || [])) : (() => { const b = arr.slice(); b.splice(...(from_fasl(items) || [])); return b; })())),
        'with':              ((arr, index, value) => (arr.with ? arr.with(index, from_fasl(value)) : (() => { const b = arr.slice(); b[index] = from_fasl(value); return b; })())),
    },
    // Canvas
    'canvas': hasDOM ? {
        'capture-stream':                ((canvas, rate)                 => require_host_function(canvas,
                                                                                                    'captureStream',
                                                                                                    'canvas.captureStream')(rate)),
        'get-context':                   ((canvas, type, opts)           => require_host_function(canvas,
                                                                                                    'getContext',
                                                                                                    'canvas.getContext')(from_fasl(type), opts)),
        'height':                        ((canvas)                       => canvas.height),
        'set-height!':                   ((canvas, h)                    => { canvas.height = h; }),
        'to-blob':                       ((canvas, cb, type, quality)    => require_host_function(canvas,
                                                                                                    'toBlob',
                                                                                                    'canvas.toBlob')(cb, from_fasl(type), quality)),
        'to-data-url':                   ((canvas, type, quality)        => require_host_function(canvas,
                                                                                                    'toDataURL',
                                                                                                    'canvas.toDataURL')(from_fasl(type), quality)),
        'transfer-control-to-offscreen': ((canvas)                       => require_host_function(canvas,
                                                                                                    'transferControlToOffscreen',
                                                                                                    'canvas.transferControlToOffscreen')()),
        'width':                         ((canvas)                       => canvas.width),
        'set-width!':                    ((canvas, w)                    => { canvas.width = w; })
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
        'canvas':                 (ctx => ctx.canvas),
        'direction':              (ctx => ctx.direction),
        'set-direction!':         ((ctx, dir) => { ctx.direction = from_fasl(dir); }),
        'fill-style':             (ctx => ctx.fillStyle),
        'set-fill-style!':        ((ctx, style) => { ctx.fillStyle = from_fasl(style); }),
        'filter':                 (ctx => ctx.filter),
        'set-filter!':            ((ctx, filter) => { ctx.filter = from_fasl(filter); }),
        'font':                   (ctx => ctx.font),
        'set-font!':              ((ctx, font) => { ctx.font = from_fasl(font); }),
        'global-alpha':           (ctx => ctx.globalAlpha),
        'set-global-alpha!':      ((ctx, a) => { ctx.globalAlpha = a; }),
        'global-composite-operation': (ctx => ctx.globalCompositeOperation),
        'set-global-composite-operation!': ((ctx, op) => { ctx.globalCompositeOperation = from_fasl(op); }),
        'image-smoothing-enabled': (ctx => ctx.imageSmoothingEnabled ? 1 : 0),
        'set-image-smoothing-enabled!': ((ctx, flag) => { ctx.imageSmoothingEnabled = !!flag; }),
        'image-smoothing-quality': (ctx => ctx.imageSmoothingQuality),
        'set-image-smoothing-quality!': ((ctx, q) => { ctx.imageSmoothingQuality = from_fasl(q); }),
        'line-cap':               (ctx => ctx.lineCap),
        'set-line-cap!':          ((ctx, cap) => { ctx.lineCap = from_fasl(cap); }),
        'line-dash-offset':       (ctx => ctx.lineDashOffset),
        'set-line-dash-offset!':  ((ctx, off) => { ctx.lineDashOffset = off; }),
        'line-join':              (ctx => ctx.lineJoin),
        'set-line-join!':         ((ctx, join) => { ctx.lineJoin = from_fasl(join); }),
        'line-width':             (ctx => ctx.lineWidth),
        'set-line-width!':        ((ctx, w) => { ctx.lineWidth = w; }),
        'miter-limit':            (ctx => ctx.miterLimit),
        'set-miter-limit!':       ((ctx, m) => { ctx.miterLimit = m; }),
        'shadow-blur':            (ctx => ctx.shadowBlur),
        'set-shadow-blur!':       ((ctx, b) => { ctx.shadowBlur = b; }),
        'shadow-color':           (ctx => ctx.shadowColor),
        'set-shadow-color!':      ((ctx, c) => { ctx.shadowColor = from_fasl(c); }),
        'shadow-offset-x':        (ctx => ctx.shadowOffsetX),
        'set-shadow-offset-x!':   ((ctx, x) => { ctx.shadowOffsetX = x; }),
        'shadow-offset-y':        (ctx => ctx.shadowOffsetY),
        'set-shadow-offset-y!':   ((ctx, y) => { ctx.shadowOffsetY = y; }),
        'stroke-style':           (ctx => ctx.strokeStyle),
        'set-stroke-style!':      ((ctx, style) => { ctx.strokeStyle = from_fasl(style); }),
        'text-align':             (ctx => ctx.textAlign),
        'set-text-align!':        ((ctx, a) => { ctx.textAlign = from_fasl(a); }),
        'text-baseline':          (ctx => ctx.textBaseline),
        'set-text-baseline!':     ((ctx, b) => { ctx.textBaseline = from_fasl(b); }),
        'text-rendering':         (ctx => ctx.textRendering),
        'set-text-rendering!':    ((ctx, r) => { ctx.textRendering = from_fasl(r); }),
        'font-kerning':           (ctx => ctx.fontKerning),
        'set-font-kerning!':      ((ctx, k) => { ctx.fontKerning = from_fasl(k); }),
        'font-stretch':           (ctx => ctx.fontStretch),
        'set-font-stretch!':      ((ctx, s) => { ctx.fontStretch = from_fasl(s); }),
        'font-variant-caps':      (ctx => ctx.fontVariantCaps),
        'set-font-variant-caps!': ((ctx, v) => { ctx.fontVariantCaps = from_fasl(v); }),
        'font-variant-ligatures': (ctx => ctx.fontVariantLigatures),
        'set-font-variant-ligatures!': ((ctx, v) => { ctx.fontVariantLigatures = from_fasl(v); }),
        'font-variant-numeric':   (ctx => ctx.fontVariantNumeric),
        'set-font-variant-numeric!': ((ctx, v) => { ctx.fontVariantNumeric = from_fasl(v); }),
        'letter-spacing':         (ctx => ctx.letterSpacing),
        'set-letter-spacing!':    ((ctx, v) => { ctx.letterSpacing = from_fasl(v); }),
        'word-spacing':           (ctx => ctx.wordSpacing),
        'set-word-spacing!':      ((ctx, v) => { ctx.wordSpacing = from_fasl(v); }),
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
        'image-data-width': ((data) => data.width),
        'image-data-height': ((data) => data.height),
        'image-data-data': ((data) => data.data),
        'text-metrics-width': ((metrics) => metrics.width),
        'dom-matrix-a': ((matrix) => matrix.a),
        'dom-matrix-b': ((matrix) => matrix.b),
        'dom-matrix-c': ((matrix) => matrix.c),
        'dom-matrix-d': ((matrix) => matrix.d),
        'dom-matrix-e': ((matrix) => matrix.e),
        'dom-matrix-f': ((matrix) => matrix.f),
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
        'width':   (data => data.width),
        'height':  (data => data.height),
        'data':    (data => data.data)
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    'text-metrics': hasDOM ? {
        'width':   (metrics => metrics.width)
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    'dom-matrix': hasDOM ? {
        'a':       (matrix => matrix.a),
        'b':       (matrix => matrix.b),
        'c':       (matrix => matrix.c),
        'd':       (matrix => matrix.d),
        'e':       (matrix => matrix.e),
        'f':       (matrix => matrix.f)
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    // Window
    'window': hasDOM ? {
        'window':               (() => window),
        'self':                 (() => self),
        'document':             (() => document),
        'name':                 (() => window.name),
        'set-name!':            (n => { window.name = from_fasl(n); }),
        'location':             (() => window.location),
        'set-location!':        (loc => { window.location = from_fasl(loc); }),
        'custom-elements':      (() => require_window_value('customElements',
                                                            'window.customElements')),
        'history':              (() => require_window_value('history',
                                                            'window.history')),
        'locationbar':          (() => window.locationbar),
        'menubar':              (() => window.menubar),
        'personalbar':          (() => window.personalbar),
        'scrollbars':           (() => window.scrollbars),
        'statusbar':            (() => window.statusbar),
        'toolbar':              (() => window.toolbar),
        'status':               (() => window.status),
        'set-status!':          (s => { window.status = from_fasl(s); }),
        'closed':               (() => window.closed ? 1 : 0),
        'frames':               (() => window.frames),
        'length':               (() => window.length),
        'opener':               (() => window.opener),
        'set-opener!':          (o => { window.opener = o; }),
        'parent':               (() => window.parent),
        'top':                  (() => window.top),
        'visual-viewport':      (() => require_window_value('visualViewport',
                                                            'window.visualViewport')),
        'navigator':            (() => require_window_value('navigator',
                                                            'window.navigator')),
        'origin':               (() => window.origin),
        'crypto':               (() => require_window_value('crypto',
                                                            'window.crypto')),
        'device-pixel-ratio':   (() => window.devicePixelRatio),
        'event':                (() => window.event),
        'frame-element':        (() => window.frameElement),
        'inner-height':         (() => window.innerHeight),
        'inner-width':          (() => window.innerWidth),
        'outer-height':         (() => window.outerHeight),
        'outer-width':          (() => window.outerWidth),
        'screen-x':             (() => window.screenX),
        'screen-y':             (() => window.screenY),
        'screen-left':          (() => window.screenLeft),
        'screen-top':           (() => window.screenTop),
        'page-x-offset':        (() => window.pageXOffset),
        'page-y-offset':        (() => window.pageYOffset),
        'scroll-x':             (() => window.scrollX),
        'scroll-y':             (() => window.scrollY),
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
        'is-secure-context':    (() => window.isSecureContext ? 1 : 0),
        'cross-origin-isolated':(() => window.crossOriginIsolated ? 1 : 0),
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
        'blur':                 (() => window.blur()),
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
        'event-counts':        (() => performance.eventCounts),
        'interaction-count':   (() => performance.interactionCount),
        'memory':              (() => performance.memory),
        'time-origin':         (() => performance.timeOrigin),
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
        'size':                (list => list.length)
    } : new Proxy({}, { get() { throw new Error('Performance API not available in this environment'); } }),
    'performance-memory-info': hasPerformance ? {
        'js-heap-size-limit':  (mem => mem.jsHeapSizeLimit),
        'total-js-heap-size':  (mem => mem.totalJSHeapSize),
        'used-js-heap-size':   (mem => mem.usedJSHeapSize)
    } : new Proxy({}, { get() { throw new Error('DOM not available in this environment'); } }),
    'websocket': websocket,
    'audio': audio,
    // Document
    'document': hasDOM ? {
        'document':                 (()                               => document),
        'head':                     (()                               => document.head),
        'body':                     (()                               => document.body),
        'document-element':         (()                               => document.documentElement),
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
        'audio-tracks': (m => m.audioTracks),
        'autoplay': (m => m.autoplay ? 1 : 0),
        'set-autoplay!': ((m, flag) => { m.autoplay = !!flag; }),
        'buffered': (m => m.buffered),
        'controls': (m => m.controls ? 1 : 0),
        'set-controls!': ((m, flag) => { m.controls = !!flag; }),
        'controls-list': (m => m.controlsList),
        'cross-origin': (m => to_fasl(m.crossOrigin)),
        'set-cross-origin!': ((m, o) => { m.crossOrigin = from_fasl(o); }),
        'current-src': (m => m.currentSrc),
        'current-time': (m => m.currentTime),
        'set-current-time!': ((m, t) => { m.currentTime = t; }),
        'default-muted': (m => m.defaultMuted ? 1 : 0),
        'set-default-muted!': ((m, flag) => { m.defaultMuted = !!flag; }),
        'default-playback-rate': (m => m.defaultPlaybackRate),
        'set-default-playback-rate!': ((m, r) => { m.defaultPlaybackRate = r; }),
        'disable-remote-playback': (m => m.disableRemotePlayback ? 1 : 0),
        'set-disable-remote-playback!': ((m, flag) => { m.disableRemotePlayback = !!flag; }),
        'duration': (m => m.duration),
        'ended': (m => m.ended ? 1 : 0),
        'error': (m => m.error),
        'loop': (m => m.loop ? 1 : 0),
        'set-loop!': ((m, flag) => { m.loop = !!flag; }),
        'media-keys': (m => m.mediaKeys),
        'media-group': (m => m.mediaGroup),
        'set-media-group!': ((m, g) => { m.mediaGroup = from_fasl(g); }),
        'muted': (m => m.muted ? 1 : 0),
        'set-muted!': ((m, flag) => { m.muted = !!flag; }),
        'network-state': (m => m.networkState),
        'paused': (m => m.paused ? 1 : 0),
        'playback-rate': (m => m.playbackRate),
        'set-playback-rate!': ((m, r) => { m.playbackRate = r; }),
        'played': (m => m.played),
        'preload': (m => m.preload),
        'set-preload!': ((m, p) => { m.preload = from_fasl(p); }),
        'preserves-pitch': (m => m.preservesPitch ? 1 : 0),
        'set-preserves-pitch!': ((m, flag) => { m.preservesPitch = !!flag; }),
        'ready-state': (m => m.readyState),
        'seekable': (m => m.seekable),
        'seeking': (m => m.seeking ? 1 : 0),
        'sink-id': (m => m.sinkId),
        'src': (m => m.src),
        'set-src!': ((m, s) => { m.src = from_fasl(s); }),
        'src-object': (m => m.srcObject),
        'set-src-object!': ((m, obj) => { m.srcObject = obj; }),
        'text-tracks': (m => m.textTracks),
        'video-tracks': (m => m.videoTracks),
        'volume': (m => m.volume),
        'set-volume!': ((m, v) => { m.volume = v; }),
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
        'alt': (img => img.alt),
        'set-alt!': ((img, alt) => { img.alt = from_fasl(alt); }),
        'src': (img => img.src),
        'set-src!': ((img, src) => { img.src = from_fasl(src); }),
        'srcset': (img => img.srcset),
        'set-srcset!': ((img, s) => { img.srcset = from_fasl(s); }),
        'sizes': (img => img.sizes),
        'set-sizes!': ((img, s) => { img.sizes = from_fasl(s); }),
        'cross-origin': (img => to_fasl(img.crossOrigin)),
        'set-cross-origin!': ((img, o) => { img.crossOrigin = from_fasl(o); }),
        'use-map': (img => img.useMap),
        'set-use-map!': ((img, m) => { img.useMap = from_fasl(m); }),
        'is-map': (img => img.isMap ? 1 : 0),
        'set-is-map!': ((img, flag) => { img.isMap = !!flag; }),
        'width': (img => img.width),
        'set-width!': ((img, w) => { img.width = w; }),
        'height': (img => img.height),
        'set-height!': ((img, h) => { img.height = h; }),
        'natural-width': (img => img.naturalWidth),
        'natural-height': (img => img.naturalHeight),
        'complete': (img => img.complete ? 1 : 0),
        'current-src': (img => img.currentSrc),
        'decoding': (img => img.decoding),
        'set-decoding!': ((img, d) => { img.decoding = from_fasl(d); }),
        'fetch-priority': (img => img.fetchPriority),
        'set-fetch-priority!': ((img, p) => { img.fetchPriority = from_fasl(p); }),
        'loading': (img => img.loading),
        'set-loading!': ((img, l) => { img.loading = from_fasl(l); }),
        'referrer-policy': (img => img.referrerPolicy),
        'set-referrer-policy!': ((img, p) => { img.referrerPolicy = from_fasl(p); }),
        'name': (img => img.name),
        'set-name!': ((img, n) => { img.name = from_fasl(n); }),
        'x': (img => img.x),
        'y': (img => img.y),
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
        'type': (evt => evt.type),
        'target': (evt => evt.target),
        'current-target': (evt => evt.currentTarget),
        'event-phase': (evt => evt.eventPhase),
        'bubbles': (evt => evt.bubbles ? 1 : 0),
        'cancelable': (evt => evt.cancelable ? 1 : 0),
        'default-prevented': (evt => evt.defaultPrevented ? 1 : 0),
        'composed': (evt => evt.composed ? 1 : 0),
        'is-trusted': (evt => evt.isTrusted ? 1 : 0),
        'time-stamp': (evt => evt.timeStamp),
        'composed-path': (evt => require_host_function(evt,
                                                        'composedPath',
                                                        'Event.composedPath')()),
        'prevent-default': (evt => require_host_function(evt,
                                                         'preventDefault',
                                                         'Event.preventDefault')()),
        'mouse-offset-x': (evt => evt.offsetX),
        'mouse-offset-y': (evt => evt.offsetY),
        'mouse-client-x': (evt => evt.clientX),
        'mouse-client-y': (evt => evt.clientY),
        'mouse-page-x': (evt => evt.pageX),
        'mouse-page-y': (evt => evt.pageY),
        'mouse-screen-x': (evt => evt.screenX),
        'mouse-screen-y': (evt => evt.screenY),
        'mouse-button': (evt => evt.button),
        'mouse-buttons': (evt => evt.buttons),
        'mouse-alt-key': (evt => evt.altKey ? 1 : 0),
        'mouse-ctrl-key': (evt => evt.ctrlKey ? 1 : 0),
        'mouse-meta-key': (evt => evt.metaKey ? 1 : 0),
        'mouse-shift-key': (evt => evt.shiftKey ? 1 : 0),
        'mouse-event?': (evt => (typeof MouseEvent !== 'undefined') && (evt instanceof MouseEvent)),
        'keyboard-key': (evt => evt.key),
        'keyboard-code': (evt => evt.code),
        'keyboard-event?': (evt => (typeof KeyboardEvent !== 'undefined') && (evt instanceof KeyboardEvent)),
        'alt-key': (evt => evt.altKey ? 1 : 0),
        'ctrl-key': (evt => evt.ctrlKey ? 1 : 0),
        'meta-key': (evt => evt.metaKey ? 1 : 0),
        'shift-key': (evt => evt.shiftKey ? 1 : 0),
        'keyboard-repeat': (evt => evt.repeat ? 1 : 0),
        'pointer-event?': (evt => (typeof PointerEvent !== 'undefined') && (evt instanceof PointerEvent)),
        'focus-event?': (evt => (typeof FocusEvent !== 'undefined') && (evt instanceof FocusEvent)),
        'input-event?': (evt => (typeof InputEvent !== 'undefined') && (evt instanceof InputEvent)),
        'submit-event?': (evt => (typeof SubmitEvent !== 'undefined') && (evt instanceof SubmitEvent)),
        'touch-event?': (evt => (typeof TouchEvent !== 'undefined') && (evt instanceof TouchEvent)),
        'touches': (evt => evt.touches),
        'target-touches': (evt => evt.targetTouches),
        'changed-touches': (evt => evt.changedTouches),
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
        'data': (evt => evt.data),
        'origin': (evt => evt.origin),
        'last-event-id': (evt => evt.lastEventId),
        'source': (evt => evt.source),
        'ports': (evt => evt.ports)
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
        'was-clean': (evt => evt.wasClean ? 1 : 0),
        'code': (evt => evt.code),
        'reason': (evt => evt.reason)
    } : {
        'close-event?'() { throw new Error('DOM not available in this environment'); },
        'was-clean'() { throw new Error('DOM not available in this environment'); },
        'code'() { throw new Error('DOM not available in this environment'); },
        'reason'() { throw new Error('DOM not available in this environment'); }
    },
    // TouchList
    'touch-list': hasDOM ? {
        'touch-list?': (xs => (typeof TouchList !== 'undefined') && (xs instanceof TouchList)),
        'length': (xs => xs.length),
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
        'identifier': (t => t.identifier),
        'client-x': (t => t.clientX),
        'client-y': (t => t.clientY),
        'page-x': (t => t.pageX),
        'page-y': (t => t.pageY),
        'screen-x': (t => t.screenX),
        'screen-y': (t => t.screenY)
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
        'left':   (rect => rect.left),
        'top':    (rect => rect.top),
        'width':  (rect => rect.width),
        'height': (rect => rect.height)
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
        'class-list':              (elem => elem.classList),
        'id':                      (elem => elem.id),
        'set-id!':                 ((elem, id) => { elem.id = from_fasl(id); }),
        'class-name':              (elem => elem.className),
        'set-class-name!':         ((elem, name) => { elem.className = from_fasl(name); }),
        'tag-name':                (elem => elem.tagName),
        'local-name':              (elem => elem.localName),
        'namespace-uri':           (elem => elem.namespaceURI),
        'prefix':                  (elem => elem.prefix),
        'is-connected':            (elem => elem.isConnected ? 1 : 0),
        'children':                (elem => elem.children),
        'scroll-top':              (elem => elem.scrollTop),
        'set-scroll-top!':         ((elem, value) => { elem.scrollTop = from_fasl(value); }),
        'scroll-left':             (elem => elem.scrollLeft),
        'set-scroll-left!':        ((elem, value) => { elem.scrollLeft = from_fasl(value); }),
        'scroll-width':            (elem => elem.scrollWidth),
        'scroll-height':           (elem => elem.scrollHeight),
        'client-width':            (elem => elem.clientWidth),
        'client-height':           (elem => elem.clientHeight),
        'offset-width':            (elem => elem.offsetWidth),
        'offset-height':           (elem => elem.offsetHeight),
        'child-element-count':      (elem => elem.childElementCount),
        'first-element-child':     (elem => elem.firstElementChild),
        'last-element-child':      (elem => elem.lastElementChild),
        'parent-element':          (elem => elem.parentElement),
        'previous-element-sibling': (elem => elem.previousElementSibling),
        'next-element-sibling':    (elem => elem.nextElementSibling),
        'inner-html':              (elem => elem.innerHTML),
        'set-inner-html!':         ((elem, html) => { elem.innerHTML = from_fasl(html); }),
        'outer-html':              (elem => elem.outerHTML),
        'set-outer-html!':         ((elem, html) => { elem.outerHTML = from_fasl(html); }),
        'text-content':            (elem => elem.textContent),
        'set-text-content!':       ((elem, text) => { elem.textContent = from_fasl(text); }),
        'shadow-root':             (elem => elem.shadowRoot),
        'dom-token-list-value':    (list => list.value),
        'dom-token-list-length':   (list => list.length),
        'dom-token-list-item':     ((list, index)         => require_host_function(list,
                                                                                   'item',
                                                                                   'DOMTokenList.item')(index)),
        'node-list-length':       (list => list.length),
        'node-list-item':         ((list, index)         => require_host_function(list,
                                                                                 'item',
                                                                                 'NodeList.item')(index)),
        'html-collection-length': (list => list.length),
        'html-collection-item':   ((list, index)         => require_host_function(list,
                                                                                 'item',
                                                                                 'HTMLCollection.item')(index)),
        'html-collection-named-item': ((list, name)      => require_host_function(list,
                                                                                  'namedItem',
                                                                                  'HTMLCollection.namedItem')(from_fasl(name))),
        'shadow-root-host':       (root => root.host),
        'shadow-root-mode':       (root => root.mode),
        'shadow-root-delegates-focus': (root => root.delegatesFocus ? 1 : 0),
        'dom-rect-list-length':   (list => list.length),
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
        'buffer': (term => term.buffer),
        'cols': (term => term.cols),
        'rows': (term => term.rows),
        'element': (term => term.element),
        'textarea': (term => term.textarea),
        'markers':  (term => term.markers),
        'modes':    (term => term.modes),
        'options': (term => term.options),
        'set-options!': ((term, options) => {
            const opts = from_fasl(options);
            if (opts !== undefined) {
                term.options = opts;
            }
        }),
        'parser': (term => term.parser),
        'unicode': (term => term.unicode),
        'on-bell': (term => term.onBell),
        'on-binary': (term => term.onBinary),
        'on-cursor-move': (term => term.onCursorMove),
        'on-data': (term => term.onData),
        'on-key': (term => term.onKey),
        'on-line-feed': (term => term.onLineFeed),
        'on-render': (term => term.onRender),
        'on-resize': (term => term.onResize),
        'on-scroll': (term => term.onScroll),
        'on-selection-change': (term => term.onSelectionChange),
        'on-title-change': (term => term.onTitleChange),
        'on-write-parsed': (term => term.onWriteParsed),
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
        'create':                    ((board, elementType, parents, attrs) => board.create(from_fasl(elementType), from_fasl(parents), from_fasl(attrs))),
        'create-point':              ((board, parents, attrs) => board.create('point', from_fasl(parents), from_fasl(attrs))),
        'create-line':               ((board, parents, attrs) => board.create('line', from_fasl(parents), from_fasl(attrs))),
        'create-segment':            ((board, parents, attrs) => board.create('segment', from_fasl(parents), from_fasl(attrs))),
        'create-arc':                ((board, parents, attrs) => board.create('arc', from_fasl(parents), from_fasl(attrs))),
        'create-angle':              ((board, parents, attrs) => board.create('angle', from_fasl(parents), from_fasl(attrs))),
        'create-sector':             ((board, parents, attrs) => board.create('sector', from_fasl(parents), from_fasl(attrs))),
        'create-glider':             ((board, parents, attrs) => board.create('glider', from_fasl(parents), from_fasl(attrs))),
        'create-circle':             ((board, parents, attrs) => board.create('circle', from_fasl(parents), from_fasl(attrs))),
        'create-conic':              ((board, parents, attrs) => board.create('conic', from_fasl(parents), from_fasl(attrs))),
        'create-ellipse':            ((board, parents, attrs) => board.create('ellipse', from_fasl(parents), from_fasl(attrs))),
        'create-curve':              ((board, parents, attrs) => board.create('curve', from_fasl(parents), from_fasl(attrs))),
        'create-functiongraph':      ((board, parents, attrs) => board.create('functiongraph', from_fasl(parents), from_fasl(attrs))),
        'create-polygon':            ((board, parents, attrs) => board.create('polygon', from_fasl(parents), from_fasl(attrs))),
        'create-midpoint':           ((board, parents, attrs) => board.create('midpoint', from_fasl(parents), from_fasl(attrs))),
        'create-parallel':           ((board, parents, attrs) => board.create('parallel', from_fasl(parents), from_fasl(attrs))),
        'create-arrowparallel':      ((board, parents, attrs) => board.create('arrowparallel', from_fasl(parents), from_fasl(attrs))),
        'create-axis':               ((board, parents, attrs) => board.create('axis', from_fasl(parents), from_fasl(attrs))),
        'create-grid':               ((board, parents, attrs) => board.create('grid', from_fasl(parents), from_fasl(attrs))),
        'create-boxplot':            ((board, parents, attrs) => board.create('boxplot', from_fasl(parents), from_fasl(attrs))),
        'create-tangent':            ((board, parents, attrs) => board.create('tangent', from_fasl(parents), from_fasl(attrs))),
        'create-tangentto':          ((board, parents, attrs) => board.create('tangentto', from_fasl(parents), from_fasl(attrs))),
        'create-polarline':          ((board, parents, attrs) => board.create('polarline', from_fasl(parents), from_fasl(attrs))),
        'create-polepoint':          ((board, parents, attrs) => board.create('polepoint', from_fasl(parents), from_fasl(attrs))),
        'create-radicalaxis':        ((board, parents, attrs) => board.create('radicalaxis', from_fasl(parents), from_fasl(attrs))),
        'create-circumcircle':       ((board, parents, attrs) => board.create('circumcircle', from_fasl(parents), from_fasl(attrs))),
        'create-incircle':           ((board, parents, attrs) => board.create('incircle', from_fasl(parents), from_fasl(attrs))),
        'create-incenter':           ((board, parents, attrs) => board.create('incenter', from_fasl(parents), from_fasl(attrs))),
        'create-minorarc':           ((board, parents, attrs) => board.create('minorarc', from_fasl(parents), from_fasl(attrs))),
        'create-minorsector':        ((board, parents, attrs) => board.create('minorsector', from_fasl(parents), from_fasl(attrs))),
        'create-circumcirclearc':    ((board, parents, attrs) => board.create('circumcirclearc', from_fasl(parents), from_fasl(attrs))),
        'create-circumcirclesector': ((board, parents, attrs) => board.create('circumcirclesector', from_fasl(parents), from_fasl(attrs))),
        'create-semicircle':         ((board, parents, attrs) => board.create('semicircle', from_fasl(parents), from_fasl(attrs))),
        'create-majorarc':           ((board, parents, attrs) => board.create('majorarc', from_fasl(parents), from_fasl(attrs))),
        'create-majorsector':        ((board, parents, attrs) => board.create('majorsector', from_fasl(parents), from_fasl(attrs))),
        'create-curveintersection':  ((board, parents, attrs) => board.create('curveintersection', from_fasl(parents), from_fasl(attrs))),
        'create-curvedifference':    ((board, parents, attrs) => board.create('curvedifference', from_fasl(parents), from_fasl(attrs))),
        'create-curveunion':         ((board, parents, attrs) => board.create('curveunion', from_fasl(parents), from_fasl(attrs))),
        'create-derivative':         ((board, parents, attrs) => board.create('derivative', from_fasl(parents), from_fasl(attrs))),
        'create-integral':           ((board, parents, attrs) => board.create('integral', from_fasl(parents), from_fasl(attrs))),
        'create-riemannsum':         ((board, parents, attrs) => board.create('riemannsum', from_fasl(parents), from_fasl(attrs))),
        'create-slopefield':         ((board, parents, attrs) => board.create('slopefield', from_fasl(parents), from_fasl(attrs))),
        'create-vectorfield':        ((board, parents, attrs) => board.create('vectorfield', from_fasl(parents), from_fasl(attrs))),
        'create-implicitcurve':      ((board, parents, attrs) => board.create('implicitcurve', from_fasl(parents), from_fasl(attrs))),
        'create-spline':             ((board, parents, attrs) => board.create('spline', from_fasl(parents), from_fasl(attrs))),
        'create-cardinalspline':     ((board, parents, attrs) => board.create('cardinalspline', from_fasl(parents), from_fasl(attrs))),
        'create-comb':               ((board, parents, attrs) => board.create('comb', from_fasl(parents), from_fasl(attrs))),
        'create-metapostspline':     ((board, parents, attrs) => board.create('metapostspline', from_fasl(parents), from_fasl(attrs))),
        'create-polygonalchain':     ((board, parents, attrs) => board.create('polygonalchain', from_fasl(parents), from_fasl(attrs))),
        'create-regularpolygon':     ((board, parents, attrs) => board.create('regularpolygon', from_fasl(parents), from_fasl(attrs))),
        'create-hyperbola':          ((board, parents, attrs) => board.create('hyperbola', from_fasl(parents), from_fasl(attrs))),
        'create-parabola':           ((board, parents, attrs) => board.create('parabola', from_fasl(parents), from_fasl(attrs))),
        'create-stepfunction':       ((board, parents, attrs) => board.create('stepfunction', from_fasl(parents), from_fasl(attrs))),
        'create-inequality':         ((board, parents, attrs) => board.create('inequality', from_fasl(parents), from_fasl(attrs))),
        'create-turtle':             ((board, parents, attrs) => board.create('turtle', from_fasl(parents), from_fasl(attrs))),
        'create-nonreflexangle':     ((board, parents, attrs) => board.create('nonreflexangle', from_fasl(parents), from_fasl(attrs))),
        'create-perpendicular':      ((board, parents, attrs) => board.create('perpendicular', from_fasl(parents), from_fasl(attrs))),
        'create-reflection':         ((board, parents, attrs) => board.create('reflection', from_fasl(parents), from_fasl(attrs))),
        'create-bisector':           ((board, parents, attrs) => board.create('bisector', from_fasl(parents), from_fasl(attrs))),
        'create-normal':             ((board, parents, attrs) => board.create('normal', from_fasl(parents), from_fasl(attrs))),
        'create-intersection':       ((board, parents, attrs) => board.create('intersection', from_fasl(parents), from_fasl(attrs))),
        'create-arrow':              ((board, parents, attrs) => board.create('arrow', from_fasl(parents), from_fasl(attrs))),
        'create-button':             ((board, parents, attrs) => board.create('button', from_fasl(parents), from_fasl(attrs))),
        'create-checkbox':           ((board, parents, attrs) => board.create('checkbox', from_fasl(parents), from_fasl(attrs))),
        'create-input':              ((board, parents, attrs) => board.create('input', from_fasl(parents), from_fasl(attrs))),
        'create-slider':             ((board, parents, attrs) => board.create('slider', from_fasl(parents), from_fasl(attrs))),
        'create-chart':              ((board, parents, attrs) => board.create('chart', from_fasl(parents), from_fasl(attrs))),
        'create-legend':             ((board, parents, attrs) => board.create('legend', from_fasl(parents), from_fasl(attrs))),
        'create-smartlabel':         ((board, parents, attrs) => board.create('smartlabel', from_fasl(parents), from_fasl(attrs))),
        'create-foreignobject':      ((board, parents, attrs) => board.create('foreignobject', from_fasl(parents), from_fasl(attrs))),
        'create-tapemeasure':        ((board, parents, attrs) => board.create('tapemeasure', from_fasl(parents), from_fasl(attrs))),
        'create-ticks':              ((board, parents, attrs) => board.create('ticks', from_fasl(parents), from_fasl(attrs))),
        'create-hatch':              ((board, parents, attrs) => board.create('hatch', from_fasl(parents), from_fasl(attrs))),
        'create-transformation':     ((board, parents, attrs) => board.create('transform', from_fasl(parents), from_fasl(attrs))),
        'create-tracecurve':         ((board, parents, attrs) => board.create('tracecurve', from_fasl(parents), from_fasl(attrs))),
        'create-slopetriangle':      ((board, parents, attrs) => board.create('slopetriangle', from_fasl(parents), from_fasl(attrs))),
        'create-parallelogram':      ((board, parents, attrs) => board.create('parallelogram', from_fasl(parents), from_fasl(attrs))),
        'create-reflexangle':        ((board, parents, attrs) => board.create('reflexangle', from_fasl(parents), from_fasl(attrs))),
        'create-measurement':        ((board, parents, attrs) => board.create('measurement', from_fasl(parents), from_fasl(attrs))),
        'create-circumcenter':       ((board, parents, attrs) => board.create('circumcenter', from_fasl(parents), from_fasl(attrs))),
        'create-mirrorelement':      ((board, parents, attrs) => board.create('mirrorelement', from_fasl(parents), from_fasl(attrs))),
        'create-text':               ((board, parents, attrs) => board.create('text', from_fasl(parents), from_fasl(attrs))),
        'create-image':              ((board, parents, attrs) => board.create('image', from_fasl(parents), from_fasl(attrs))),
        'create-group':              ((board, parents, attrs) => board.create('group', from_fasl(parents), from_fasl(attrs))),
        'create-bisectorlines':      ((board, parents, attrs) => board.create('bisectorlines', from_fasl(parents), from_fasl(attrs))),
        'create-perpendicularsegment': ((board, parents, attrs) => board.create('perpendicularsegment', from_fasl(parents), from_fasl(attrs))),
        'add-grid!':                 (board => { board.addGrid(); }),
        'remove-grids!':             (board => { board.removeGrids(); }),
        'add-animation!':            ((board, element) => { board.addAnimation(from_fasl(element)); }),
        'add-conditions!':           ((board, str) => { board.addConditions(from_fasl(str)); }),
        'add-event-handlers!':       (board => { board.addEventHandlers(); }),
        'add-fullscreen-event-handlers!': (board => { board.addFullscreenEventHandlers(); }),
        'add-hook!':                 ((board, hook, m, context) => board.addHook(hook, from_fasl(m), from_fasl(context))),
        'add-keyboard-event-handlers!': (board => { board.addKeyboardEventHandlers(); }),
        'add-mouse-event-handlers!': (board => { board.addMouseEventHandlers(); }),
        'add-pointer-event-handlers!': (board => { board.addPointerEventHandlers(); }),
        'add-resize-event-handlers!': (board => { board.addResizeEventHandlers(); }),
        'add-touch-event-handlers!': ((board, appleGestures) => { board.addTouchEventHandlers(from_fasl(appleGestures)); }),
        'add-wheel-event-handlers!': (board => { board.addWheelEventHandlers(); }),
        'add-child!':               ((board, child) => { board.addChild(from_fasl(child)); }),
        'apply-zoom!':              (board => { board.applyZoom(); }),
        'calculate-snap-sizes!':    (board => { board.calculateSnapSizes(); }),
        'clear-traces!':            (board => { board.clearTraces(); }),
        'create-roulette!':         ((board, c1, c2, startC1, stepsize, direction, time, pointlist) =>
                                      board.createRoulette(from_fasl(c1), from_fasl(c2), from_fasl(startC1),
                                                           from_fasl(stepsize), from_fasl(direction),
                                                           from_fasl(time), from_fasl(pointlist))),
        'dehighlight-all!':         (board => { board.dehighlightAll(); }),
        'finalize-adding!':         ((board, obj) => { board.finalizeAdding(from_fasl(obj)); }),
        'generate-id':              (board => board.generateId()),
        'generate-name':            ((board, object) => board.generateName(from_fasl(object))),
        'get-all-objects-under-mouse': ((board, evt) => board.getAllObjectsUnderMouse(from_fasl(evt))),
        'get-all-under-mouse':      ((board, evt) => board.getAllUnderMouse(from_fasl(evt))),
        'get-bounding-box':         (board => board.getBoundingBox()),
        'get-coords-top-left-corner': (board => board.getCoordsTopLeftCorner()),
        'get-mouse-position':       ((board, evt) => board.getMousePosition(from_fasl(evt))),
        'get-mouse-position/index':  ((board, evt, i) => board.getMousePosition(from_fasl(evt), from_fasl(i))),
        'get-scr-coords-of-mouse':  ((board, x, y) => board.getScrCoordsOfMouse(from_fasl(x), from_fasl(y))),
        'get-usr-coords-of-mouse':  ((board, evt) => board.getUsrCoordsOfMouse(from_fasl(evt))),
        'has-point!':               ((board, x, y) => board.hasPoint(from_fasl(x), from_fasl(y))),
        'highlight-custom-infobox!': ((board, text) => { board.highlightCustomInfobox(from_fasl(text)); }),
        'highlight-custom-infobox/element!': ((board, text, el) => { board.highlightCustomInfobox(from_fasl(text), from_fasl(el)); }),
        'highlight-infobox!':       ((board, x, y) => { board.highlightInfobox(from_fasl(x), from_fasl(y)); }),
        'highlight-infobox/element!': ((board, x, y, el) => { board.highlightInfobox(from_fasl(x), from_fasl(y), from_fasl(el)); }),
        'init-geonext-board!':      (board => { board.initGeonextBoard(); }),
        'init-infobox!':            ((board, attributes) => { board.initInfobox(from_fasl(attributes)); }),
        'init-move-object!':        ((board, x, y, evt, type) => { board.initMoveObject(from_fasl(x), from_fasl(y), from_fasl(evt), from_fasl(type)); }),
        'init-move-origin!':        ((board, x, y) => { board.initMoveOrigin(from_fasl(x), from_fasl(y)); }),
        'move-object!':             ((board, x, y, o, evt, type) => { board.moveObject(from_fasl(x), from_fasl(y), from_fasl(o), from_fasl(evt), from_fasl(type)); }),
        'move-origin!':             ((board, x, y, diff) => { board.moveOrigin(from_fasl(x), from_fasl(y), from_fasl(diff)); }),
        'off':                      ((board, event, handler) => { board.off(from_fasl(event), from_fasl(handler)); }),
        'on':                       ((board, event, handler) => { board.on(from_fasl(event), from_fasl(handler)); }),
        'remove-event-handlers!':   (board => { board.removeEventHandlers(); }),
        'remove-hook!':             ((board, id) => { board.removeHook(from_fasl(id)); }),
        'remove-keyboard-event-handlers!': (board => { board.removeKeyboardEventHandlers(); }),
        'remove-mouse-event-handlers!': (board => { board.removeMouseEventHandlers(); }),
        'remove-pointer-event-handlers!': (board => { board.removePointerEventHandlers(); }),
        'remove-resize-event-handlers!': (board => { board.removeResizeEventHandlers(); }),
        'remove-touch-event-handlers!': (board => { board.removeTouchEventHandlers(); }),
        'resize-container!':        ((board, width, height, dontset, dontSetBoundingBox) =>
                                      { board.resizeContainer(from_fasl(width), from_fasl(height), from_fasl(dontset), from_fasl(dontSetBoundingBox)); }),
        'select':                   ((board, str, onlyByIdOrName) => board.select(from_fasl(str), from_fasl(onlyByIdOrName))),
        'set-attribute!':           ((board, attributes) => { board.setAttribute(from_fasl(attributes)); }),
        'set-bounding-box!':        ((board, bbox, keepaspectratio, setZoom) => { board.setBoundingBox(from_fasl(bbox), from_fasl(keepaspectratio), from_fasl(setZoom)); }),
        'set-id!':                  ((board, obj, type) => { board.setId(from_fasl(obj), from_fasl(type)); }),
        'set-zoom!':                ((board, fX, fY) => { board.setZoom(from_fasl(fX), from_fasl(fY)); }),
        'show-dependencies!':       (board => { board.showDependencies(); }),
        'show-xml!':                (board => { board.showXML(); }),
        'start-intersection-observer!': (board => { board.startIntersectionObserver(); }),
        'start-resize-observer!':   (board => { board.startResizeObserver(); }),
        'start-selection-mode!':    (board => { board.startSelectionMode(); }),
        'stop-all-animation!':      (board => { board.stopAllAnimation(); }),
        'stop-intersection-observer!': (board => { board.stopIntersectionObserver(); }),
        'stop-resize-observer!':    (board => { board.stopResizeObserver(); }),
        'stop-selection-mode!':     (board => { board.stopSelectionMode(); }),
        'suppress-default!':        ((board, e) => { board.suppressDefault(from_fasl(e)); }),
        'to-fullscreen!':           ((board, id) => { board.toFullscreen(from_fasl(id)); }),
        'update-conditions!':       (board => { board.updateConditions(); }),
        'update-container-dims!':   (board => { board.updateContainerDims(); }),
        'update-container-dims/size!': ((board, width, height) => { board.updateContainerDims(from_fasl(width), from_fasl(height)); }),
        'update-coords!':           (board => { board.updateCoords(); }),
        'update-csstransforms!':    (board => { board.updateCSSTransforms(); }),
        'update-elements!':         ((board, drag) => { board.updateElements(from_fasl(drag)); }),
        'update-hooks!':            ((board, m) => { board.updateHooks(from_fasl(m)); }),
        'update-infobox!':          ((board, el) => { board.updateInfobox(from_fasl(el)); }),
        'update-renderer!':         (board => { board.updateRenderer(); }),
        'update-renderer-canvas!':  (board => { board.updateRendererCanvas(); }),
        'zoom-all-points!':         (board => { board.zoomAllPoints(); }),
        'zoom-elements!':           ((board, elements) => { board.zoomElements(from_fasl(elements)); }),
        'zoom-in!':                 ((board, x, y) => { board.zoomIn(from_fasl(x), from_fasl(y)); }),
        'zoom-out!':                ((board, x, y) => { board.zoomOut(from_fasl(x), from_fasl(y)); }),
        'zoom100!':                 (board => { board.zoom100(); }),
        'id':                        (board => board.id),
        'container':                 (board => board.container),
        'renderer':                  (board => board.renderer),
        'canvas-width':              (board => board.canvasWidth),
        'canvas-height':             (board => board.canvasHeight),
        'bounding-box':              (board => board.boundingBox),
        'update!':                   (board => board.update()),
        'full-update!':              (board => board.fullUpdate()),
        'remove-object!':            ((board, obj) => { board.removeObject(obj); }),
        'suspend-update!':           (board => board.suspendUpdate()),
        'unsuspend-update!':         (board => board.unsuspendUpdate()),
        'num-objects':               (board => board.numObjects),
        'objects-list':              (board => Object.values(board.objects))
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
        'add-event': ((element, type, listener) => element.addEvent(from_fasl(type), listener))
    } : {
        'call'()                      { throw new Error('DOM not available in this environment'); },
        'call/nullish'()              { throw new Error('DOM not available in this environment'); },
        'add-event'()                 { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Text
    'jsx-text': hasDOM ? {
        '_createFctUpdateText': ((text, args) => text._createFctUpdateText(...from_fasl(args))),
        '_setText':              ((text, args) => text._setText(...from_fasl(args))),
        'bounds':                ((text, args) => text.bounds(...from_fasl(args))),
        'checkForSizeUpdate':    ((text, args) => text.checkForSizeUpdate(...from_fasl(args))),
        'convertGeonext2CSS':    ((text, args) => text.convertGeonext2CSS(...from_fasl(args))),
        'convertGeonextAndSketchometry2CSS': ((text, args) => text.convertGeonextAndSketchometry2CSS(...from_fasl(args))),
        'convertSketchometry2CSS': ((text, args) => text.convertSketchometry2CSS(...from_fasl(args))),
        'crudeSizeEstimate':     ((text, args) => text.crudeSizeEstimate(...from_fasl(args))),
        'escapeTicks':           ((text, args) => text.escapeTicks(...from_fasl(args))),
        'expandShortMath':       ((text, args) => text.expandShortMath(...from_fasl(args))),
        'generateTerm':          ((text, args) => text.generateTerm(...from_fasl(args))),
        'getAnchorX':            ((text, args) => text.getAnchorX(...from_fasl(args))),
        'getAnchorY':            ((text, args) => text.getAnchorY(...from_fasl(args))),
        'getNumberOfConflicts':  ((text, args) => text.getNumberOfConflicts(...from_fasl(args))),
        'getSize':               ((text, args) => text.getSize(...from_fasl(args))),
        'hasPoint':              ((text, args) => text.hasPoint(...from_fasl(args))),
        'notifyParents':         ((text, args) => text.notifyParents(...from_fasl(args))),
        'poorMansTeX':           ((text, args) => text.poorMansTeX(...from_fasl(args))),
        'replaceSub':            ((text, args) => text.replaceSub(...from_fasl(args))),
        'replaceSup':            ((text, args) => text.replaceSup(...from_fasl(args))),
        'setAutoPosition':       ((text, args) => text.setAutoPosition(...from_fasl(args))),
        'setCoords':             ((text, args) => text.setCoords(...from_fasl(args))),
        'setText':               ((text, args) => text.setText(...from_fasl(args))),
        'setTextJessieCode':     ((text, args) => text.setTextJessieCode(...from_fasl(args))),
        'unescapeTicks':         ((text, args) => text.unescapeTicks(...from_fasl(args))),
        'updateSize':            ((text, args) => text.updateSize(...from_fasl(args))),
        'updateText':            ((text, args) => text.updateText(...from_fasl(args))),
        'utf8_decode':           ((text, args) => text.utf8_decode(...from_fasl(args))),
        'valueTagToJessieCode':  ((text, args) => text.valueTagToJessieCode(...from_fasl(args)))
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
        'H':                        (foreignobject => foreignobject.H()),
        'W':                        (foreignobject => foreignobject.W()),
        'hasPoint':                 ((foreignobject, x, y) => foreignobject.hasPoint(from_fasl(x), from_fasl(y))),
        'setSize':                  ((foreignobject, width, height) => foreignobject.setSize(from_fasl(width), from_fasl(height))),
        'update':                   (foreignobject => foreignobject.update()),
        'updateRenderer':           (foreignobject => foreignobject.updateRenderer()),
        'updateSize':               (foreignobject => foreignobject.updateSize()),
        'updateSpan':               (foreignobject => foreignobject.updateSpan())
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
        'Value':                    (tapemeasure => tapemeasure.Value())
    } : {
        'Value'()                   { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Ticks
    'jsx-ticks': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('ticks', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Transformation
    'jsx-transformation': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('transform', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Tracecurve
    'jsx-tracecurve': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('tracecurve', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Parallelogram
    'jsx-parallelogram': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('parallelogram', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph ReflexAngle
    'jsx-reflexangle': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('reflexangle', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Point Relation Helpers
    'jsx-mirrorpoint': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('mirrorpoint', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    'jsx-otherintersection': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('otherintersection', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    'jsx-orthogonalprojection': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('orthogonalprojection', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    'jsx-parallelpoint': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('parallelpoint', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    'jsx-perpendicularpoint': hasDOM ? {
        'create':                   ((board, parents, attrs) => board.create('perpendicularpoint', from_fasl(parents), from_fasl(attrs)))
    } : {
        'create'()                  { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Checkbox
    'jsx-checkbox': hasDOM ? {
        'Value':           ((checkbox, args) => checkbox.Value(...from_fasl(args)))
    } : {
        'Value'()          { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Input
    'jsx-input': hasDOM ? {
        'set':   ((input, args) => input.set(...from_fasl(args))),
        'Value': ((input, args) => input.Value(...from_fasl(args)))
    } : {
        'set'()   { throw new Error('DOM not available in this environment'); },
        'Value'() { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Slider
    'jsx-slider': hasDOM ? {
        'setMax':   ((slider, args) => slider.setMax(...from_fasl(args))),
        'setMin':   ((slider, args) => slider.setMin(...from_fasl(args))),
        'setValue': ((slider, args) => slider.setValue(...from_fasl(args))),
        'Value':    ((slider, args) => slider.Value(...from_fasl(args)))
    } : {
        'setMax'()   { throw new Error('DOM not available in this environment'); },
        'setMin'()   { throw new Error('DOM not available in this environment'); },
        'setValue'() { throw new Error('DOM not available in this environment'); },
        'Value'()    { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Chart
    'jsx-chart': hasDOM ? {
        'drawBar':       ((chart, args) => chart.drawBar(...from_fasl(args))),
        'drawFit':       ((chart, args) => chart.drawFit(...from_fasl(args))),
        'drawLine':      ((chart, args) => chart.drawLine(...from_fasl(args))),
        'drawPie':       ((chart, args) => chart.drawPie(...from_fasl(args))),
        'drawPoints':    ((chart, args) => chart.drawPoints(...from_fasl(args))),
        'drawRadar':     ((chart, args) => chart.drawRadar(...from_fasl(args))),
        'drawSpline':    ((chart, args) => chart.drawSpline(...from_fasl(args))),
        'updateDataArray': ((chart, args) => chart.updateDataArray(...from_fasl(args))),
        'updateRenderer':  ((chart, args) => chart.updateRenderer(...from_fasl(args)))
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
        'H':              ((image, args) => image.H(...from_fasl(args))),
        'W':              ((image, args) => image.W(...from_fasl(args))),
        'hasPoint':       ((image, args) => image.hasPoint(...from_fasl(args))),
        'setSize':        ((image, args) => image.setSize(...from_fasl(args))),
        'update':         ((image, args) => image.update(...from_fasl(args))),
        'updateRenderer': ((image, args) => image.updateRenderer(...from_fasl(args))),
        'updateSize':     ((image, args) => image.updateSize(...from_fasl(args))),
        'updateSpan':     ((image, args) => image.updateSpan(...from_fasl(args)))
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
        'addParents':          ((group, args) => group.addParents(...from_fasl(args))),
        'addPoint':            ((group, args) => group.addPoint(...from_fasl(args))),
        'addPoints':           ((group, args) => group.addPoints(...from_fasl(args))),
        'addRotationPoint':    ((group, args) => group.addRotationPoint(...from_fasl(args))),
        'addScalePoint':       ((group, args) => group.addScalePoint(...from_fasl(args))),
        'addTranslationPoint': ((group, args) => group.addTranslationPoint(...from_fasl(args))),
        'addGroup':            ((group, args) => group.addGroup(...from_fasl(args))),
        'removePoint':         ((group, args) => group.removePoint(...from_fasl(args))),
        'removeRotationPoint': ((group, args) => group.removeRotationPoint(...from_fasl(args))),
        'removeScalePoint':    ((group, args) => group.removeScalePoint(...from_fasl(args))),
        'removeTranslationPoint': ((group, args) => group.removeTranslationPoint(...from_fasl(args))),
        'setParents':          ((group, args) => group.setParents(...from_fasl(args))),
        'setRotationCenter':   ((group, args) => group.setRotationCenter(...from_fasl(args))),
        'setRotationPoints':   ((group, args) => group.setRotationPoints(...from_fasl(args))),
        'setScaleCenter':      ((group, args) => group.setScaleCenter(...from_fasl(args))),
        'setScalePoints':      ((group, args) => group.setScalePoints(...from_fasl(args))),
        'setTranslationPoints': ((group, args) => group.setTranslationPoints(...from_fasl(args))),
        'ungroup':             (group => group.ungroup()),
        'update':              (group => group.update())
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
        'get-radius':                 (arc => arc.getRadius()),
        'has-point-sector':           ((arc, x, y) => arc.hasPointSector(x, y)),
        'radius':                     (arc => arc.Radius()),
        'value':                      ((arc, unit, rad) => arc.Value(from_fasl(unit), from_fasl(rad)))
    } : {
        'get-radius'()                { throw new Error('DOM not available in this environment'); },
        'has-point-sector'()          { throw new Error('DOM not available in this environment'); },
        'radius'()                    { throw new Error('DOM not available in this environment'); },
        'value'()                     { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Angle
    'jsx-angle': hasDOM ? {
        'free':                       (angle => angle.free()),
        'set-angle!':                 ((angle, val) => { angle.setAngle(from_fasl(val)); }),
        'value':                      ((angle, unit) => angle.Value(from_fasl(unit)))
    } : {
        'free'()                      { throw new Error('DOM not available in this environment'); },
        'set-angle!'()                { throw new Error('DOM not available in this environment'); },
        'value'()                     { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Sector
    'jsx-sector': hasDOM ? {
        'area':                       (sector => sector.Area()),
        'has-point-sector':           ((sector, x, y) => sector.hasPointSector(x, y)),
        'l':                          (sector => sector.L()),
        'perimeter':                  (sector => sector.Perimeter()),
        'radius':                     (sector => sector.Radius()),
        'set-position-directly!':     ((sector, method, coords, oldcoords) => sector.setPositionDirectly(from_fasl(method), from_fasl(coords), from_fasl(oldcoords))),
        'set-radius!':                ((sector, value) => sector.setRadius(from_fasl(value)))
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
        'start-animation!':          ((glider, direction, stepCount, delay) => glider.startAnimation(from_fasl(direction), from_fasl(stepCount), from_fasl(delay))),
        'stop-animation!':           ((glider) => glider.stopAnimation())
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
        'Value': ((riemannsum) => riemannsum.Value())
    } : {
        'Value'()                     { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Slopefield
    'jsx-slopefield': hasDOM ? {
        'setF': ((field, func) => field.setF(from_fasl(func)))
    } : {
        'setF'()                      { throw new Error('DOM not available in this environment'); }
    },
    // JSXGraph Vectorfield
    'jsx-vectorfield': hasDOM ? {
        'setF': ((field, func) => field.setF(from_fasl(func)))
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
        'attractor-distance':          (pt => pt.attractorDistance),
        'set-attractor-distance!':     ((pt, d) => { pt.attractorDistance = d; }),
        'attractors':                  (pt => pt.attractors),
        'set-attractors!':             ((pt, a) => { pt.attractors = a; }),
        'attractor-unit':              (pt => pt.attractorUnit),
        'set-attractor-unit!':         ((pt, u) => { pt.attractorUnit = from_fasl(u); }),
        'attract-to-grid':             (pt => pt.attractToGrid ? 1 : 0),
        'set-attract-to-grid!':        ((pt, flag) => { pt.attractToGrid = !!flag; }),
        'face':                        (pt => pt.face),
        'set-face!':                   ((pt, f) => { pt.face = from_fasl(f); }),
        'ignored-snap-to-points':      (pt => pt.ignoredSnapToPoints),
        'set-ignored-snap-to-points!': ((pt, p) => { pt.ignoredSnapToPoints = p; }),
        'infobox-digits':              (pt => pt.infoboxDigits),
        'set-infobox-digits!':         ((pt, n) => { pt.infoboxDigits = n; }),
        'show-infobox':                (pt => pt.showInfobox ? 1 : 0),
        'set-show-infobox!':           ((pt, flag) => { pt.showInfobox = !!flag; }),
        'size':                        (pt => pt.size),
        'set-size!':                   ((pt, s) => { pt.size = s; }),
        'size-unit':                   (pt => pt.sizeUnit),
        'set-size-unit!':              ((pt, u) => { pt.sizeUnit = from_fasl(u); }),
        'snap-size-x':                 (pt => pt.snapSizeX),
        'set-snap-size-x!':            ((pt, x) => { pt.snapSizeX = x; }),
        'snap-size-y':                 (pt => pt.snapSizeY),
        'set-snap-size-y!':            ((pt, y) => { pt.snapSizeY = y; }),
        'snap-to-grid':                (pt => pt.snapToGrid ? 1 : 0),
        'set-snap-to-grid!':           ((pt, flag) => { pt.snapToGrid = !!flag; }),
        'snap-to-points':              (pt => pt.snapToPoints ? 1 : 0),
        'set-snap-to-points!':         ((pt, flag) => { pt.snapToPoints = !!flag; }),
        'snatch-distance':             (pt => pt.snatchDistance),
        'set-snatch-distance!':        ((pt, d) => { pt.snatchDistance = d; }),
        'style':                       (pt => pt.style),
        'set-style!':                  ((pt, s) => { pt.style = s; }),
        'x':                           (pt => pt.X()),
        'y':                           (pt => pt.Y()),
        'zoom':                        (pt => pt.zoom ? 1 : 0),
        'set-zoom!':                   ((pt, flag) => { pt.zoom = !!flag; }),
        'has-point':                   ((pt, x, y) => pt.hasPoint(x, y) ? 1 : 0),
        'is-on':                       ((pt, el, tol) => pt.isOn(el, tol) ? 1 : 0),
        'make-intersection!':          ((pt, el1, el2, i, j) => { pt.makeIntersection(el1, el2, i, j); }),
        'normalize-face':              ((pt, s) => pt.normalizeFace(from_fasl(s))),
        'call-set-style!':             ((pt, i) => { pt.setStyle(i); }),
        'update!':                     ((pt, flag) => { pt.update(!!flag); }),
        'update-renderer!':            (pt => { pt.updateRenderer(); }),
        'update-transform!':           ((pt, flag) => pt.updateTransform(!!flag))
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
