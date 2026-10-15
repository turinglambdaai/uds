#lang info

(define version "0.1")
;; Multi-collection package shape: the collection is the `uds/` subdirectory.
;; `collection 'multi` is the standard declaration for this layout.
(define collection 'multi)
;; rackunit-lib is a run-time dependency (not merely a build-time one)
;; because the package ships its test suite, and the catalog's dependency
;; check scans shipped modules in run mode.
(define deps '("base" "rackunit-lib"))
(define build-deps '("base" "scribble-lib" "racket-doc" "rackunit-lib"))
(define pkg-desc "Pure-Racket ISO 14229 (Unified Diagnostic Services): service IDs, NRCs, DTCs, request builders and response parsers, transport-agnostic")
(define pkg-authors '("turinglambdaai"))
(define license 'MIT)
;; Collection-level scribblings declaration: for multi packages the
;; catalog doc build reads only this file, so the manual entry lives here.
(define scribblings '(["uds/scribblings/uds.scrbl" ()]))
(define test-omit-paths '("uds/scribblings"))
