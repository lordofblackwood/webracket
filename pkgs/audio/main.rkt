#lang webracket/base

(require racket/include
         webracket/unsafe/audio
         webracket/unsafe/standard
         (only-in webracket/primitives
                  external?
                  procedure->external)
         (for-syntax racket/base))

;; Public module wrapper for the legacy Web Audio helper library.
;;
;; The included file owns the safe wrapper surface; this module supplies the
;; unsafe audio and standard JS bindings explicitly for module-based programs.

(provide (all-defined-out))

(begin-for-syntax
  (define (read-syntax/skip-first-line
           [source-name (object-name (current-input-port))]
           [in          (current-input-port)])
    (read-line in)
    (read-syntax source-name in)))

;; audio-listener : external/raw -> audio-listener?
;;   Wrap a browser AudioListener object.
(struct audio-listener (raw) #:transparent)

;; audio-listener-wrap : any/c -> any/c
;;   Wrap a raw browser AudioListener object, leaving wrapped values alone.
(define (audio-listener-wrap value)
  (if (or (not value) (audio-listener? value))
      value
      (audio-listener value)))

;; audio-listener-unwrap : any/c -> any/c
;;   Unwrap an audio-listener struct to its raw browser object.
(define (audio-listener-unwrap value)
  (if (audio-listener? value)
      (audio-listener-raw value)
      value))

;; audio-periodic-wave : external/raw -> audio-periodic-wave?
;;   Wrap a browser PeriodicWave object.
(struct audio-periodic-wave (raw) #:transparent)

;; audio-periodic-wave-wrap : any/c -> any/c
;;   Wrap a raw browser PeriodicWave object, leaving wrapped values alone.
(define (audio-periodic-wave-wrap value)
  (if (or (not value) (audio-periodic-wave? value))
      value
      (audio-periodic-wave value)))

;; audio-periodic-wave-unwrap : any/c -> any/c
;;   Unwrap an audio-periodic-wave struct to its raw browser object.
(define (audio-periodic-wave-unwrap value)
  (if (audio-periodic-wave? value)
      (audio-periodic-wave-raw value)
      value))

;; array-like->vector : symbol? any/c (-> any/c any/c) -> vector?
;;   Convert a browser array-like value into a WebRacket vector.
(define (array-like->vector who value wrap-item)
  (define length (js-ref value "length"))
  (unless (exact-nonnegative-integer? length)
    (raise-argument-error who "array-like browser value" value))
  (let loop ([i 0] [acc '()])
    (if (= i length)
        (list->vector (reverse acc))
        (loop (add1 i)
              (cons (wrap-item (js-index value i)) acc)))))

(include/reader "../../lib/libs/audio.rkt" read-syntax/skip-first-line)
