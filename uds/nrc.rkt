#lang racket/base

;; Negative response codes (NRC) of ISO 14229-1, and the negative response
;; framing (7F <echoed SID> <NRC>).
;;
;; Values cross-checked against python-udsoncan (MIT, ResponseCode.py);
;; 0x23 is reserved in ISO 14229-1 and deliberately absent.

(require racket/contract
         "sid.rkt")

(provide (contract-out
          (nrc:general-reject                        (integer-in 0 255))
          (nrc:service-not-supported                 (integer-in 0 255))
          (nrc:sub-function-not-supported            (integer-in 0 255))
          (nrc:incorrect-message-length-or-invalid-format (integer-in 0 255))
          (nrc:response-too-long                     (integer-in 0 255))
          (nrc:busy-repeat-request                   (integer-in 0 255))
          (nrc:conditions-not-correct                (integer-in 0 255))
          (nrc:request-sequence-error                (integer-in 0 255))
          (nrc:no-response-from-subnet-component     (integer-in 0 255))
          (nrc:failure-prevents-execution-of-requested-action (integer-in 0 255))
          (nrc:request-out-of-range                  (integer-in 0 255))
          (nrc:security-access-denied                (integer-in 0 255))
          (nrc:authentication-required               (integer-in 0 255))
          (nrc:invalid-key                           (integer-in 0 255))
          (nrc:exceed-number-of-attempts             (integer-in 0 255))
          (nrc:required-time-delay-not-expired       (integer-in 0 255))
          (nrc:secure-data-transmission-required     (integer-in 0 255))
          (nrc:secure-data-transmission-not-allowed  (integer-in 0 255))
          (nrc:secure-data-verification-failed       (integer-in 0 255))
          (nrc:ownership-verification-failed         (integer-in 0 255))
          (nrc:challenge-calculation-failed          (integer-in 0 255))
          (nrc:setting-access-rights-failed          (integer-in 0 255))
          (nrc:session-key-creation-derivation-failed (integer-in 0 255))
          (nrc:configuration-data-usage-failed       (integer-in 0 255))
          (nrc:de-authentication-failed              (integer-in 0 255))
          (nrc:upload-download-not-accepted          (integer-in 0 255))
          (nrc:transfer-data-suspended               (integer-in 0 255))
          (nrc:general-programming-failure           (integer-in 0 255))
          (nrc:wrong-block-sequence-counter          (integer-in 0 255))
          (nrc:request-correctly-received-response-pending (integer-in 0 255))
          (nrc:sub-function-not-supported-in-active-session (integer-in 0 255))
          (nrc:service-not-supported-in-active-session (integer-in 0 255))
          (nrc:rpm-too-high                          (integer-in 0 255))
          (nrc:rpm-too-low                           (integer-in 0 255))
          (nrc:engine-is-running                     (integer-in 0 255))
          (nrc:engine-is-not-running                 (integer-in 0 255))
          (nrc:engine-run-time-too-low               (integer-in 0 255))
          (nrc:temperature-too-high                  (integer-in 0 255))
          (nrc:temperature-too-low                   (integer-in 0 255))
          (nrc:vehicle-speed-too-high                (integer-in 0 255))
          (nrc:vehicle-speed-too-low                 (integer-in 0 255))
          (nrc:throttle-pedal-too-high               (integer-in 0 255))
          (nrc:throttle-pedal-too-low                (integer-in 0 255))
          (nrc:transmission-range-not-in-neutral     (integer-in 0 255))
          (nrc:transmission-range-not-in-gear        (integer-in 0 255))
          (nrc:brake-switch-not-closed               (integer-in 0 255))
          (nrc:shifter-lever-not-in-park             (integer-in 0 255))
          (nrc:torque-converter-clutch-locked        (integer-in 0 255))
          (nrc:voltage-too-high                      (integer-in 0 255))
          (nrc:voltage-too-low                       (integer-in 0 255))
          (nrc:resource-temporarily-not-available    (integer-in 0 255))
          (struct negative-response ((sid (integer-in 0 255))
                                     (nrc (integer-in 0 255))))
          [negative-response-parse (-> bytes? negative-response?)]
          [negative-response-bytes (-> (integer-in 0 255) (integer-in 0 255) bytes?)]
          [nrc-name (-> (integer-in 0 255) (or/c symbol? #f))]
          [nrc-supported? (-> (integer-in 0 255) boolean?)]
          [response-pending? (-> bytes? boolean?)]))

(define nrc:general-reject                                 #x10)
(define nrc:service-not-supported                          #x11)
(define nrc:sub-function-not-supported                     #x12)
(define nrc:incorrect-message-length-or-invalid-format     #x13)
(define nrc:response-too-long                              #x14)
(define nrc:busy-repeat-request                            #x21)
(define nrc:conditions-not-correct                         #x22)
(define nrc:request-sequence-error                         #x24)
(define nrc:no-response-from-subnet-component              #x25)
(define nrc:failure-prevents-execution-of-requested-action #x26)
(define nrc:request-out-of-range                           #x31)
(define nrc:security-access-denied                         #x33)
(define nrc:authentication-required                        #x34)
(define nrc:invalid-key                                    #x35)
(define nrc:exceed-number-of-attempts                      #x36)
(define nrc:required-time-delay-not-expired                #x37)
(define nrc:secure-data-transmission-required              #x38)
(define nrc:secure-data-transmission-not-allowed           #x39)
(define nrc:secure-data-verification-failed                #x3A)
(define nrc:ownership-verification-failed                  #x58)
(define nrc:challenge-calculation-failed                   #x59)
(define nrc:setting-access-rights-failed                   #x5A)
(define nrc:session-key-creation-derivation-failed         #x5B)
(define nrc:configuration-data-usage-failed                #x5C)
(define nrc:de-authentication-failed                       #x5D)
(define nrc:upload-download-not-accepted                   #x70)
(define nrc:transfer-data-suspended                        #x71)
(define nrc:general-programming-failure                    #x72)
(define nrc:wrong-block-sequence-counter                   #x73)
(define nrc:request-correctly-received-response-pending    #x78)
(define nrc:sub-function-not-supported-in-active-session   #x7E)
(define nrc:service-not-supported-in-active-session        #x7F)
(define nrc:rpm-too-high                                   #x81)
(define nrc:rpm-too-low                                    #x82)
(define nrc:engine-is-running                              #x83)
(define nrc:engine-is-not-running                          #x84)
(define nrc:engine-run-time-too-low                        #x85)
(define nrc:temperature-too-high                           #x86)
(define nrc:temperature-too-low                            #x87)
(define nrc:vehicle-speed-too-high                         #x88)
(define nrc:vehicle-speed-too-low                          #x89)
(define nrc:throttle-pedal-too-high                        #x8A)
(define nrc:throttle-pedal-too-low                         #x8B)
(define nrc:transmission-range-not-in-neutral              #x8C)
(define nrc:transmission-range-not-in-gear                 #x8D)
(define nrc:brake-switch-not-closed                        #x8F)
(define nrc:shifter-lever-not-in-park                      #x90)
(define nrc:torque-converter-clutch-locked                 #x91)
(define nrc:voltage-too-high                               #x92)
(define nrc:voltage-too-low                                #x93)
(define nrc:resource-temporarily-not-available             #x94)

(define +nrc-names+
  (hasheq nrc:general-reject 'general-reject
          nrc:service-not-supported 'service-not-supported
          nrc:sub-function-not-supported 'sub-function-not-supported
          nrc:incorrect-message-length-or-invalid-format 'incorrect-message-length-or-invalid-format
          nrc:response-too-long 'response-too-long
          nrc:busy-repeat-request 'busy-repeat-request
          nrc:conditions-not-correct 'conditions-not-correct
          nrc:request-sequence-error 'request-sequence-error
          nrc:no-response-from-subnet-component 'no-response-from-subnet-component
          nrc:failure-prevents-execution-of-requested-action 'failure-prevents-execution-of-requested-action
          nrc:request-out-of-range 'request-out-of-range
          nrc:security-access-denied 'security-access-denied
          nrc:authentication-required 'authentication-required
          nrc:invalid-key 'invalid-key
          nrc:exceed-number-of-attempts 'exceed-number-of-attempts
          nrc:required-time-delay-not-expired 'required-time-delay-not-expired
          nrc:secure-data-transmission-required 'secure-data-transmission-required
          nrc:secure-data-transmission-not-allowed 'secure-data-transmission-not-allowed
          nrc:secure-data-verification-failed 'secure-data-verification-failed
          nrc:ownership-verification-failed 'ownership-verification-failed
          nrc:challenge-calculation-failed 'challenge-calculation-failed
          nrc:setting-access-rights-failed 'setting-access-rights-failed
          nrc:session-key-creation-derivation-failed 'session-key-creation-derivation-failed
          nrc:configuration-data-usage-failed 'configuration-data-usage-failed
          nrc:de-authentication-failed 'de-authentication-failed
          nrc:upload-download-not-accepted 'upload-download-not-accepted
          nrc:transfer-data-suspended 'transfer-data-suspended
          nrc:general-programming-failure 'general-programming-failure
          nrc:wrong-block-sequence-counter 'wrong-block-sequence-counter
          nrc:request-correctly-received-response-pending 'request-correctly-received-response-pending
          nrc:sub-function-not-supported-in-active-session 'sub-function-not-supported-in-active-session
          nrc:service-not-supported-in-active-session 'service-not-supported-in-active-session
          nrc:rpm-too-high 'rpm-too-high
          nrc:rpm-too-low 'rpm-too-low
          nrc:engine-is-running 'engine-is-running
          nrc:engine-is-not-running 'engine-is-not-running
          nrc:engine-run-time-too-low 'engine-run-time-too-low
          nrc:temperature-too-high 'temperature-too-high
          nrc:temperature-too-low 'temperature-too-low
          nrc:vehicle-speed-too-high 'vehicle-speed-too-high
          nrc:vehicle-speed-too-low 'vehicle-speed-too-low
          nrc:throttle-pedal-too-high 'throttle-pedal-too-high
          nrc:throttle-pedal-too-low 'throttle-pedal-too-low
          nrc:transmission-range-not-in-neutral 'transmission-range-not-in-neutral
          nrc:transmission-range-not-in-gear 'transmission-range-not-in-gear
          nrc:brake-switch-not-closed 'brake-switch-not-closed
          nrc:shifter-lever-not-in-park 'shifter-lever-not-in-park
          nrc:torque-converter-clutch-locked 'torque-converter-clutch-locked
          nrc:voltage-too-high 'voltage-too-high
          nrc:voltage-too-low 'voltage-too-low
          nrc:resource-temporarily-not-available 'resource-temporarily-not-available))

(define (nrc-name nrc) (hash-ref +nrc-names+ nrc #f))
(define (nrc-supported? nrc) (hash-has-key? +nrc-names+ nrc))

(struct negative-response (sid nrc) #:transparent)

(define (negative-response-parse payload)
  (unless (and (>= (bytes-length payload) 3)
               (= (bytes-ref payload 0) #x7F))
    (error 'negative-response-parse "not a negative response: ~a" payload))
  (negative-response (bytes-ref payload 1) (bytes-ref payload 2)))

(define (negative-response-bytes sid nrc)
  (bytes #x7F sid nrc))

;; True when `payload` is a negative response carrying the
;; requestCorrectlyReceived-ResponsePending NRC (the tester must restart its
;; P2*/response timer and keep waiting).
(define (response-pending? payload)
  (and (>= (bytes-length payload) 3)
       (= (bytes-ref payload 0) #x7F)
       (= (bytes-ref payload 2) nrc:request-correctly-received-response-pending)))
