#lang webracket/base

;; Browser smoke for Web Audio wrapper and raw FFI host-method boundaries.

(require audio
         (only-in webracket/unsafe/audio
                  js-audio-audio-buffer-source-node-start!
                  js-audio-audio-buffer-source-node-buffer
                  js-audio-audio-buffer-source-node-loop
                  js-audio-audio-buffer-source-node-set-buffer!
                  js-audio-audio-buffer-source-node-set-loop!
                  js-audio-analyser-node-get-byte-frequency-data!
                  js-audio-analyser-node-fft-size
                  js-audio-analyser-node-set-fft-size!
                  js-audio-biquad-filter-node-q
                  js-audio-biquad-filter-node-set-type!
                  js-audio-buffer-get-channel-data
                  js-audio-buffer-length
                  js-audio-constant-source-node-start!
                  js-audio-constant-source-node-offset
                  js-audio-context-close
                  js-audio-context-create-gain
                  js-audio-context-decode-audio-data
                  js-audio-context-state
                  js-audio-dynamics-compressor-node-threshold
                  js-audio-gain-node-gain
                  js-audio-node-connect
                  js-audio-node-context
                  js-audio-oscillator-node-start!
                  js-audio-oscillator-node-set-type!
                  js-audio-oscillator-node-type
                  js-audio-panner-node-panning-model
                  js-audio-panner-node-position-x
                  js-audio-panner-node-set-panning-model!
                  js-audio-param-set-value!
                  js-audio-param-value
                  js-audio-param-set-value-at-time!
                  js-audio-stereo-panner-node-pan)
         (only-in webracket/unsafe/standard
                  js-eval))

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
 "globalThis.__wrAudioBoundarySaved = {
    AudioContext: globalThis.AudioContext,
    AudioNode: globalThis.AudioNode
  };
  globalThis.AudioContext = {};
  globalThis.AudioNode = {};
  globalThis.__wrAudioBoundaryPlain = {};")

(check-false (audio-context? (js-eval "globalThis.__wrAudioBoundaryPlain"))
             "audio-context? returns #f when AudioContext is not callable")
(check-false (audio-node? (js-eval "globalThis.__wrAudioBoundaryPlain"))
             "audio-node? returns #f when AudioNode is not callable")

