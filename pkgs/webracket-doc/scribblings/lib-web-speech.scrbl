#lang scribble/manual

@(require scribble/manual
          (for-label (lib "scribblings/lib-web-speech-labels.rkt" "webracket-doc"))
          "webracket-scribble-utils.rkt")

@title{Library: @racketid[web-speech]}
@declare-exporting[(lib "scribblings/lib-web-speech-labels.rkt" "webracket-doc")]

@defmodule[web-speech]

The @racketmodname[web-speech] module wraps browser speech synthesis:
creating utterances, speaking/canceling them, reading voices, and setting
basic utterance options.

@(mdn-bar "Web Speech API"
          "https://developer.mozilla.org/en-US/docs/Web/API/Web_Speech_API")

@bold{Read MDN first.} Web Speech support varies substantially between
browsers. This first wrapper focuses on @tt{SpeechSynthesis}; speech
recognition is exposed only as a support predicate because browser support
and prefixes are still uneven.

@section{Web Speech Quick Start}

@racketblock[
(require web-speech)

(define synth (speech-synthesis))

(when synth
  (define utterance
    (make-speech-utterance
     "Hello from WebRacket"
     (make-speech-utterance-options "en-US" 1 1 1)))
  (speech-synthesis-speak! synth utterance))
]

@section{Web Speech API}

@defproc[(web-speech-synthesis-supported?) boolean?]{
@(mdn-bar "SpeechSynthesis"
          "https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesis")
Returns @racket[#t] when speech synthesis and @tt{SpeechSynthesisUtterance}
are available.
}

@defproc[(web-speech-recognition-supported?) boolean?]{
@(mdn-bar "SpeechRecognition"
          "https://developer.mozilla.org/en-US/docs/Web/API/SpeechRecognition")
Returns @racket[#t] when the browser exposes @tt{SpeechRecognition} or
@tt{webkitSpeechRecognition}. Recognition construction is not wrapped in
this first pass.
}

@defproc[(speech-synthesis) (or/c #f speech-synthesis?)]{
Returns the browser @tt{SpeechSynthesis} object wrapped in a checked value,
or @racket[#f] when unsupported.
}

@defproc[(speech-synthesis? [v any/c]) boolean?]{Returns @racket[#t] for wrapped @tt{SpeechSynthesis} values.}
@defproc[(speech-synthesis-raw [value speech-synthesis?]) external/raw]{Returns the wrapped raw @tt{SpeechSynthesis} object.}

@defproc[(make-speech-utterance-options [lang (or/c #f string? symbol?) #f]
                                        [volume (or/c #f (real-in 0 1)) #f]
                                        [rate (or/c #f (real-in 0.1 10)) #f]
                                        [pitch (or/c #f (real-in 0 2)) #f])
         speech-utterance-options?]{
Builds checked options for @racket[make-speech-utterance]. The defaults
leave browser defaults unchanged.
}

@defproc[(make-speech-utterance [text (or/c string? symbol?)]
                                [options (or/c #f speech-utterance-options?) #f])
         speech-utterance?]{
@(mdn-bar "SpeechSynthesisUtterance"
          "https://developer.mozilla.org/en-US/docs/Web/API/SpeechSynthesisUtterance")
Creates a browser utterance. Symbols are converted with
@racket[symbol->string].
}

@defproc[(speech-utterance? [v any/c]) boolean?]{Returns @racket[#t] for wrapped @tt{SpeechSynthesisUtterance} values.}
@defproc[(speech-utterance-raw [value speech-utterance?]) external/raw]{Returns the wrapped raw utterance object.}

@defproc[(speech-synthesis-speak! [synthesis speech-synthesis?]
                                  [utterance speech-utterance?])
         void?]{
Queues an utterance to be spoken.
}

@defproc[(speech-synthesis-cancel! [synthesis speech-synthesis?]) void?]{Cancels queued and active speech.}
@defproc[(speech-synthesis-pause! [synthesis speech-synthesis?]) void?]{Pauses active speech.}
@defproc[(speech-synthesis-resume! [synthesis speech-synthesis?]) void?]{Resumes paused speech.}
@defproc[(speech-synthesis-speaking? [synthesis speech-synthesis?]) boolean?]{Returns whether speech is active.}
@defproc[(speech-synthesis-paused? [synthesis speech-synthesis?]) boolean?]{Returns whether speech is paused.}
@defproc[(speech-synthesis-pending? [synthesis speech-synthesis?]) boolean?]{Returns whether utterances are queued.}

@defproc[(speech-synthesis-voices [synthesis speech-synthesis?]) vector?]{
Returns available voices as wrapped @tt{SpeechSynthesisVoice} values.
}

@defproc[(speech-voice? [v any/c]) boolean?]{Returns @racket[#t] for wrapped voice values.}
@defproc[(speech-voice-raw [value speech-voice?]) external/raw]{Returns the wrapped raw voice object.}
@defproc[(speech-voice-name [voice speech-voice?]) string?]{Returns the voice display name.}
@defproc[(speech-voice-lang [voice speech-voice?]) string?]{Returns the voice language tag.}
@defproc[(speech-voice-default? [voice speech-voice?]) boolean?]{Returns whether the voice is the default voice.}
@defproc[(speech-voice-local-service? [voice speech-voice?]) boolean?]{Returns whether the voice is provided locally.}
@defproc[(speech-voice-uri [voice speech-voice?]) string?]{Returns the voice URI.}

@defproc[(speech-utterance-set-voice! [utterance speech-utterance?]
                                      [voice speech-voice?])
         void?]{
Sets the voice used by an utterance. Use this when an example or
application should prefer a specific normal browser voice instead of leaving
voice selection entirely to the browser.
}

@defproc[(speech-utterance-on-end! [utterance speech-utterance?]
                                   [callback (or/c procedure? external? #f)])
         void?]{
Sets the utterance @tt{onend} handler. Pass @racket[#f] to clear it.
}

@defproc[(speech-utterance-on-error! [utterance speech-utterance?]
                                     [callback (or/c procedure? external? #f)])
         void?]{
Sets the utterance @tt{onerror} handler. Pass @racket[#f] to clear it.
}
