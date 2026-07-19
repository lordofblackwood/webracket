#lang webracket/base

;; Browser smoke for Web Speech wrapper surface behavior.

(require web-speech
         (only-in webracket/unsafe/dom
                  js-eval
                  js-ref)
         (only-in webracket/primitives
                  external?))

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal label)))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-false got label)
  (when got
    (error 'check-false label)))

(js-eval
 "globalThis.__wrSpeechSurfaceSaved = {
    speechSynthesis: Object.getOwnPropertyDescriptor(window, 'speechSynthesis'),
    SpeechSynthesisUtterance: globalThis.SpeechSynthesisUtterance
  };
  globalThis.__wrSpeechSurfaceVoiceA = {
    name: 'Ava',
    lang: 'en-US',
    default: true,
    localService: true,
    voiceURI: 'voice:ava'
  };
  globalThis.__wrSpeechSurfaceVoiceB = {
    name: 'Bo',
    lang: 'da-DK',
    default: false,
    localService: false,
    voiceURI: 'voice:bo'
  };
  globalThis.__wrSpeechSurfaceSynth = {
    speaking: false,
    paused: false,
    pending: false,
    calls: [],
    speak(utterance) {
      this.calls.push(['speak', utterance.text]);
      this.speaking = true;
      this.pending = true;
      this.lastUtterance = utterance;
    },
    cancel() {
      this.calls.push(['cancel']);
      this.speaking = false;
      this.pending = false;
    },
    pause() {
      this.calls.push(['pause']);
      this.paused = true;
    },
    resume() {
      this.calls.push(['resume']);
      this.paused = false;
    },
    getVoices() {
      return [globalThis.__wrSpeechSurfaceVoiceA,
              globalThis.__wrSpeechSurfaceVoiceB];
    }
  };
  globalThis.SpeechSynthesisUtterance =
    class SpeechSynthesisUtterance {
      constructor(text) {
        this.text = text;
        this.lang = '';
        this.volume = 1;
        this.rate = 1;
        this.pitch = 1;
        this.voice = null;
        this.onend = null;
        this.onerror = null;
      }
    };
  Object.defineProperty(window, 'speechSynthesis', {
    value: globalThis.__wrSpeechSurfaceSynth,
    configurable: true,
    writable: true
  });
  globalThis.__wrSpeechSurfaceRestore = () => {
    const saved = globalThis.__wrSpeechSurfaceSaved;
    if (saved.speechSynthesis) {
      Object.defineProperty(window, 'speechSynthesis', saved.speechSynthesis);
    } else {
      delete window.speechSynthesis;
    }
    if (saved.SpeechSynthesisUtterance === undefined) {
      delete globalThis.SpeechSynthesisUtterance;
    } else {
      globalThis.SpeechSynthesisUtterance = saved.SpeechSynthesisUtterance;
    }
    delete globalThis.__wrSpeechSurfaceSaved;
    delete globalThis.__wrSpeechSurfaceVoiceA;
    delete globalThis.__wrSpeechSurfaceVoiceB;
    delete globalThis.__wrSpeechSurfaceSynth;
    delete globalThis.__wrSpeechSurfaceRestore;
  };")

(check-true (web-speech-synthesis-supported?)
            "mocked speech synthesis reports supported")

(define synth (speech-synthesis))
(check-true (speech-synthesis? synth)
            "speech-synthesis returns wrapper")
(check-false (speech-synthesis-speaking? synth)
             "initial speaking")
(check-false (speech-synthesis-paused? synth)
             "initial paused")
(check-false (speech-synthesis-pending? synth)
             "initial pending")

(define voices (speech-synthesis-voices synth))
(check-equal (vector-length voices) 2 "voice count")
(define voice (vector-ref voices 0))
(check-true (speech-voice? voice) "voice wrapper")
(check-equal (speech-voice-name voice) "Ava" "voice name")
(check-equal (speech-voice-lang voice) "en-US" "voice lang")
(check-true (speech-voice-default? voice) "voice default")
(check-true (speech-voice-local-service? voice) "voice local service")
(check-equal (speech-voice-uri voice) "voice:ava" "voice URI")

(define utterance
  (make-speech-utterance
   "Hello from WebRacket"
   (make-speech-utterance-options "en-US" 0.75 1.25 1.5)))
(check-true (speech-utterance? utterance) "utterance wrapper")
(check-equal (js-ref (speech-utterance-raw utterance) "text")
             "Hello from WebRacket"
             "utterance text")
(check-equal (js-ref (speech-utterance-raw utterance) "lang")
             "en-US"
             "utterance lang")
(check-equal (js-ref (speech-utterance-raw utterance) "volume")
             0.75
             "utterance volume")
(check-equal (js-ref (speech-utterance-raw utterance) "rate")
             1.25
             "utterance rate")
(check-equal (js-ref (speech-utterance-raw utterance) "pitch")
             1.5
             "utterance pitch")

(speech-utterance-set-voice! utterance voice)
(check-equal (js-ref (js-ref (speech-utterance-raw utterance) "voice") "name")
             "Ava"
             "utterance voice")

(speech-utterance-on-end! utterance (lambda (_evt) (void)))
(speech-utterance-on-error! utterance (lambda (_evt) (void)))
(check-true (external? (js-ref (speech-utterance-raw utterance) "onend"))
            "utterance onend external")
(check-true (external? (js-ref (speech-utterance-raw utterance) "onerror"))
            "utterance onerror external")

(speech-synthesis-speak! synth utterance)
(check-true (speech-synthesis-speaking? synth) "speaking after speak")
(check-true (speech-synthesis-pending? synth) "pending after speak")
(speech-synthesis-pause! synth)
(check-true (speech-synthesis-paused? synth) "paused after pause")
(speech-synthesis-resume! synth)
(check-false (speech-synthesis-paused? synth) "paused after resume")
(speech-synthesis-cancel! synth)
(check-false (speech-synthesis-speaking? synth) "speaking after cancel")
(check-false (speech-synthesis-pending? synth) "pending after cancel")

(js-eval "__wrSpeechSurfaceRestore();")

(js-log "web-speech-surface-ok")
#t