(js-eval
 "globalThis.AudioContext = (() => false);
  globalThis.AudioNode = (() => false);")

(define audio-context-non-constructor-message
  (catch-message
   (lambda ()
     (audio-context-new))))

(check-false (audio-context? (js-eval "globalThis.__wrAudioBoundaryPlain"))
             "audio-context? returns #f when AudioContext is not constructible")
(check-false (audio-node? (js-eval "globalThis.__wrAudioBoundaryPlain"))
             "audio-node? returns #f when AudioNode is not constructible")

(js-eval
 "globalThis.AudioNode = class AudioNode {};
  globalThis.__wrAudioBoundaryNode = new AudioNode();")

(define node-without-listeners
  (js-eval "globalThis.__wrAudioBoundaryNode"))
(define noop-listener (lambda (_evt) (void)))

(define add-listener-message
  (catch-message
   (lambda ()
     (audio-add-event-listener! node-without-listeners
                                'ended
                                noop-listener))))

(define remove-listener-message
  (catch-message
   (lambda ()
     (audio-remove-event-listener! node-without-listeners
                                   'ended
                                   noop-listener))))

(define fake-object
  (js-eval "globalThis.__wrAudioBoundaryPlain"))

(define context-close-message
  (catch-message
   (lambda ()
     (js-audio-context-close fake-object))))

(define create-gain-message
  (catch-message
   (lambda ()
     (js-audio-context-create-gain fake-object))))

(define decode-message
  (catch-message
   (lambda ()
     (js-audio-context-decode-audio-data fake-object (bytes)))))

(define node-connect-message
  (catch-message
   (lambda ()
     (js-audio-node-connect fake-object #f (void) (void)))))

(define context-state-message
  (catch-message
   (lambda ()
     (js-audio-context-state fake-object))))

(define node-context-message
  (catch-message
   (lambda ()
     (js-audio-node-context fake-object))))

(define param-value-message
  (catch-message
   (lambda ()
     (js-audio-param-value fake-object))))

(define param-value-setter-message
  (catch-message
   (lambda ()
     (js-audio-param-set-value! fake-object 1.0))))

(define param-set-message
  (catch-message
   (lambda ()
     (js-audio-param-set-value-at-time! fake-object 1.0 0.0))))

(define buffer-length-message
  (catch-message
   (lambda ()
     (js-audio-buffer-length fake-object))))

(define buffer-data-message
  (catch-message
   (lambda ()
     (js-audio-buffer-get-channel-data fake-object 0))))

(define gain-node-gain-message
  (catch-message
   (lambda ()
     (js-audio-gain-node-gain fake-object))))

(define oscillator-type-message
  (catch-message
   (lambda ()
     (js-audio-oscillator-node-type fake-object))))

(define oscillator-type-setter-message
  (catch-message
   (lambda ()
     (js-audio-oscillator-node-set-type! fake-object "sine"))))

(define oscillator-start-message
  (catch-message
   (lambda ()
     (js-audio-oscillator-node-start! fake-object (void)))))

(define buffer-source-buffer-message
  (catch-message
   (lambda ()
     (js-audio-audio-buffer-source-node-buffer fake-object))))

(define buffer-source-buffer-setter-message
  (catch-message
   (lambda ()
     (js-audio-audio-buffer-source-node-set-buffer! fake-object #f))))

(define buffer-source-loop-message
  (catch-message
   (lambda ()
     (js-audio-audio-buffer-source-node-loop fake-object))))

(define buffer-source-loop-setter-message
  (catch-message
   (lambda ()
     (js-audio-audio-buffer-source-node-set-loop! fake-object #t))))

(define buffer-source-start-message
  (catch-message
   (lambda ()
     (js-audio-audio-buffer-source-node-start! fake-object
                                               (void)
                                               (void)
                                               (void)))))

(define analyser-fft-size-message
  (catch-message
   (lambda ()
     (js-audio-analyser-node-fft-size fake-object))))

(define analyser-fft-size-setter-message
  (catch-message
   (lambda ()
     (js-audio-analyser-node-set-fft-size! fake-object 1024))))

(define analyser-byte-message
  (catch-message
   (lambda ()
     (js-audio-analyser-node-get-byte-frequency-data! fake-object
                                                       (bytes 0 0 0 0)))))

(define biquad-q-message
  (catch-message
   (lambda ()
     (js-audio-biquad-filter-node-q fake-object))))

(define biquad-type-setter-message
  (catch-message
   (lambda ()
     (js-audio-biquad-filter-node-set-type! fake-object "lowpass"))))

(define constant-offset-message
  (catch-message
   (lambda ()
     (js-audio-constant-source-node-offset fake-object))))

(define constant-start-message
  (catch-message
   (lambda ()
     (js-audio-constant-source-node-start! fake-object (void)))))

(define dynamics-threshold-message
  (catch-message
   (lambda ()
     (js-audio-dynamics-compressor-node-threshold fake-object))))

(define panner-model-message
  (catch-message
   (lambda ()
     (js-audio-panner-node-panning-model fake-object))))

(define panner-model-setter-message
  (catch-message
   (lambda ()
     (js-audio-panner-node-set-panning-model! fake-object "equalpower"))))

(define panner-position-message
  (catch-message
   (lambda ()
     (js-audio-panner-node-position-x fake-object))))

(define stereo-pan-message
  (catch-message
   (lambda ()
     (js-audio-stereo-panner-node-pan fake-object))))

(js-eval
 "globalThis.AudioContext = globalThis.__wrAudioBoundarySaved.AudioContext;
  globalThis.AudioNode = globalThis.__wrAudioBoundarySaved.AudioNode;
  delete globalThis.__wrAudioBoundarySaved;
  delete globalThis.__wrAudioBoundaryPlain;
  delete globalThis.__wrAudioBoundaryNode;")

(check-message add-listener-message
               "EventTarget.addEventListener is not available"
               "missing audio addEventListener message")
(check-message remove-listener-message
               "EventTarget.removeEventListener is not available"
               "missing audio removeEventListener message")
(check-message audio-context-non-constructor-message
               "AudioContext not available in this environment: context-new"
               "non-constructible AudioContext constructor message")
(check-message context-close-message
               "AudioContext.close not available in this environment"
               "missing AudioContext.close message")
(check-message create-gain-message
               "AudioContext.createGain not available in this environment"
               "missing AudioContext.createGain message")
(check-message decode-message
               "AudioContext.decodeAudioData not available in this environment"
               "missing AudioContext.decodeAudioData message")
(check-message node-connect-message
               "AudioNode.connect not available in this environment"
               "missing AudioNode.connect message")
(check-message context-state-message
               "AudioContext.state not available in this environment"
               "missing AudioContext.state message")
(check-message node-context-message
               "AudioNode.context not available in this environment"
               "missing AudioNode.context message")
(check-message param-value-message
               "AudioParam.value not available in this environment"
               "missing AudioParam.value message")
(check-message param-value-setter-message
               "AudioParam.value not available in this environment"
               "missing AudioParam.value setter message")
(check-message param-set-message
               "AudioParam.setValueAtTime not available in this environment"
               "missing AudioParam.setValueAtTime message")
(check-message buffer-length-message
               "AudioBuffer.length not available in this environment"
               "missing AudioBuffer.length message")
(check-message buffer-data-message
               "AudioBuffer.getChannelData not available in this environment"
               "missing AudioBuffer.getChannelData message")
(check-message gain-node-gain-message
               "GainNode.gain not available in this environment"
               "missing GainNode.gain message")
(check-message oscillator-type-message
               "OscillatorNode.type not available in this environment"
               "missing OscillatorNode.type message")
(check-message oscillator-type-setter-message
               "OscillatorNode.type not available in this environment"
               "missing OscillatorNode.type setter message")
(check-message oscillator-start-message
               "OscillatorNode.start not available in this environment"
               "missing OscillatorNode.start message")
(check-message buffer-source-buffer-message
               "AudioBufferSourceNode.buffer not available in this environment"
               "missing AudioBufferSourceNode.buffer message")
(check-message buffer-source-buffer-setter-message
               "AudioBufferSourceNode.buffer not available in this environment"
               "missing AudioBufferSourceNode.buffer setter message")
(check-message buffer-source-loop-message
               "AudioBufferSourceNode.loop not available in this environment"
               "missing AudioBufferSourceNode.loop message")
(check-message buffer-source-loop-setter-message
               "AudioBufferSourceNode.loop not available in this environment"
               "missing AudioBufferSourceNode.loop setter message")
(check-message buffer-source-start-message
               "AudioBufferSourceNode.start not available in this environment"
               "missing AudioBufferSourceNode.start message")
(check-message analyser-fft-size-message
               "AnalyserNode.fftSize not available in this environment"
               "missing AnalyserNode.fftSize message")
(check-message analyser-fft-size-setter-message
               "AnalyserNode.fftSize not available in this environment"
               "missing AnalyserNode.fftSize setter message")
(check-message analyser-byte-message
               "AnalyserNode.getByteFrequencyData not available in this environment"
               "missing AnalyserNode.getByteFrequencyData message")
(check-message biquad-q-message
               "BiquadFilterNode.Q not available in this environment"
               "missing BiquadFilterNode.Q message")
(check-message biquad-type-setter-message
               "BiquadFilterNode.type not available in this environment"
               "missing BiquadFilterNode.type setter message")
(check-message constant-offset-message
               "ConstantSourceNode.offset not available in this environment"
               "missing ConstantSourceNode.offset message")
(check-message constant-start-message
               "ConstantSourceNode.start not available in this environment"
               "missing ConstantSourceNode.start message")
(check-message dynamics-threshold-message
               "DynamicsCompressorNode.threshold not available in this environment"
               "missing DynamicsCompressorNode.threshold message")
(check-message panner-model-message
               "PannerNode.panningModel not available in this environment"
               "missing PannerNode.panningModel message")
(check-message panner-model-setter-message
               "PannerNode.panningModel not available in this environment"
               "missing PannerNode.panningModel setter message")
(check-message panner-position-message
               "PannerNode.positionX not available in this environment"
               "missing PannerNode.positionX message")
(check-message stereo-pan-message
               "StereoPannerNode.pan not available in this environment"
               "missing StereoPannerNode.pan message")

(js-log "audio-method-missing-host-ffi-ok")
#t
