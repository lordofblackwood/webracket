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
 "globalThis.__wrAudioBoundarySaved = {
    AudioContext: globalThis.AudioContext,
    AudioNode: globalThis.AudioNode,
    AudioParam: globalThis.AudioParam,
    AudioBuffer: globalThis.AudioBuffer,
    GainNode: globalThis.GainNode,
    OscillatorNode: globalThis.OscillatorNode,
    AudioBufferSourceNode: globalThis.AudioBufferSourceNode,
    AnalyserNode: globalThis.AnalyserNode,
    BiquadFilterNode: globalThis.BiquadFilterNode,
    ConstantSourceNode: globalThis.ConstantSourceNode,
    DynamicsCompressorNode: globalThis.DynamicsCompressorNode,
    PannerNode: globalThis.PannerNode,
    StereoPannerNode: globalThis.StereoPannerNode,
    ChannelSplitterNode: globalThis.ChannelSplitterNode,
    ChannelMergerNode: globalThis.ChannelMergerNode,
    Float32Array: globalThis.Float32Array,
    Uint8Array: globalThis.Uint8Array
  };
  globalThis.AudioContext = {};
  globalThis.AudioNode = {};
  globalThis.__wrAudioBoundaryPlain = {};")

(define null-raw (js-null))
(define undefined-raw (js-undefined))
(define null-raw-periodic-wave (audio-periodic-wave null-raw))
(define undefined-raw-periodic-wave (audio-periodic-wave undefined-raw))

(check-false (audio-raw-host-value? null-raw)
             "audio raw host value rejects null")
(check-false (audio-raw-host-value? undefined-raw)
             "audio raw host value rejects undefined")
(check-false (audio-context? null-raw)
             "audio-context? rejects null")
(check-false (audio-node? undefined-raw)
             "audio-node? rejects undefined")
(check-false (audio-param? null-raw)
             "audio-param? rejects null")
(check-false (audio-buffer? undefined-raw)
             "audio-buffer? rejects undefined")
(check-false (audio-listener-wrap null-raw)
             "audio-listener-wrap maps null to #f")
(check-false (audio-listener-wrap undefined-raw)
             "audio-listener-wrap maps undefined to #f")
(check-false (audio-periodic-wave-wrap null-raw)
             "audio-periodic-wave-wrap maps null to #f")
(check-false (audio-periodic-wave-wrap undefined-raw)
             "audio-periodic-wave-wrap maps undefined to #f")
(check-false (audio-periodic-wave-host-value? null-raw-periodic-wave)
             "audio periodic wave host value rejects wrapped null")
(check-false (audio-periodic-wave-host-value? undefined-raw-periodic-wave)
             "audio periodic wave host value rejects wrapped undefined")
(check-false (audio-host-method-present? null-raw "connect")
             "audio host method check rejects null target")
(check-false (audio-host-method-present? undefined-raw "connect")
             "audio host method check rejects undefined target")

(js-eval "globalThis.Float32Array = undefined;")

