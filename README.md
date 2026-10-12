# uds — ISO 14229 (Unified Diagnostic Services) in pure Racket

[![CI](https://github.com/turinglambdaai/uds/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/uds/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`uds` implements the message layer of **ISO 14229-1** — **UDS**
(Unified Diagnostic Services), the application protocol spoken by automotive
ECUs — in pure Racket: all 27 service identifiers, the negative response
codes, diagnostic trouble codes (16-bit numbers with P/C/B/U text form, the
Annex-D status byte), and typed builders/parsers for the request and
response messages.

The library is transport-agnostic and pure: builders return the payload
bytes of one ISO-TP message and parsers consume them. Pair it with the
[`isotp`](https://github.com/turinglambdaai/isotp) package for the ISO
15765-2 transport layer, or drive it over DoIP or a test double. There is no
FFI and no system dependency.

## Installation

```
raco pkg install uds
```

## Usage

```racket
(require uds)

;; Ask for the extended diagnostic session
(diagnostic-session-control 'extended)          ; => #"\20\3"

;; Read the VIN (DID 0xF190)
(read-data-by-identifier '(#xF190))             ; => #"\42\361\220"

;; Start a routine
(routine-control 'start #x0203)                 ; => #"\61\1\2\3"

;; Parse whatever comes back
(define r (response-parse #"\120\3\000\062\000\310"))
;; => positive response of DiagnosticSessionControl, sub 3
(session-control-response (positive-response-data r))  ; => 3, 50, 2000

;; Negative responses
(response-parse #"\177\42\61")  ; => (negative-response #x22 #x31)
;; service 0x22 rejected with requestOutOfRange
```

Diagnostic trouble codes:

```racket
(dtc-text->number "P0123")                     ; => #x0123
(dtc-number->text #xF456)                      ; => "U3456"
(byte->dtc-status #x2C)                        ; pending + confirmed + ...
(parse-dtc-records #"\1\23\54\221\64\100")     ; => list of dtc
```

## Format notes

- Positive responses are the request SID with bit 6 set (0x40); negative
  responses are `7F <echoed SID> <NRC>`.
- The request sub-function byte's bit 7 is
  `suppressPosRspMsgIndicationBit`; `parse-sub-function-byte` splits it.
- DTC numbers: bits 15–14 system letter (P=00, C=01, B=10, U=11), bits
  13–12 first digit, then three BCD nibbles. "P0420" → 0x0420.
- Every numeric constant was cross-checked against the public
  [python-udsoncan](https://github.com/pylessard/python-udsoncan)
  implementation (MIT); the test suite pins those values as golden vectors.

## Limitations

- Security algorithms (seed/key) are ECU-specific and stay with the caller.
- No session/timing management; the library is a message codec.

## License

[MIT](LICENSE)
