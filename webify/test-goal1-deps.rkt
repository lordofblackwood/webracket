#lang racket/base

(require racket/file
         racket/list
         racket/runtime-path
         racket/string
         racket/system)

(define-runtime-path probe-path "probe-installed-module-deps.rkt")

(module+ main
  (define tmp-dir (make-temporary-file "webracket-goal1-deps-test-~a" 'directory))
  (define out-path (build-path tmp-dir "stdout.txt"))
  (define err-path (build-path tmp-dir "stderr.txt"))
  (define out (open-output-file out-path #:exists 'truncate/replace))
  (define err (open-output-file err-path #:exists 'truncate/replace))
  (define status
    (parameterize ([current-output-port out]
                   [current-error-port err])
      (system*/exit-code
       (find-system-path 'exec-file)
       "-y"
       (path->string probe-path)
       "--goal1-compact-bounded"
       "--goal1-limit"
       "2"
       "--timeout"
       "120"
       "--memory-mb"
       "1024"
       "--jobs"
       "2")))
  (close-output-port out)
  (close-output-port err)
  (define stdout (file->string out-path))
  (define stderr (file->string err-path))
  (delete-directory/files tmp-dir)
  (unless (zero? status)
    (display stdout)
    (display stderr (current-error-port)))
  (when (zero? status)
    (define stdout-lines (string-split stdout "\n" #:trim? #t))
    (unless (and (>= (length stdout-lines) 4)
                 (string=? (first stdout-lines)
                           "Goal 1 must-have library dependency dashboard")
                 (string=? (second stdout-lines)
                           "case\textract\tinputs\tprimitive-demands\tmissing-primitives\townership")
                 (for/and ([line (in-list (drop stdout-lines 2))])
                   (and (= (length (string-split line "\t" #:trim? #f)) 6)
                        (not (string-prefix? line "goal1-deps:"))))
                 (string-contains? stderr "goal1-deps: starting")
                 (string-contains? stderr "goal1-deps: finished"))
      (display stdout)
      (display stderr (current-error-port))
      (set! status 1)))
  (exit status))
