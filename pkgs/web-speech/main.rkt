#lang webracket/base

(require (only-in webracket/unsafe/dom
                  js-array->vector
                  js-new
                  js-nullish?
                  js-ref
                  js-ref/extern
                  js-send/extern
                  js-send/extern/nullish
                  js-set!
                  js-typeof
                  js-var
                  js-window-speech-synthesis)
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
  (define method (js-ref/extern raw method-name))
  (and (not (js-nullish? method))
       (string=? (js-typeof method) "function")))

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
  (define synthesis (js-window-speech-synthesis))
  (define utterance-constructor (js-var "SpeechSynthesisUtterance"))
  (and (not (js-nullish? synthesis))
       (not (js-nullish? utterance-constructor))
       (speech-method-present? synthesis "speak")))

;; web-speech-recognition-supported? : -> boolean?
;;   Report whether unprefixed or webkit-prefixed speech recognition is available.
(define (web-speech-recognition-supported?)
  (or (not (js-nullish? (js-var "SpeechRecognition")))
      (not (js-nullish? (js-var "webkitSpeechRecognition")))))

;; speech-synthesis : -> (or/c #f speech-synthesis?)
;;   Return the browser SpeechSynthesis object when available.
(define (speech-synthesis)
  (and (web-speech-synthesis-supported?)
       (speech-synthesis-info (js-window-speech-synthesis))))

;; speech-synthesis? : any/c -> boolean?
;;   Report whether v is a wrapped SpeechSynthesis object.
(define (speech-synthesis? v)
  (and (speech-synthesis-info? v)
       (external? (speech-synthesis-raw v))))

;; speech-utterance? : any/c -> boolean?
;;   Report whether v is a wrapped SpeechSynthesisUtterance object.
(define (speech-utterance? v)
  (and (speech-utterance-info? v)
       (external? (speech-utterance-raw v))))

;; speech-voice? : any/c -> boolean?
;;   Report whether v is a wrapped SpeechSynthesisVoice object.
(define (speech-voice? v)
  (and (speech-voice-info? v)
       (external? (speech-voice-raw v))))

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
    (js-set! (speech-utterance-raw utterance)
             "lang"
             (speech-stringish-option->string
              'make-speech-utterance
              (speech-utterance-options-lang options))))
  (when (speech-utterance-options-volume options)
    (js-set! (speech-utterance-raw utterance)
             "volume"
             (speech-utterance-options-volume options)))
  (when (speech-utterance-options-rate options)
    (js-set! (speech-utterance-raw utterance)
             "rate"
             (speech-utterance-options-rate options)))
  (when (speech-utterance-options-pitch options)
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
  (unless (speech-synthesis? synthesis)
    (raise-argument-error 'speech-synthesis-speak! "speech-synthesis?" synthesis))
  (unless (speech-utterance? utterance)
    (raise-argument-error 'speech-synthesis-speak! "speech-utterance?" utterance))
  (js-send/extern/nullish (speech-synthesis-raw synthesis)
                          "speak"
                          (vector (speech-utterance-raw utterance)))
  (void))

;; speech-synthesis-cancel! : speech-synthesis? -> void?
;;   Cancel queued and active speech.
(define (speech-synthesis-cancel! synthesis)
  (unless (speech-synthesis? synthesis)
    (raise-argument-error 'speech-synthesis-cancel! "speech-synthesis?" synthesis))
  (js-send/extern/nullish (speech-synthesis-raw synthesis) "cancel" (vector))
  (void))

;; speech-synthesis-pause! : speech-synthesis? -> void?
;;   Pause active speech.
(define (speech-synthesis-pause! synthesis)
  (unless (speech-synthesis? synthesis)
    (raise-argument-error 'speech-synthesis-pause! "speech-synthesis?" synthesis))
  (js-send/extern/nullish (speech-synthesis-raw synthesis) "pause" (vector))
  (void))

;; speech-synthesis-resume! : speech-synthesis? -> void?
;;   Resume paused speech.
(define (speech-synthesis-resume! synthesis)
  (unless (speech-synthesis? synthesis)
    (raise-argument-error 'speech-synthesis-resume! "speech-synthesis?" synthesis))
  (js-send/extern/nullish (speech-synthesis-raw synthesis) "resume" (vector))
  (void))

;; speech-synthesis-speaking? : speech-synthesis? -> boolean?
;;   Report whether speech is currently active.
(define (speech-synthesis-speaking? synthesis)
  (unless (speech-synthesis? synthesis)
    (raise-argument-error 'speech-synthesis-speaking? "speech-synthesis?" synthesis))
  (js-ref (speech-synthesis-raw synthesis) "speaking"))

;; speech-synthesis-paused? : speech-synthesis? -> boolean?
;;   Report whether speech is currently paused.
(define (speech-synthesis-paused? synthesis)
  (unless (speech-synthesis? synthesis)
    (raise-argument-error 'speech-synthesis-paused? "speech-synthesis?" synthesis))
  (js-ref (speech-synthesis-raw synthesis) "paused"))

;; speech-synthesis-pending? : speech-synthesis? -> boolean?
;;   Report whether utterances are queued.
(define (speech-synthesis-pending? synthesis)
  (unless (speech-synthesis? synthesis)
    (raise-argument-error 'speech-synthesis-pending? "speech-synthesis?" synthesis))
  (js-ref (speech-synthesis-raw synthesis) "pending"))

;; speech-synthesis-voices : speech-synthesis? -> vector?
;;   Return available speech voices as wrapped values.
(define (speech-synthesis-voices synthesis)
  (unless (speech-synthesis? synthesis)
    (raise-argument-error 'speech-synthesis-voices "speech-synthesis?" synthesis))
  (speech-vector-map
   speech-voice-info
   (js-array->vector
    (js-send/extern (speech-synthesis-raw synthesis) "getVoices" (vector)))))

;; speech-voice-name : speech-voice? -> string?
;;   Read a voice name.
(define (speech-voice-name voice)
  (unless (speech-voice? voice)
    (raise-argument-error 'speech-voice-name "speech-voice?" voice))
  (js-ref (speech-voice-raw voice) "name"))

;; speech-voice-lang : speech-voice? -> string?
;;   Read a BCP 47 language tag for a voice.
(define (speech-voice-lang voice)
  (unless (speech-voice? voice)
    (raise-argument-error 'speech-voice-lang "speech-voice?" voice))
  (js-ref (speech-voice-raw voice) "lang"))

;; speech-voice-default? : speech-voice? -> boolean?
;;   Report whether this is the default voice.
(define (speech-voice-default? voice)
  (unless (speech-voice? voice)
    (raise-argument-error 'speech-voice-default? "speech-voice?" voice))
  (js-ref (speech-voice-raw voice) "default"))

;; speech-voice-local-service? : speech-voice? -> boolean?
;;   Report whether this voice is provided locally.
(define (speech-voice-local-service? voice)
  (unless (speech-voice? voice)
    (raise-argument-error 'speech-voice-local-service? "speech-voice?" voice))
  (js-ref (speech-voice-raw voice) "localService"))

;; speech-voice-uri : speech-voice? -> string?
;;   Read the voice URI.
(define (speech-voice-uri voice)
  (unless (speech-voice? voice)
    (raise-argument-error 'speech-voice-uri "speech-voice?" voice))
  (js-ref (speech-voice-raw voice) "voiceURI"))

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
  (unless (speech-utterance? utterance)
    (raise-argument-error 'speech-utterance-on-end! "speech-utterance?" utterance))
  (define callback* (and callback
                         (speech-callback->external 'speech-utterance-on-end! callback)))
  (js-set! (speech-utterance-raw utterance) "onend" callback*)
  (void))

;; speech-utterance-on-error! : speech-utterance? (or/c procedure? external? #f) -> void?
;;   Set the onerror handler for an utterance.
(define (speech-utterance-on-error! utterance callback)
  (unless (speech-utterance? utterance)
    (raise-argument-error 'speech-utterance-on-error! "speech-utterance?" utterance))
  (define callback* (and callback
                         (speech-callback->external 'speech-utterance-on-error! callback)))
  (js-set! (speech-utterance-raw utterance) "onerror" callback*)
  (void))
