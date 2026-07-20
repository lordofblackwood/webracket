#lang webracket/base

(require (only-in webracket/unsafe/dom
                  js-constructible?
                  js-array->vector
                  js-new
                  js-nullish?
                  js-ref
                  js-ref/extern
                  js-send/extern
                  js-send/extern/nullish
                  js-set!
                  js-typeof
                  js-undefined?
                  js-var
                  js-window-window)
         (only-in webracket/primitives
                  external?
                  procedure->external))

(provide (all-defined-out))

;;;
;;; Web Speech wrappers
;;;

(define speech-callback-cache (make-hasheq))

;; speech-synthesis-info : external/raw -> speech-synthesis-info?
;;   Wrap the browser SpeechSynthesis object.
(struct speech-synthesis-info (raw) #:transparent)

;; speech-utterance-info : external/raw -> speech-utterance-info?
;;   Wrap a browser SpeechSynthesisUtterance object.
(struct speech-utterance-info (raw) #:transparent)

;; speech-voice-info : external/raw -> speech-voice-info?
;;   Wrap a browser SpeechSynthesisVoice object.
(struct speech-voice-info (raw) #:transparent)

;; speech-utterance-options : value -> speech-utterance-options?
;;   Options for make-speech-utterance.
(struct speech-utterance-options (lang volume rate pitch) #:transparent)

;; speech-synthesis-raw : speech-synthesis-info? -> external/raw
;;   Extract the raw SpeechSynthesis object.
(define (speech-synthesis-raw value)
  (speech-synthesis-info-raw value))

;; speech-utterance-raw : speech-utterance-info? -> external/raw
;;   Extract the raw SpeechSynthesisUtterance object.
(define (speech-utterance-raw value)
  (speech-utterance-info-raw value))

;; speech-voice-raw : speech-voice-info? -> external/raw
;;   Extract the raw SpeechSynthesisVoice object.
(define (speech-voice-raw value)
  (speech-voice-info-raw value))

;; speech-method-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a callable method named method-name.
(define (speech-method-present? raw method-name)
  (and (speech-raw-host-value? raw)
       (let ([method (js-ref/extern raw method-name)])
         (and (not (js-nullish? method))
              (string=? (js-typeof method) "function")))))

;; speech-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a non-nullish property named property-name.
(define (speech-property-present? raw property-name)
  (and (speech-raw-host-value? raw)
       (not (js-nullish? (js-ref/extern raw property-name)))))

;; speech-nullable-property-present? : external/raw string? -> boolean?
;;   Report whether raw exposes a property, allowing null values.
(define (speech-nullable-property-present? raw property-name)
  (and (speech-raw-host-value? raw)
       (not (js-undefined? (js-ref/extern raw property-name)))))

;; speech-raw-host-value? : any/c -> boolean?
;;   Report whether raw is a non-nullish external host value.
(define (speech-raw-host-value? raw)
  (and (external? raw)
       (not (js-nullish? raw))))

;; speech-constructor-present? : string? -> boolean?
;;   Report whether the host exposes a callable constructor.
(define (speech-constructor-present? name)
  (js-constructible? (js-var name)))

;; speech-synthesis-raw/current : -> any/c
;;   Probe the optional window.speechSynthesis property without requiring it.
(define (speech-synthesis-raw/current)
  (js-ref/extern (js-window-window) "speechSynthesis"))

;; check-speech-constructor : symbol? string? -> void?
;;   Ensure the host exposes a required Web Speech constructor.
(define (check-speech-constructor who name)
  (unless (speech-constructor-present? name)
    (raise-arguments-error who
                           (string-append name " constructor is not available"))))

;; check-speech-synthesis : symbol? any/c -> void?
;;   Ensure value wraps an external SpeechSynthesis-like host value.
(define (check-speech-synthesis who value)
  (unless (speech-synthesis-host-value? value)
    (raise-argument-error who "speech-synthesis?" value)))

;; check-speech-utterance : symbol? any/c -> void?
;;   Ensure value wraps an external SpeechSynthesisUtterance-like host value.
(define (check-speech-utterance who value)
  (unless (speech-utterance? value)
    (raise-argument-error who "speech-utterance?" value)))

;; check-speech-voice : symbol? any/c -> void?
;;   Ensure value wraps an external SpeechSynthesisVoice-like host value.
(define (check-speech-voice who value)
  (unless (speech-voice? value)
    (raise-argument-error who "speech-voice?" value)))

;; check-speech-host-method : symbol? external/raw string? string? -> void?
;;   Ensure raw exposes a required Web Speech method.
(define (check-speech-host-method who raw receiver-name method-name)
  (unless (speech-method-present? raw method-name)
    (raise-arguments-error who
                           (string-append receiver-name "." method-name " is not available"))))

;; check-speech-host-property : symbol? external/raw string? string? -> void?
;;   Ensure raw exposes a required Web Speech property.
(define (check-speech-host-property who raw receiver-name property-name)
  (unless (speech-property-present? raw property-name)
    (raise-arguments-error who
                           (string-append receiver-name "." property-name " is not available"))))

;; check-speech-host-nullable-property : symbol? external/raw string? string? -> void?
;;   Ensure raw exposes a required Web Speech property, allowing null values.
(define (check-speech-host-nullable-property who raw receiver-name property-name)
  (unless (speech-nullable-property-present? raw property-name)
    (raise-arguments-error who
                           (string-append receiver-name "." property-name " is not available"))))

;; speech-vector-map : procedure? vector? -> vector?
;;   Map proc over vec without depending on racket/vector.
(define (speech-vector-map proc vec)
  (define len (vector-length vec))
  (define out (make-vector len))
  (let loop ([i 0])
    (when (< i len)
      (vector-set! out i (proc (vector-ref vec i)))
      (loop (add1 i))))
  out)

;; web-speech-synthesis-supported? : -> boolean?
;;   Report whether speech synthesis is available.
(define (web-speech-synthesis-supported?)
  (define synthesis (speech-synthesis-raw/current))
  (and (not (js-nullish? synthesis))
       (speech-constructor-present? "SpeechSynthesisUtterance")
       (speech-method-present? synthesis "speak")))

;; web-speech-recognition-supported? : -> boolean?
;;   Report whether unprefixed or webkit-prefixed speech recognition is available.
(define (web-speech-recognition-supported?)
  (or (speech-constructor-present? "SpeechRecognition")
      (speech-constructor-present? "webkitSpeechRecognition")))

;; speech-synthesis : -> (or/c #f speech-synthesis?)
;;   Return the browser SpeechSynthesis object when available.
(define (speech-synthesis)
  (and (web-speech-synthesis-supported?)
       (speech-synthesis-info (speech-synthesis-raw/current))))

;; speech-synthesis? : any/c -> boolean?
;;   Report whether v is a wrapped SpeechSynthesis object.
(define (speech-synthesis? v)
  (speech-synthesis-host-value? v))

;; speech-synthesis-host-value? : any/c -> boolean?
;;   Report whether v wraps an external SpeechSynthesis-like host value.
(define (speech-synthesis-host-value? v)
  (and (speech-synthesis-info? v)
       (speech-raw-host-value? (speech-synthesis-raw v))))

;; speech-utterance? : any/c -> boolean?
;;   Report whether v is a wrapped SpeechSynthesisUtterance object.
(define (speech-utterance? v)
  (and (speech-utterance-info? v)
       (speech-raw-host-value? (speech-utterance-raw v))))

;; speech-voice? : any/c -> boolean?
;;   Report whether v is a wrapped SpeechSynthesisVoice object.
(define (speech-voice? v)
  (and (speech-voice-info? v)
       (speech-raw-host-value? (speech-voice-raw v))))

;; speech-optional-string? : any/c -> boolean?
;;   Recognize optional string-like settings.
(define (speech-optional-string? value)
  (or (not value) (string? value) (symbol? value)))

;; speech-stringish->string : symbol? any/c -> string?
;;   Normalize text input to a browser string.
(define (speech-stringish->string who value)
  (cond
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [else
     (raise-argument-error who "(or/c string? symbol?)" value)]))

;; speech-stringish-option->string : symbol? any/c -> (or/c #f string?)
;;   Normalize optional string-like options.
(define (speech-stringish-option->string who value)
  (cond
    [(not value) #f]
    [(string? value) value]
    [(symbol? value) (symbol->string value)]
    [else
     (raise-argument-error who "(or/c #f string? symbol?)" value)]))

;; speech-number-in-range? : any/c number? number? -> boolean?
;;   Recognize numbers in a browser option range.
(define (speech-number-in-range? value lo hi)
  (and (number? value)
       (<= lo value)
       (<= value hi)))

;; make-speech-utterance-options : [maybe-lang] [maybe-volume] [maybe-rate] [maybe-pitch] -> speech-utterance-options?
;;   Build checked utterance options.
(define (make-speech-utterance-options [lang #f]
                                       [volume #f]
                                       [rate #f]
                                       [pitch #f])
  (unless (speech-optional-string? lang)
    (raise-argument-error 'make-speech-utterance-options
                          "(or/c #f string? symbol?)"
                          lang))
  (unless (or (not volume) (speech-number-in-range? volume 0 1))
    (raise-argument-error 'make-speech-utterance-options
                          "(or/c #f (real-in 0 1))"
                          volume))
  (unless (or (not rate) (speech-number-in-range? rate 0.1 10))
    (raise-argument-error 'make-speech-utterance-options
                          "(or/c #f (real-in 0.1 10))"
                          rate))
  (unless (or (not pitch) (speech-number-in-range? pitch 0 2))
    (raise-argument-error 'make-speech-utterance-options
                          "(or/c #f (real-in 0 2))"
                          pitch))
  (speech-utterance-options lang volume rate pitch))

;; apply-speech-utterance-options! : speech-utterance-info? speech-utterance-options? -> void?
;;   Apply checked utterance options to a raw utterance.
(define (apply-speech-utterance-options! utterance options)
  (when (speech-utterance-options-lang options)
    (check-speech-host-property 'make-speech-utterance
                                (speech-utterance-raw utterance)
                                "SpeechSynthesisUtterance"
                                "lang")
    (js-set! (speech-utterance-raw utterance)
             "lang"
             (speech-stringish-option->string
              'make-speech-utterance
              (speech-utterance-options-lang options))))
  (when (speech-utterance-options-volume options)
    (check-speech-host-property 'make-speech-utterance
                                (speech-utterance-raw utterance)
                                "SpeechSynthesisUtterance"
                                "volume")
    (js-set! (speech-utterance-raw utterance)
             "volume"
             (speech-utterance-options-volume options)))
  (when (speech-utterance-options-rate options)
    (check-speech-host-property 'make-speech-utterance
                                (speech-utterance-raw utterance)
                                "SpeechSynthesisUtterance"
                                "rate")
    (js-set! (speech-utterance-raw utterance)
             "rate"
             (speech-utterance-options-rate options)))
  (when (speech-utterance-options-pitch options)
    (check-speech-host-property 'make-speech-utterance
                                (speech-utterance-raw utterance)
                                "SpeechSynthesisUtterance"
                                "pitch")
    (js-set! (speech-utterance-raw utterance)
             "pitch"
             (speech-utterance-options-pitch options)))
  (void))

;; make-speech-utterance : (or/c string? symbol?) [maybe-options] -> speech-utterance?
;;   Create a SpeechSynthesisUtterance.
(define (make-speech-utterance text [options #f])
  (unless (or (not options) (speech-utterance-options? options))
    (raise-argument-error 'make-speech-utterance
                          "(or/c #f speech-utterance-options?)"
                          options))
  (check-speech-constructor 'make-speech-utterance "SpeechSynthesisUtterance")
  (define utterance
    (speech-utterance-info
     (js-new (js-var "SpeechSynthesisUtterance")
             (vector (speech-stringish->string 'make-speech-utterance text)))))
  (when options
    (apply-speech-utterance-options! utterance options))
  utterance)

;; speech-synthesis-speak! : speech-synthesis? speech-utterance? -> void?
;;   Queue an utterance to be spoken.
(define (speech-synthesis-speak! synthesis utterance)
  (check-speech-synthesis 'speech-synthesis-speak! synthesis)
  (check-speech-utterance 'speech-synthesis-speak! utterance)
  (check-speech-host-method 'speech-synthesis-speak!
                            (speech-synthesis-raw synthesis)
                            "SpeechSynthesis"
                            "speak")
  (js-send/extern/nullish (speech-synthesis-raw synthesis)
                          "speak"
                          (vector (speech-utterance-raw utterance)))
  (void))

;; speech-synthesis-cancel! : speech-synthesis? -> void?
;;   Cancel queued and active speech.
(define (speech-synthesis-cancel! synthesis)
  (check-speech-synthesis 'speech-synthesis-cancel! synthesis)
  (check-speech-host-method 'speech-synthesis-cancel!
                            (speech-synthesis-raw synthesis)
                            "SpeechSynthesis"
                            "cancel")
  (js-send/extern/nullish (speech-synthesis-raw synthesis) "cancel" (vector))
  (void))

;; speech-synthesis-pause! : speech-synthesis? -> void?
;;   Pause active speech.
(define (speech-synthesis-pause! synthesis)
  (check-speech-synthesis 'speech-synthesis-pause! synthesis)
  (check-speech-host-method 'speech-synthesis-pause!
                            (speech-synthesis-raw synthesis)
                            "SpeechSynthesis"
                            "pause")
  (js-send/extern/nullish (speech-synthesis-raw synthesis) "pause" (vector))
  (void))

;; speech-synthesis-resume! : speech-synthesis? -> void?
;;   Resume paused speech.
(define (speech-synthesis-resume! synthesis)
  (check-speech-synthesis 'speech-synthesis-resume! synthesis)
  (check-speech-host-method 'speech-synthesis-resume!
                            (speech-synthesis-raw synthesis)
                            "SpeechSynthesis"
                            "resume")
  (js-send/extern/nullish (speech-synthesis-raw synthesis) "resume" (vector))
  (void))

;; speech-synthesis-speaking? : speech-synthesis? -> boolean?
;;   Report whether speech is currently active.
(define (speech-synthesis-speaking? synthesis)
  (check-speech-synthesis 'speech-synthesis-speaking? synthesis)
  (check-speech-host-property 'speech-synthesis-speaking?
                              (speech-synthesis-raw synthesis)
                              "SpeechSynthesis"
                              "speaking")
  (js-ref (speech-synthesis-raw synthesis) "speaking"))

;; speech-synthesis-paused? : speech-synthesis? -> boolean?
;;   Report whether speech is currently paused.
(define (speech-synthesis-paused? synthesis)
  (check-speech-synthesis 'speech-synthesis-paused? synthesis)
  (check-speech-host-property 'speech-synthesis-paused?
                              (speech-synthesis-raw synthesis)
                              "SpeechSynthesis"
                              "paused")
  (js-ref (speech-synthesis-raw synthesis) "paused"))

;; speech-synthesis-pending? : speech-synthesis? -> boolean?
;;   Report whether utterances are queued.
(define (speech-synthesis-pending? synthesis)
  (check-speech-synthesis 'speech-synthesis-pending? synthesis)
  (check-speech-host-property 'speech-synthesis-pending?
                              (speech-synthesis-raw synthesis)
                              "SpeechSynthesis"
                              "pending")
  (js-ref (speech-synthesis-raw synthesis) "pending"))

;; speech-synthesis-voices : speech-synthesis? -> vector?
;;   Return available speech voices as wrapped values.
(define (speech-synthesis-voices synthesis)
  (check-speech-synthesis 'speech-synthesis-voices synthesis)
  (check-speech-host-method 'speech-synthesis-voices
                            (speech-synthesis-raw synthesis)
                            "SpeechSynthesis"
                            "getVoices")
  (speech-vector-map
   speech-voice-info
   (js-array->vector
    (js-send/extern (speech-synthesis-raw synthesis) "getVoices" (vector)))))

;; speech-voice-name : speech-voice? -> string?
;;   Read a voice name.
(define (speech-voice-name voice)
  (check-speech-voice 'speech-voice-name voice)
  (check-speech-host-property 'speech-voice-name
                              (speech-voice-raw voice)
                              "SpeechSynthesisVoice"
                              "name")
  (js-ref (speech-voice-raw voice) "name"))

;; speech-voice-lang : speech-voice? -> string?
;;   Read a BCP 47 language tag for a voice.
(define (speech-voice-lang voice)
  (check-speech-voice 'speech-voice-lang voice)
  (check-speech-host-property 'speech-voice-lang
                              (speech-voice-raw voice)
                              "SpeechSynthesisVoice"
                              "lang")
  (js-ref (speech-voice-raw voice) "lang"))

;; speech-voice-default? : speech-voice? -> boolean?
;;   Report whether this is the default voice.
(define (speech-voice-default? voice)
  (check-speech-voice 'speech-voice-default? voice)
  (check-speech-host-property 'speech-voice-default?
                              (speech-voice-raw voice)
                              "SpeechSynthesisVoice"
                              "default")
  (js-ref (speech-voice-raw voice) "default"))

;; speech-voice-local-service? : speech-voice? -> boolean?
;;   Report whether this voice is provided locally.
(define (speech-voice-local-service? voice)
  (check-speech-voice 'speech-voice-local-service? voice)
  (check-speech-host-property 'speech-voice-local-service?
                              (speech-voice-raw voice)
                              "SpeechSynthesisVoice"
                              "localService")
  (js-ref (speech-voice-raw voice) "localService"))

;; speech-voice-uri : speech-voice? -> string?
;;   Read the voice URI.
(define (speech-voice-uri voice)
  (check-speech-voice 'speech-voice-uri voice)
  (check-speech-host-property 'speech-voice-uri
                              (speech-voice-raw voice)
                              "SpeechSynthesisVoice"
                              "voiceURI")
  (js-ref (speech-voice-raw voice) "voiceURI"))

;; speech-utterance-set-voice! : speech-utterance? speech-voice? -> void?
;;   Set the voice used by an utterance.
(define (speech-utterance-set-voice! utterance voice)
  (check-speech-utterance 'speech-utterance-set-voice! utterance)
  (check-speech-voice 'speech-utterance-set-voice! voice)
  (check-speech-host-nullable-property 'speech-utterance-set-voice!
                                       (speech-utterance-raw utterance)
                                       "SpeechSynthesisUtterance"
                                       "voice")
  (js-set! (speech-utterance-raw utterance) "voice" (speech-voice-raw voice))
  (void))

;; speech-callback->external : symbol? any/c -> external/raw
;;   Convert a callback to a stable external callback wrapper.
(define (speech-callback->external who callback)
  (cond
    [(external? callback) callback]
    [(procedure? callback)
     (define cached (hash-ref speech-callback-cache callback #f))
     (cond
       [cached cached]
       [else
        (define external
          (procedure->external
           (lambda args
             (apply callback args)
             (void))))
        (hash-set! speech-callback-cache callback external)
        external])]
    [else
     (raise-argument-error who "(or/c procedure? external?)" callback)]))

;; speech-utterance-on-end! : speech-utterance? (or/c procedure? external? #f) -> void?
;;   Set the onend handler for an utterance.
(define (speech-utterance-on-end! utterance callback)
  (check-speech-utterance 'speech-utterance-on-end! utterance)
  (check-speech-host-nullable-property 'speech-utterance-on-end!
                                       (speech-utterance-raw utterance)
                                       "SpeechSynthesisUtterance"
                                       "onend")
  (define callback* (and callback
                         (speech-callback->external 'speech-utterance-on-end! callback)))
  (js-set! (speech-utterance-raw utterance) "onend" callback*)
  (void))

;; speech-utterance-on-error! : speech-utterance? (or/c procedure? external? #f) -> void?
;;   Set the onerror handler for an utterance.
(define (speech-utterance-on-error! utterance callback)
  (check-speech-utterance 'speech-utterance-on-error! utterance)
  (check-speech-host-nullable-property 'speech-utterance-on-error!
                                       (speech-utterance-raw utterance)
                                       "SpeechSynthesisUtterance"
                                       "onerror")
  (define callback* (and callback
                         (speech-callback->external 'speech-utterance-on-error! callback)))
  (js-set! (speech-utterance-raw utterance) "onerror" callback*)
  (void))
