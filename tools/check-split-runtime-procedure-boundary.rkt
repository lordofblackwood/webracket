#lang racket/base

;;; Check Split Runtime Procedure Boundary
;;;
;;; This check isolates the Wasm-GC type-boundary rule needed by split-runtime
;;; output: if the runtime and program modules use identical shared type
;;; declarations, a procedure allocated in the runtime module must pass a
;;; program-side `(ref.test (ref $Procedure) ...)`, and the program must be able
;;; to call a runtime-side apply shim with the imported procedure.

(require racket/file
         racket/list
         racket/path
         racket/port
         racket/runtime-path
         racket/string
         racket/system
         (only-in "../pkgs/webracket-lib/compiler/assembler.rkt"
                  wat->wasm)
         (only-in "../pkgs/webracket-lib/compiler/runtime-wasm/shared-types.rkt"
                  generate-shared-types))

;; repo-dir : path?
;;   Absolute path to the repository root.
(define-runtime-path repo-dir "..")

;; output-dir : path?
;;   Repo-local directory for generated WAT/Wasm artifacts.
(define output-dir
  (build-path (simplify-path repo-dir)
              "tmp"
              "split-runtime-procedure-boundary-check"))

;; with-shared-types : (listof datum?) -> datum?
;;   Build a module whose type prefix comes from the real WebRacket runtime.
(define (with-shared-types forms)
  `(module
    ,@(generate-shared-types)
    ,@forms))

;; runtime-module : datum?
;;   Runtime module for the boundary check.
(define runtime-module
  (with-shared-types
   '((func $answer-invoke
       (type $ProcedureInvoker)
       (param $proc (ref $Procedure))
       (param $args (ref $Args))
       (result (ref eq))
       (ref.i31 (i32.const 84)))

     (global $answer-procedure
       (export "answer-procedure")
       (mut (ref eq))
       (struct.new $Procedure
                   (i32.const 0)
                   (ref.i31 (i32.const 1))
                   (ref.i31 (i32.const 0))
                   (ref.i31 (i32.const 1))
                   (ref.func $answer-invoke)))

     (func $apply0
       (export "apply0")
       (param $proc-raw (ref eq))
       (result i32)
       (local $proc (ref $Procedure))
       (local $result (ref eq))
       (if (i32.eqz (ref.test (ref $Procedure) (local.get $proc-raw)))
           (then (return (i32.const -1))))
       (local.set $proc
                  (ref.cast (ref $Procedure) (local.get $proc-raw)))
       (local.set $result
                  (call_ref $ProcedureInvoker
                            (local.get $proc)
                            (array.new $Args
                                       (ref.i31 (i32.const 0))
                                       (i32.const 0))
                            (struct.get $Procedure
                                        $invoke
                                        (local.get $proc))))
       (i31.get_s (ref.cast (ref i31) (local.get $result))))

     (elem declare funcref (ref.func $answer-invoke)))))

;; program-module : datum?
;;   Program module for the boundary check.
(define program-module
  (with-shared-types
   '((import "runtime" "answer-procedure"
             (global $imported-procedure (mut (ref eq))))
     (import "runtime" "apply0"
             (func $runtime-apply0 (param (ref eq)) (result i32)))

     (func (export "local-procedure-test") (result i32)
       (ref.test (ref $Procedure) (global.get $imported-procedure)))

     (func (export "runtime-apply0") (result i32)
       (call $runtime-apply0 (global.get $imported-procedure))))))

;; host-js : string?
;;   Node host that instantiates runtime first and then program with runtime exports.
(define host-js
  #<<JS
const fs = require("fs");

async function main() {
  const runtimeBytes = fs.readFileSync("runtime.wasm");
  const programBytes = fs.readFileSync("program.wasm");

  const runtime = await WebAssembly.instantiate(runtimeBytes, {});
  const program = await WebAssembly.instantiate(programBytes, {
    runtime: runtime.instance.exports,
  });

  console.log("local-procedure-test=" + program.instance.exports["local-procedure-test"]());
  console.log("runtime-apply0=" + program.instance.exports["runtime-apply0"]());
}

main().catch((err) => {
  console.error(err && err.stack ? err.stack : err);
  process.exit(1);
});
JS
)

;; command-result : boolean? string? string? -> command-result?
;;   Captured subprocess result.
(struct command-result (ok? stdout stderr) #:transparent)

;; write-text-file! : path-string? string? -> void?
;;   Write text to path, replacing any existing file.
(define (write-text-file! path text)
  (call-with-output-file path
    (lambda (out) (display text out))
    #:exists 'replace))

;; run-command/capture : path-string? path-string? (listof path-string?) -> command-result?
;;   Run a command under cwd, capturing stdout and stderr.
(define (run-command/capture cwd exe args)
  (define out (open-output-string))
  (define err (open-output-string))
  (define ok?
    (parameterize ([current-directory cwd]
                   [current-output-port out]
                   [current-error-port err])
      (apply system* exe args)))
  (command-result ok? (get-output-string out) (get-output-string err)))

;; ensure-executable : string? -> path?
;;   Resolve an executable from PATH.
(define (ensure-executable name)
  (or (find-executable-path name)
      (error 'check-split-runtime-procedure-boundary
             "required executable not found in PATH: ~a"
             name)))

;; check-command! : symbol? command-result? -> void?
;;   Fail with captured output when command did not succeed.
(define (check-command! who result)
  (unless (command-result-ok? result)
    (raise-arguments-error who
                           "command failed"
                           "stdout" (command-result-stdout result)
                           "stderr" (command-result-stderr result))))

;; assert-output! : string? -> void?
;;   Validate the Node output for the expected boundary behavior.
(define (assert-output! stdout)
  (define lines
    (filter non-empty-string?
            (string-split stdout "\n")))
  (define expected
    '("local-procedure-test=1"
      "runtime-apply0=84"))
  (unless (equal? lines expected)
    (raise-arguments-error 'check-split-runtime-procedure-boundary
                           "unexpected host output"
                           "expected" expected
                           "actual" lines)))

(define node (ensure-executable "node"))

(make-directory* output-dir)
(write-text-file! (build-path output-dir "host.js") host-js)

(check-command!
 'wasm-tools-runtime
 (command-result
  (wat->wasm runtime-module
             #:wat (build-path output-dir "runtime.wat")
             #:wasm (build-path output-dir "runtime.wasm"))
  ""
  ""))
(check-command!
 'wasm-tools-program
 (command-result
  (wat->wasm program-module
             #:wat (build-path output-dir "program.wat")
             #:wasm (build-path output-dir "program.wasm"))
  ""
  ""))

(define host-result
  (run-command/capture output-dir node (list "host.js")))
(check-command! 'node-host host-result)
(assert-output! (command-result-stdout host-result))

(display (command-result-stdout host-result))