(define missing-float32-array-message
  (catch-message
   (lambda ()
     (audio-vector->js-float32-array #(0.0 1.0)))))

(js-eval "globalThis.Float32Array = (() => false);")

(define non-constructor-float32-array-message
  (catch-message
   (lambda ()
     (audio-make-js-float32-array 2))))

(js-eval
 "globalThis.Float32Array = globalThis.__wrAudioBoundarySaved.Float32Array;
  globalThis.Uint8Array = undefined;")

(define missing-uint8-array-message
  (catch-message
   (lambda ()
     (audio-make-js-uint8-array 2))))

(js-eval "globalThis.Uint8Array = (() => false);")

(define non-constructor-uint8-array-message
  (catch-message
   (lambda ()
     (audio-make-js-uint8-array 2))))

(js-eval "globalThis.Uint8Array = globalThis.__wrAudioBoundarySaved.Uint8Array;")

(define null-host-method-message
  (catch-message
   (lambda ()
     (check-audio-host-method 'audio-null-host-method
                              null-raw
                              "AudioNode"
                              "connect"))))

(define null-periodic-wave-message
  (catch-message
   (lambda ()
     (check-audio-periodic-wave 'audio-null-periodic-wave
                                null-raw-periodic-wave))))

(define undefined-periodic-wave-message
  (catch-message
   (lambda ()
     (check-audio-periodic-wave 'audio-undefined-periodic-wave
                                undefined-raw-periodic-wave))))

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
  globalThis.AudioContext = class AudioContext {};
  globalThis.AudioParam = class AudioParam {};
  globalThis.AudioBuffer = class AudioBuffer {};
  globalThis.GainNode = class GainNode extends AudioNode {};
  globalThis.OscillatorNode = class OscillatorNode extends AudioNode {};
  globalThis.AudioBufferSourceNode = class AudioBufferSourceNode extends AudioNode {};
  globalThis.AnalyserNode = class AnalyserNode extends AudioNode {};
  globalThis.BiquadFilterNode = class BiquadFilterNode extends AudioNode {};
  globalThis.ConstantSourceNode = class ConstantSourceNode extends AudioNode {};
  globalThis.DynamicsCompressorNode = class DynamicsCompressorNode extends AudioNode {};
  globalThis.PannerNode = class PannerNode extends AudioNode {};
  globalThis.StereoPannerNode = class StereoPannerNode extends AudioNode {};
  globalThis.ChannelSplitterNode = class ChannelSplitterNode extends AudioNode {};
  globalThis.ChannelMergerNode = class ChannelMergerNode extends AudioNode {};
  globalThis.__wrAudioBoundaryNode = new AudioNode();")

(define node-without-listeners
  (js-eval "globalThis.__wrAudioBoundaryNode"))
(define context-without-handler
  (js-eval "new AudioContext()"))
(define param-without-surface
  (js-eval "new AudioParam()"))
(define buffer-without-surface
  (js-eval "new AudioBuffer()"))
(define gain-without-surface
  (js-eval "new GainNode()"))
(define oscillator-without-surface
  (js-eval "new OscillatorNode()"))
(define buffer-source-without-surface
  (js-eval "new AudioBufferSourceNode()"))
(define analyser-without-surface
  (js-eval "new AnalyserNode()"))
(define biquad-without-surface
  (js-eval "new BiquadFilterNode()"))
(define constant-without-surface
  (js-eval "new ConstantSourceNode()"))
(define dynamics-without-surface
  (js-eval "new DynamicsCompressorNode()"))
(define panner-without-surface
  (js-eval "new PannerNode()"))
(define stereo-panner-without-surface
  (js-eval "new StereoPannerNode()"))
(define splitter-without-surface
  (js-eval "new ChannelSplitterNode()"))
(define merger-without-surface
  (js-eval "new ChannelMergerNode()"))
(define noop-listener (lambda (_evt) (void)))

(check-false (audio-context? context-without-handler)
             "audio-context? rejects missing context surface")
(check-false (audio-node? node-without-listeners)
             "audio-node? rejects missing node surface")
(check-false (audio-param? param-without-surface)
             "audio-param? rejects missing param surface")
(check-false (audio-buffer? buffer-without-surface)
             "audio-buffer? rejects missing buffer surface")
(check-false (audio-gain-node? gain-without-surface)
             "audio-gain-node? rejects missing gain surface")
(check-false (audio-oscillator-node? oscillator-without-surface)
             "audio-oscillator-node? rejects missing oscillator surface")
(check-false (audio-buffer-source-node? buffer-source-without-surface)
             "audio-buffer-source-node? rejects missing buffer-source surface")
(check-false (audio-analyser-node? analyser-without-surface)
             "audio-analyser-node? rejects missing analyser surface")
(check-false (audio-biquad-filter-node? biquad-without-surface)
             "audio-biquad-filter-node? rejects missing biquad surface")
(check-false (audio-constant-source-node? constant-without-surface)
             "audio-constant-source-node? rejects missing constant-source surface")
(check-false (audio-dynamics-compressor-node? dynamics-without-surface)
             "audio-dynamics-compressor-node? rejects missing dynamics surface")
(check-false (audio-panner-node? panner-without-surface)
             "audio-panner-node? rejects missing panner surface")
(check-false (audio-stereo-panner-node? stereo-panner-without-surface)
             "audio-stereo-panner-node? rejects missing stereo-panner surface")
(check-false (audio-channel-splitter-node? splitter-without-surface)
             "audio-channel-splitter-node? rejects missing splitter surface")
(check-false (audio-channel-merger-node? merger-without-surface)
             "audio-channel-merger-node? rejects missing merger surface")

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

(define node-onended-message
  (catch-message
   (lambda ()
     (audio-oscillator-node-onended! node-without-listeners noop-listener))))

(define context-onstatechange-message
  (catch-message
   (lambda ()
     (audio-context-onstatechange! context-without-handler noop-listener))))

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
  globalThis.AudioParam = globalThis.__wrAudioBoundarySaved.AudioParam;
  globalThis.AudioBuffer = globalThis.__wrAudioBoundarySaved.AudioBuffer;
  globalThis.GainNode = globalThis.__wrAudioBoundarySaved.GainNode;
  globalThis.OscillatorNode = globalThis.__wrAudioBoundarySaved.OscillatorNode;
  globalThis.AudioBufferSourceNode = globalThis.__wrAudioBoundarySaved.AudioBufferSourceNode;
  globalThis.AnalyserNode = globalThis.__wrAudioBoundarySaved.AnalyserNode;
  globalThis.BiquadFilterNode = globalThis.__wrAudioBoundarySaved.BiquadFilterNode;
  globalThis.ConstantSourceNode = globalThis.__wrAudioBoundarySaved.ConstantSourceNode;
  globalThis.DynamicsCompressorNode = globalThis.__wrAudioBoundarySaved.DynamicsCompressorNode;
  globalThis.PannerNode = globalThis.__wrAudioBoundarySaved.PannerNode;
  globalThis.StereoPannerNode = globalThis.__wrAudioBoundarySaved.StereoPannerNode;
  globalThis.ChannelSplitterNode = globalThis.__wrAudioBoundarySaved.ChannelSplitterNode;
  globalThis.ChannelMergerNode = globalThis.__wrAudioBoundarySaved.ChannelMergerNode;
  globalThis.Float32Array = globalThis.__wrAudioBoundarySaved.Float32Array;
  globalThis.Uint8Array = globalThis.__wrAudioBoundarySaved.Uint8Array;
  delete globalThis.__wrAudioBoundarySaved;
  delete globalThis.__wrAudioBoundaryPlain;
  delete globalThis.__wrAudioBoundaryNode;")

(check-message add-listener-message
               "EventTarget.addEventListener is not available"
               "missing audio addEventListener message")
(check-message remove-listener-message
               "EventTarget.removeEventListener is not available"
               "missing audio removeEventListener message")
(check-message node-onended-message
               "AudioNode.onended is not available"
               "missing AudioNode.onended message")
(check-message context-onstatechange-message
               "AudioContext.onstatechange is not available"
               "missing AudioContext.onstatechange message")
(check-message null-host-method-message
               "AudioNode.connect is not available"
               "missing null audio host method message")
(check-message missing-float32-array-message
               "Float32Array not available in this environment"
               "missing Float32Array constructor message")
(check-message non-constructor-float32-array-message
               "Float32Array not available in this environment"
               "non-constructible Float32Array constructor message")
(check-message missing-uint8-array-message
               "Uint8Array not available in this environment"
               "missing Uint8Array constructor message")
(check-message non-constructor-uint8-array-message
               "Uint8Array not available in this environment"
               "non-constructible Uint8Array constructor message")
(check-message null-periodic-wave-message
               "audio-periodic-wave?"
               "missing null PeriodicWave wrapper message")
(check-message undefined-periodic-wave-message
               "audio-periodic-wave?"
               "missing undefined PeriodicWave wrapper message")
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
