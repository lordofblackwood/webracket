#lang webracket/base

;; Browser smoke for a small JSXGraph board/point path using a host mock.

(require jsxgraph
         webracket/primitives
         (only-in webracket/unsafe/standard
                  js-eval))

(define epsilon 0.000001)

(define (check-equal got want label)
  (unless (equal? got want)
    (error 'check-equal (format "~a: got ~s want ~s" label got want))))

(define (check-true got label)
  (unless got
    (error 'check-true label)))

(define (check-number~= got want label)
  (unless (<= (abs (- got want)) epsilon)
    (error 'check-number~=
           (format "~a: got ~s want ~s" label got want))))

(define (check-vector~= got want label)
  (check-equal (vector-length got) (vector-length want) label)
  (for ([i (in-range (vector-length got))])
    (check-number~= (vector-ref got i)
                    (vector-ref want i)
                    label)))

(js-eval
 "const host = document.createElement('div');
  host.id = 'jsxgraph-smoke-host';
  document.body.appendChild(host);

  function makePoint(board, parents, attrs) {
    const x = Number(parents[0] || 0);
    const y = Number(parents[1] || 0);
    return {
      __jsxKind: 'point',
      board,
      parents,
      attrs,
      size: 4,
      sizeUnit: 'screen',
      snapToGrid: false,
      zoom: true,
      X() { return x; },
      Y() { return y; },
      hasPoint(px, py) { return px === x && py === y; },
      normalizeFace(face) { return face; },
      setStyle(style) { this.style = style; },
      update(finalize) { this.updated = finalize; },
      updateRenderer() { this.rendererUpdated = true; },
      updateTransform(finalize) {
        this.transformUpdated = finalize;
        return this;
      }
    };
  }

  globalThis.__wrJsxIsPointThisOk = false;
  globalThis.JXG = {
    isPoint(value) {
      globalThis.__wrJsxIsPointThisOk = this === globalThis.JXG;
      return !!value && value.__jsxKind === 'point';
    },
    JSXGraph: {
      initBoard(containerId, attrs) {
        const container = document.getElementById(containerId);
        return {
          id: containerId,
          container,
          renderer: {kind: 'renderer'},
          canvasWidth: 640,
          canvasHeight: 480,
          boundingBox: [-5, 5, 5, -5],
          numObjects: 0,
          objects: {},
          attrs,
          create(type, parents, attrs) {
            const nextId = `obj${this.numObjects}`;
            const obj = type === 'point'
              ? makePoint(this, parents, attrs)
              : {__jsxKind: type, board: this, parents, attrs};
            this.objects[nextId] = obj;
            this.numObjects += 1;
            return obj;
          },
          update() {},
          fullUpdate() {},
          suspendUpdate() {},
          unsuspendUpdate() {}
        };
      }
    }
  };")

(define board
  (jsx-create-board "jsxgraph-smoke-host"
                    (jsx-attributes [axis #t])))

(check-true (jsx-board? board) "board wrapper")
(check-equal (jsx-board-id board) "jsxgraph-smoke-host" "board id")
(check-equal (jsx-board-canvas-width board) 640 "board width")
(check-equal (jsx-board-canvas-height board) 480 "board height")
(check-vector~= (jsx-board-bounding-box board) #(-5 5 5 -5) "bounding box")
(check-equal (jsx-board-num-objects board) 0 "initial object count")

(define point
  (jsx-create-point board
                    (jsx-parents 1.0 2.0)
                    (jsx-attributes [name "P"])))

(check-true (jsx-point? point) "point wrapper")
(check-true (jsx-point?/raw (jsx-point-raw point)) "raw point predicate")
(check-true (js-eval "globalThis.__wrJsxIsPointThisOk")
            "raw point predicate receiver")
(check-number~= (jsx-point-x point) 1.0 "point x")
(check-number~= (jsx-point-y point) 2.0 "point y")
(check-number~= (jsx-point-size point) 4.0 "point size")
(jsx-set-point-size! point 8.0)
(check-number~= (jsx-point-size point) 8.0 "updated point size")
(jsx-set-point-snap-to-grid! point #t)
(check-true (jsx-point-snap-to-grid point) "snap to grid")
(check-true (jsx-point-has-point point 1.0 2.0) "point hit test")
(check-equal (jsx-point-normalize-face point "circle") "circle" "normalize face")
(check-equal (jsx-board-num-objects board) 1 "object count")
(check-equal (vector-length (jsx-board-objects-list board)) 1 "objects list")

(jsx-point-update! point 1)
(jsx-point-update-renderer! point)
(check-true (external? (jsx-point-update-transform! point 1))
            "update transform result")

(js-log "jsxgraph-ffi-ok")
#t
