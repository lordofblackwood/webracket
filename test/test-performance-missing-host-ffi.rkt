#lang webracket/base

;; Browser smoke for optional Performance API host-boundary errors.

(require (only-in webracket/unsafe/performance
                  js-performance-measure-user-agent-specific-memory)
         (only-in webracket/unsafe/standard
                  js-eval))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (catch-message thunk)
  (with-handlers ([exn:fail? exn-message])
    (thunk)
    #f))

(define (string-contains/simple? haystack needle)
  (define haystack-length (string-length haystack))
  (define needle-length (string-length needle))
  (let loop ([index 0])
    (cond
      [(> (+ index needle-length) haystack-length) #f]
      [(string=? (substring haystack index (+ index needle-length)) needle) #t]
      [else (loop (add1 index))])))

(define (check-message message needle label)
  (check-true (and message
                   (string-contains/simple? message needle))
              label))

(js-eval
 "globalThis.__wrPerformanceMethodBoundary = {
    hadOwn: Object.prototype.hasOwnProperty.call(performance, 'measureUserAgentSpecificMemory'),
    descriptor: Object.getOwnPropertyDescriptor(performance, 'measureUserAgentSpecificMemory')
  };
  Object.defineProperty(performance, 'measureUserAgentSpecificMemory', {
    value: undefined,
    configurable: true,
    writable: true
  });")

(define measure-user-agent-specific-memory-message
  (catch-message
   (lambda ()
     (js-performance-measure-user-agent-specific-memory))))

(js-eval
 "const saved = globalThis.__wrPerformanceMethodBoundary;
  if (saved.hadOwn) {
    Object.defineProperty(performance, 'measureUserAgentSpecificMemory', saved.descriptor);
  } else {
    delete performance.measureUserAgentSpecificMemory;
  }
  delete globalThis.__wrPerformanceMethodBoundary;")

(check-message measure-user-agent-specific-memory-message
               "performance.measureUserAgentSpecificMemory not available in this environment"
               "missing measureUserAgentSpecificMemory message")

(js-log "performance-missing-host-ffi-ok")
#t
