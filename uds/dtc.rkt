#lang racket/base

;; Diagnostic Trouble Codes (ISO 14229-1 / SAE J2012-DA): the 16-bit DTC
;; number, its 4-letter text form, the status byte, and the 3-byte records
;; carried by ReadDTCInformation responses.
;;
;; 16-bit number layout: bits 15-14 = system letter (P=00, C=01, B=10,
;; U=11); bits 13-12 = first digit (0-3); bits 11-8 / 7-4 / 3-0 = the
;; second, third, fourth digits as BCD (0-9).  E.g. "P0123" = 0x0123,
;; "C1234" = 0x4124, "U3456" = 0xF456.
;;
;; Status byte bits (ISO 14229-1 Annex D):
;;   0x01 testFailed                  0x10 testNotCompletedSinceLastClear
;;   0x02 testFailedThisOperationCycle 0x20 testFailedSinceLastClear
;;   0x04 pendingDTC                  0x40 testNotCompletedThisOperationCycle
;;   0x08 confirmedDTC                0x80 warningIndicatorRequested

(require racket/contract
         racket/format
         racket/list)

(provide (contract-out
          (struct dtc ((number (integer-in 0 65535))
                       (status-byte (integer-in 0 255))))
          [dtc-text->number (-> string? (integer-in 0 65535))]
          [dtc-number->text (-> (integer-in 0 65535) string?)]
          (struct dtc-status ((test-failed boolean?)
                              (test-failed-this-operation-cycle boolean?)
                              (pending boolean?)
                              (confirmed boolean?)
                              (test-not-completed-since-last-clear boolean?)
                              (test-failed-since-last-clear boolean?)
                              (test-not-completed-this-operation-cycle boolean?)
                              (warning-indicator-requested boolean?)))
          [make-dtc-status
           (->* ()
                (#:test-failed boolean?
                 #:test-failed-this-operation-cycle boolean?
                 #:pending boolean?
                 #:confirmed boolean?
                 #:test-not-completed-since-last-clear boolean?
                 #:test-failed-since-last-clear boolean?
                 #:test-not-completed-this-operation-cycle boolean?
                 #:warning-indicator-requested boolean?)
                dtc-status?)]
          [dtc-status->byte (-> dtc-status? (integer-in 0 255))]
          [byte->dtc-status (-> (integer-in 0 255) dtc-status?)]
          [dtc-bytes (-> (integer-in 0 65535) (integer-in 0 255) bytes?)]
          [parse-dtc-records (-> bytes? (listof dtc?))]
          (+dtc-group-all+ (integer-in 0 16777215))
          [dtc-group-bytes (-> (integer-in 0 16777215) bytes?)]))

(struct dtc (number status-byte) #:transparent)

;; ---------------------------------------------------------------------------
;; DTC number <-> text

(define +letters+ '(#\P #\C #\B #\U))

(define (dtc-text->number s)
  (define m (regexp-match #px"^([PCBU])([0-3])([0-9]{3})$" s))
  (unless m
    (error 'dtc-text->number "expected a DTC like P0123/C1234/B2345/U3456, got ~a" s))
  (define letter-index (index-of +letters+ (string-ref (list-ref m 1) 0)))
  (define first-digit (string->number (list-ref m 2)))
  ;; The three trailing digits each occupy one BCD nibble.
  (define digits (list-ref m 3))
  (+ (arithmetic-shift letter-index 14)
     (arithmetic-shift first-digit 12)
     (arithmetic-shift (string->number (substring digits 0 1)) 8)
     (arithmetic-shift (string->number (substring digits 1 2)) 4)
     (string->number (substring digits 2 3))))

(define (dtc-number->text n)
  (define letter (list-ref +letters+ (arithmetic-shift (bitwise-and n #xC000) -14)))
  (define first-digit (arithmetic-shift (bitwise-and n #x3000) -12))
  (define d2 (bitwise-and (arithmetic-shift n -8) #xF))
  (define d3 (bitwise-and (arithmetic-shift n -4) #xF))
  (define d4 (bitwise-and n #xF))
  (string-append (string letter)
                 (number->string first-digit)
                 (number->string d2)
                 (number->string d3)
                 (number->string d4)))

;; ---------------------------------------------------------------------------
;; Status byte

(struct dtc-status (test-failed
                    test-failed-this-operation-cycle
                    pending
                    confirmed
                    test-not-completed-since-last-clear
                    test-failed-since-last-clear
                    test-not-completed-this-operation-cycle
                    warning-indicator-requested)
  #:transparent)

(define (make-dtc-status
         #:test-failed [test-failed #f]
         #:test-failed-this-operation-cycle [test-failed-this-operation-cycle #f]
         #:pending [pending #f]
         #:confirmed [confirmed #f]
         #:test-not-completed-since-last-clear [test-not-completed-since-last-clear #f]
         #:test-failed-since-last-clear [test-failed-since-last-clear #f]
         #:test-not-completed-this-operation-cycle [test-not-completed-this-operation-cycle #f]
         #:warning-indicator-requested [warning-indicator-requested #f])
  (dtc-status test-failed test-failed-this-operation-cycle pending confirmed
              test-not-completed-since-last-clear test-failed-since-last-clear
              test-not-completed-this-operation-cycle warning-indicator-requested))

(define (dtc-status->byte s)
  (bitwise-ior (if (dtc-status-test-failed s) #x01 0)
               (if (dtc-status-test-failed-this-operation-cycle s) #x02 0)
               (if (dtc-status-pending s) #x04 0)
               (if (dtc-status-confirmed s) #x08 0)
               (if (dtc-status-test-not-completed-since-last-clear s) #x10 0)
               (if (dtc-status-test-failed-since-last-clear s) #x20 0)
               (if (dtc-status-test-not-completed-this-operation-cycle s) #x40 0)
               (if (dtc-status-warning-indicator-requested s) #x80 0)))

(define (byte->dtc-status b)
  (dtc-status (= 1 (bitwise-and b #x01))
              (= 2 (bitwise-and b #x02))
              (= 4 (bitwise-and b #x04))
              (= 8 (bitwise-and b #x08))
              (= #x10 (bitwise-and b #x10))
              (= #x20 (bitwise-and b #x20))
              (= #x40 (bitwise-and b #x40))
              (= #x80 (bitwise-and b #x80))))

;; ---------------------------------------------------------------------------
;; Wire records

;; The 3-byte DTC record: two number bytes, one status byte.
(define (dtc-bytes number status)
  (bytes (bitwise-and (arithmetic-shift number -8) #xFF)
         (bitwise-and number #xFF)
         status))

;; Parses a run of DTC records (ReadDTCInformation reportDTCByStatusMask /
;; reportSupportedDTC payloads); the length must be a multiple of 3.
(define (parse-dtc-records payload)
  (unless (zero? (remainder (bytes-length payload) 3))
    (error 'parse-dtc-records
           "DTC record run must be a multiple of 3 bytes, got ~a" (bytes-length payload)))
  (for/list ([i (in-range 0 (bytes-length payload) 3)])
    (dtc (+ (arithmetic-shift (bytes-ref payload i) 8) (bytes-ref payload (+ i 1)))
         (bytes-ref payload (+ i 2)))))

;; groupOfDTC 0xFFFFFF means "all DTCs" (ClearDiagnosticInformation).
(define +dtc-group-all+ #xFFFFFF)

(define (dtc-group-bytes group)
  (bytes (bitwise-and (arithmetic-shift group -16) #xFF)
         (bitwise-and (arithmetic-shift group -8) #xFF)
         (bitwise-and group #xFF)))
