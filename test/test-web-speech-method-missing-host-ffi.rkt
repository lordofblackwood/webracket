#lang webracket/base

;; Browser smoke for Web Speech wrapper host-boundary errors.

(require web-speech
         (only-in webracket/unsafe/dom
                  js-eval
                  js-null
                  js-undefined))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-false got label)
  (when got
    (error 'check-false label)))

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
 "globalThis.__wrSpeechBoundarySaved = {
    speechSynthesis: Object.getOwnPropertyDescriptor(window, 'speechSynthesis'),
    SpeechSynthesisUtterance: globalThis.SpeechSynthesisUtterance
  };
  globalThis.__wrSpeechBoundaryInstallUtterance = () => {
    globalThis.SpeechSynthesisUtterance =
      class SpeechSynthesisUtterance {
        constructor(text) { this.text = text; }
      };
  };
  globalThis.__wrSpeechBoundaryHideUtterance = () => {
    globalThis.SpeechSynthesisUtterance = undefined;
  };
  globalThis.__wrSpeechBoundaryInstallNonConstructorUtterance = () => {
    globalThis.SpeechSynthesisUtterance = () => {};
  };
  globalThis.__wrSpeechBoundaryFakeSynthesis = (missing) => {
    const synth = {
      speaking: false,
      paused: false,
      pending: false,
      speak(_utterance) {},
      cancel() {},
      pause() {},
      resume() {},
      getVoices() { return []; }
    };
    delete synth[missing];
    return synth;
  };
  globalThis.__wrSpeechBoundaryFakeVoice = (missing) => {
    const voice = {
      name: 'Ava',
      lang: 'en-US',
      default: false,
      localService: true,
      voiceURI: 'voice:ava'
    };
    delete voice[missing];
    return voice;
  };
  globalThis.__wrSpeechBoundaryInstallSynthesis = (missing) => {
    Object.defineProperty(window, 'speechSynthesis', {
      value: globalThis.__wrSpeechBoundaryFakeSynthesis(missing),
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrSpeechBoundaryHideSynthesis = () => {
    Object.defineProperty(window, 'speechSynthesis', {
      value: undefined,
      configurable: true,
      writable: true
    });
  };
  globalThis.__wrSpeechBoundaryRestoreSynthesis = () => {
    const saved = globalThis.__wrSpeechBoundarySaved;
    if (saved.speechSynthesis) {
      Object.defineProperty(window, 'speechSynthesis', saved.speechSynthesis);
    } else {
      delete window.speechSynthesis;
    }
  };
  globalThis.__wrSpeechBoundaryRestore = () => {
    globalThis.__wrSpeechBoundaryRestoreSynthesis();
    const saved = globalThis.__wrSpeechBoundarySaved;
    if (saved.SpeechSynthesisUtterance === undefined) {
      delete globalThis.SpeechSynthesisUtterance;
    } else {
      globalThis.SpeechSynthesisUtterance = saved.SpeechSynthesisUtterance;
    }
    delete globalThis.__wrSpeechBoundarySaved;
    delete globalThis.__wrSpeechBoundaryInstallUtterance;
    delete globalThis.__wrSpeechBoundaryHideUtterance;
    delete globalThis.__wrSpeechBoundaryInstallNonConstructorUtterance;
    delete globalThis.__wrSpeechBoundaryFakeSynthesis;
    delete globalThis.__wrSpeechBoundaryFakeVoice;
    delete globalThis.__wrSpeechBoundaryInstallSynthesis;
    delete globalThis.__wrSpeechBoundaryHideSynthesis;
    delete globalThis.__wrSpeechBoundaryRestoreSynthesis;
    delete globalThis.__wrSpeechBoundaryRestore;
  };
  globalThis.__wrSpeechBoundaryInstallUtterance();")

(js-eval "__wrSpeechBoundaryHideSynthesis();")
(check-false (web-speech-synthesis-supported?)
             "missing speechSynthesis reports unsupported")
(check-false (speech-synthesis)
             "missing speechSynthesis returns #f")
(js-eval "__wrSpeechBoundaryInstallSynthesis('none');")

(js-eval "__wrSpeechBoundaryHideUtterance();")
(define utterance-constructor-message
  (catch-message
   (lambda ()
     (make-speech-utterance "hello"))))
(js-eval "__wrSpeechBoundaryInstallUtterance();")

(js-eval "__wrSpeechBoundaryInstallNonConstructorUtterance();")
(define utterance-non-constructor-message
  (catch-message
   (lambda ()
     (make-speech-utterance "hello"))))
(js-eval "__wrSpeechBoundaryInstallUtterance();")

(define utterance (make-speech-utterance "hello"))

(define (fake-synthesis missing)
  (speech-synthesis-info
   (js-eval (string-append "__wrSpeechBoundaryFakeSynthesis('"
                           missing
                           "')"))))

(define (fake-voice missing)
  (speech-voice-info
   (js-eval (string-append "__wrSpeechBoundaryFakeVoice('"
                           missing
                           "')"))))

(define null-raw-synthesis
  (speech-synthesis-info (js-null)))

(define undefined-raw-synthesis
  (speech-synthesis-info (js-undefined)))

(define null-raw-utterance
  (speech-utterance-info (js-null)))

(define undefined-raw-utterance
  (speech-utterance-info (js-undefined)))

(define null-raw-voice
  (speech-voice-info (js-null)))

(define undefined-raw-voice
  (speech-voice-info (js-undefined)))

(check-false (speech-synthesis? null-raw-synthesis)
             "speech-synthesis? rejects null raw")
(check-false (speech-synthesis? undefined-raw-synthesis)
             "speech-synthesis? rejects undefined raw")
(check-false (speech-utterance? null-raw-utterance)
             "speech-utterance? rejects null raw")
(check-false (speech-utterance? undefined-raw-utterance)
             "speech-utterance? rejects undefined raw")
(check-false (speech-voice? null-raw-voice)
             "speech-voice? rejects null raw")
(check-false (speech-voice? undefined-raw-voice)
             "speech-voice? rejects undefined raw")

(define speak-message
  (catch-message
   (lambda ()
     (speech-synthesis-speak! (fake-synthesis "speak") utterance))))

(define cancel-message
  (catch-message
   (lambda ()
     (speech-synthesis-cancel! (fake-synthesis "cancel")))))

(define pause-message
  (catch-message
   (lambda ()
     (speech-synthesis-pause! (fake-synthesis "pause")))))

(define resume-message
  (catch-message
   (lambda ()
     (speech-synthesis-resume! (fake-synthesis "resume")))))

(define voices-message
  (catch-message
   (lambda ()
     (speech-synthesis-voices (fake-synthesis "getVoices")))))

(define speaking-message
  (catch-message
   (lambda ()
     (speech-synthesis-speaking? (fake-synthesis "speaking")))))

(define paused-message
  (catch-message
   (lambda ()
     (speech-synthesis-paused? (fake-synthesis "paused")))))

(define pending-message
  (catch-message
   (lambda ()
     (speech-synthesis-pending? (fake-synthesis "pending")))))

(define voice-name-message
  (catch-message
   (lambda ()
     (speech-voice-name (fake-voice "name")))))

(define voice-lang-message
  (catch-message
   (lambda ()
     (speech-voice-lang (fake-voice "lang")))))

(define voice-default-message
  (catch-message
   (lambda ()
     (speech-voice-default? (fake-voice "default")))))

(define voice-local-service-message
  (catch-message
   (lambda ()
     (speech-voice-local-service? (fake-voice "localService")))))

(define voice-uri-message
  (catch-message
   (lambda ()
     (speech-voice-uri (fake-voice "voiceURI")))))

(define invalid-synthesis-message
  (catch-message
   (lambda ()
     (speech-synthesis-cancel! (speech-synthesis-info #f)))))

(define synthesis-null-raw-message
  (catch-message
   (lambda ()
     (speech-synthesis-cancel! null-raw-synthesis))))

(define synthesis-undefined-raw-message
  (catch-message
   (lambda ()
     (speech-synthesis-cancel! undefined-raw-synthesis))))

(define utterance-null-raw-message
  (catch-message
   (lambda ()
     (speech-utterance-on-end! null-raw-utterance #f))))

(define utterance-undefined-raw-message
  (catch-message
   (lambda ()
     (speech-utterance-on-end! undefined-raw-utterance #f))))

(define voice-null-raw-message
  (catch-message
   (lambda ()
     (speech-voice-name null-raw-voice))))

(define voice-undefined-raw-message
  (catch-message
   (lambda ()
     (speech-voice-name undefined-raw-voice))))

(check-message utterance-constructor-message
               "SpeechSynthesisUtterance constructor is not available"
               "missing SpeechSynthesisUtterance constructor message")
(check-message utterance-non-constructor-message
               "SpeechSynthesisUtterance constructor is not available"
               "non-constructible SpeechSynthesisUtterance constructor message")
(check-message speak-message
               "SpeechSynthesis.speak is not available"
               "missing SpeechSynthesis.speak message")
(check-message cancel-message
               "SpeechSynthesis.cancel is not available"
               "missing SpeechSynthesis.cancel message")
(check-message pause-message
               "SpeechSynthesis.pause is not available"
               "missing SpeechSynthesis.pause message")
(check-message resume-message
               "SpeechSynthesis.resume is not available"
               "missing SpeechSynthesis.resume message")
(check-message voices-message
               "SpeechSynthesis.getVoices is not available"
               "missing SpeechSynthesis.getVoices message")
(check-message speaking-message
               "SpeechSynthesis.speaking is not available"
               "missing SpeechSynthesis.speaking message")
(check-message paused-message
               "SpeechSynthesis.paused is not available"
               "missing SpeechSynthesis.paused message")
(check-message pending-message
               "SpeechSynthesis.pending is not available"
               "missing SpeechSynthesis.pending message")
(check-message voice-name-message
               "SpeechSynthesisVoice.name is not available"
               "missing SpeechSynthesisVoice.name message")
(check-message voice-lang-message
               "SpeechSynthesisVoice.lang is not available"
               "missing SpeechSynthesisVoice.lang message")
(check-message voice-default-message
               "SpeechSynthesisVoice.default is not available"
               "missing SpeechSynthesisVoice.default message")
(check-message voice-local-service-message
               "SpeechSynthesisVoice.localService is not available"
               "missing SpeechSynthesisVoice.localService message")
(check-message voice-uri-message
               "SpeechSynthesisVoice.voiceURI is not available"
               "missing SpeechSynthesisVoice.voiceURI message")
(check-message invalid-synthesis-message
               "speech-synthesis?"
               "missing speech synthesis invalid raw message")
(check-message synthesis-null-raw-message
               "speech-synthesis?"
               "missing speech synthesis null raw message")
(check-message synthesis-undefined-raw-message
               "speech-synthesis?"
               "missing speech synthesis undefined raw message")
(check-message utterance-null-raw-message
               "speech-utterance?"
               "missing speech utterance null raw message")
(check-message utterance-undefined-raw-message
               "speech-utterance?"
               "missing speech utterance undefined raw message")
(check-message voice-null-raw-message
               "speech-voice?"
               "missing speech voice null raw message")
(check-message voice-undefined-raw-message
               "speech-voice?"
               "missing speech voice undefined raw message")

(js-eval "__wrSpeechBoundaryRestore();")

(js-log "web-speech-method-missing-host-ffi-ok")
#t
