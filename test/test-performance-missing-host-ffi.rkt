#lang webracket/base

;; Browser smoke for optional Performance API host-boundary errors.

(require (only-in webracket/unsafe/performance
                  js-performance-clear-marks
                  js-performance-clear-measures
                  js-performance-clear-resource-timings
                  js-performance-event-count-map-size
                  js-performance-get-entries
                  js-performance-get-entries-by-name
                  js-performance-get-entries-by-type
                  js-performance-mark
                  js-performance-measure
                  js-performance-measure-user-agent-specific-memory
                  js-performance-memory-info-js-heap-size-limit
                  js-performance-memory-info-total-js-heap-size
                  js-performance-memory-info-used-js-heap-size
                  js-performance-now
                  js-performance-set-resource-timing-buffer-size
                  js-performance-to-json)
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

(define js-null (js-eval "null"))
(define missing-property-object (js-eval "({})"))

(js-eval
 "globalThis.__wrPerformanceMethodBoundary = {};
  [
    'now',
    'clearMarks',
    'clearMeasures',
    'clearResourceTimings',
    'getEntries',
    'getEntriesByName',
    'getEntriesByType',
    'mark',
    'measure',
    'measureUserAgentSpecificMemory',
    'setResourceTimingBufferSize',
    'toJSON'
  ].forEach((name) => {
    globalThis.__wrPerformanceMethodBoundary[name] = {
      hadOwn: Object.prototype.hasOwnProperty.call(performance, name),
      descriptor: Object.getOwnPropertyDescriptor(performance, name)
    };
    Object.defineProperty(performance, name, {
      value: undefined,
      configurable: true,
      writable: true
    });
  });")

(define now-message
  (catch-message
   (lambda ()
     (js-performance-now))))

(define clear-marks-message
  (catch-message
   (lambda ()
     (js-performance-clear-marks (void)))))

(define clear-measures-message
  (catch-message
   (lambda ()
     (js-performance-clear-measures (void)))))

(define clear-resource-timings-message
  (catch-message
   (lambda ()
     (js-performance-clear-resource-timings))))

(define get-entries-message
  (catch-message
   (lambda ()
     (js-performance-get-entries))))

(define get-entries-by-name-message
  (catch-message
   (lambda ()
     (js-performance-get-entries-by-name "missing" (void)))))

(define get-entries-by-type-message
  (catch-message
   (lambda ()
     (js-performance-get-entries-by-type "mark"))))

(define mark-message
  (catch-message
   (lambda ()
     (js-performance-mark "missing" (void)))))

(define measure-message
  (catch-message
   (lambda ()
     (js-performance-measure "missing" (void) (void)))))

(define measure-user-agent-specific-memory-message
  (catch-message
   (lambda ()
     (js-performance-measure-user-agent-specific-memory))))

(define set-resource-timing-buffer-size-message
  (catch-message
   (lambda ()
     (js-performance-set-resource-timing-buffer-size 64))))

(define to-json-message
  (catch-message
   (lambda ()
     (js-performance-to-json))))

(define event-count-size-null-message
  (catch-message
   (lambda ()
     (js-performance-event-count-map-size js-null))))

(define memory-js-heap-size-limit-null-message
  (catch-message
   (lambda ()
     (js-performance-memory-info-js-heap-size-limit js-null))))

(define memory-total-js-heap-size-null-message
  (catch-message
   (lambda ()
     (js-performance-memory-info-total-js-heap-size js-null))))

(define memory-used-js-heap-size-null-message
  (catch-message
   (lambda ()
     (js-performance-memory-info-used-js-heap-size js-null))))

(define event-count-size-missing-message
  (catch-message
   (lambda ()
     (js-performance-event-count-map-size missing-property-object))))

(define memory-js-heap-size-limit-missing-message
  (catch-message
   (lambda ()
     (js-performance-memory-info-js-heap-size-limit missing-property-object))))

(define memory-total-js-heap-size-missing-message
  (catch-message
   (lambda ()
     (js-performance-memory-info-total-js-heap-size missing-property-object))))

(define memory-used-js-heap-size-missing-message
  (catch-message
   (lambda ()
     (js-performance-memory-info-used-js-heap-size missing-property-object))))

(js-eval
 "Object.entries(globalThis.__wrPerformanceMethodBoundary).forEach(([name, saved]) => {
    if (saved.hadOwn) {
      Object.defineProperty(performance, name, saved.descriptor);
    } else {
      delete performance[name];
    }
  });
  delete globalThis.__wrPerformanceMethodBoundary;")

(check-message now-message
               "performance.now not available in this environment"
               "missing now message")

(check-message clear-marks-message
               "performance.clearMarks not available in this environment"
               "missing clearMarks message")

(check-message clear-measures-message
               "performance.clearMeasures not available in this environment"
               "missing clearMeasures message")

(check-message clear-resource-timings-message
               "performance.clearResourceTimings not available in this environment"
               "missing clearResourceTimings message")

(check-message get-entries-message
               "performance.getEntries not available in this environment"
               "missing getEntries message")

(check-message get-entries-by-name-message
               "performance.getEntriesByName not available in this environment"
               "missing getEntriesByName message")

(check-message get-entries-by-type-message
               "performance.getEntriesByType not available in this environment"
               "missing getEntriesByType message")

(check-message mark-message
               "performance.mark not available in this environment"
               "missing mark message")

(check-message measure-message
               "performance.measure not available in this environment"
               "missing measure message")

(check-message measure-user-agent-specific-memory-message
               "performance.measureUserAgentSpecificMemory not available in this environment"
               "missing measureUserAgentSpecificMemory message")

(check-message set-resource-timing-buffer-size-message
               "performance.setResourceTimingBufferSize not available in this environment"
               "missing setResourceTimingBufferSize message")

(check-message to-json-message
               "performance.toJSON not available in this environment"
               "missing toJSON message")

(check-message event-count-size-null-message
               "PerformanceEventCounts.size: target object is null or undefined"
               "null PerformanceEventCounts.size message")

(check-message memory-js-heap-size-limit-null-message
               "PerformanceMemory.jsHeapSizeLimit: target object is null or undefined"
               "null PerformanceMemory.jsHeapSizeLimit message")

(check-message memory-total-js-heap-size-null-message
               "PerformanceMemory.totalJSHeapSize: target object is null or undefined"
               "null PerformanceMemory.totalJSHeapSize message")

(check-message memory-used-js-heap-size-null-message
               "PerformanceMemory.usedJSHeapSize: target object is null or undefined"
               "null PerformanceMemory.usedJSHeapSize message")

(check-message event-count-size-missing-message
               "PerformanceEventCounts.size not available in this environment"
               "missing PerformanceEventCounts.size message")

(check-message memory-js-heap-size-limit-missing-message
               "PerformanceMemory.jsHeapSizeLimit not available in this environment"
               "missing PerformanceMemory.jsHeapSizeLimit message")

(check-message memory-total-js-heap-size-missing-message
               "PerformanceMemory.totalJSHeapSize not available in this environment"
               "missing PerformanceMemory.totalJSHeapSize message")

(check-message memory-used-js-heap-size-missing-message
               "PerformanceMemory.usedJSHeapSize not available in this environment"
               "missing PerformanceMemory.usedJSHeapSize message")

(js-log "performance-missing-host-ffi-ok")
#t
