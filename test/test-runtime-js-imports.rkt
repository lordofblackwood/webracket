#lang racket/base

(require racket/file
         racket/runtime-path
         racket/system
         rackunit)

(define-runtime-path runtime-imports-js
  "../pkgs/webracket-lib/compiler/runtime-js/imports.js")

;; write-script! : path-string? string? -> void?
;;   Write a generated JavaScript test script.
(define (write-script! path source)
  (call-with-output-file path
    (lambda (out) (display source out))
    #:exists 'truncate/replace))

(test-case "FFI exception bridge import assertion tolerates descriptor failures"
  (define node-path (find-executable-path "node"))
  (when node-path
    (define script-path
      (make-temporary-file "webracket-runtime-js-imports-~a.mjs"))
    (define imports-js (file->string runtime-imports-js))
    (write-script!
     script-path
     (string-append
      "const hostArray = Array;\n"
      "class FakeWebAssemblyTag { constructor(_spec) {} }\n"
      "class FakeWebAssemblyException extends Error {}\n"
      "const hostWebAssemblyTag = FakeWebAssemblyTag;\n"
      "const hostWebAssemblyException = FakeWebAssemblyException;\n"
      "const hostWebAssemblyModule = {\n"
      "  imports(module) {\n"
      "    if (module.throwImports) {\n"
      "      throw new Error('import descriptor failure');\n"
      "    }\n"
      "    return module.imports || [];\n"
      "  }\n"
      "};\n"
      "const memory = {};\n"
      "const hasDOM = false;\n"
      "const hasPerformance = false;\n"
      "const websocket = {};\n"
      "const audio = {};\n"
      "function make_callback(_id) { return null; }\n"
      imports-js
      "\n"
      "assert_ffi_exception_bridge_visible_imports(\n"
      "  { throwImports: true },\n"
      "  {},\n"
      "  'Safari descriptor failure probe'\n"
      ");\n"
      "assert_ffi_exception_bridge_visible_imports(\n"
      "  { imports: [{ kind: 'function', module: 'geo', name: 'measure' }] },\n"
      "  { geo: { measure() {} } },\n"
      "  'normal descriptor probe'\n"
      ");\n"
      "let rejected = false;\n"
      "try {\n"
      "  assert_ffi_exception_bridge_visible_imports(\n"
      "    { imports: [{ kind: 'function', module: 'geo', name: 'measure' }] },\n"
      "    { geo: {} },\n"
      "    'missing descriptor probe'\n"
      "  );\n"
      "} catch (err) {\n"
      "  rejected = /must be an own enumerable function/.test(String(err && err.message));\n"
      "}\n"
      "if (!rejected) {\n"
      "  throw new Error('expected missing import assertion failure');\n"
      "}\n"
      "hostWebAssemblyModule.imports = undefined;\n"
      "assert_ffi_exception_bridge_visible_imports(\n"
      "  { imports: [{ kind: 'function', module: 'geo', name: 'measure' }] },\n"
      "  {},\n"
      "  'missing Module.imports probe'\n"
      ");\n"))
    (dynamic-wind
      void
      (lambda ()
        (check-equal? (system*/exit-code node-path (path->string script-path))
                      0))
      (lambda ()
        (with-handlers ([exn:fail:filesystem? void])
          (delete-file script-path))))))

(module+ main
  (void))
