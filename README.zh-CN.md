# uds — ISO 14229 (Unified Diagnostic Services) in pure Racket

[English](README.md) · **中文**

[![CI](https://github.com/turinglambdaai/uds/actions/workflows/ci.yml/badge.svg)](https://github.com/turinglambdaai/uds/actions/workflows/ci.yml) [![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

`uds` 以纯 Racket 实现 **ISO 14229-1** 的消息层——即汽车 ECU 所讲的应用层协议 **UDS**（Unified Diagnostic Services，统一诊断服务）：覆盖全部 27 个服务标识符、否定响应码、诊断故障码（16 位编号及其 P/C/B/U 文本形式、Annex-D 状态字节），以及请求与响应消息的类型化构造器/解析器。

本库与传输层无关且纯净：构造器返回单条 ISO-TP 消息的载荷字节，解析器消费这些字节。可搭配 [`isotp`](https://github.com/turinglambdaai/isotp) 包提供 ISO 15765-2 传输层，也可以跑在 DoIP 或测试替身之上。无 FFI，无系统依赖。

## 安装

```
raco pkg install uds
```

## 用法

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

诊断故障码：

```racket
(dtc-text->number "P0123")                     ; => #x0123
(dtc-number->text #xF456)                      ; => "U3456"
(byte->dtc-status #x2C)                        ; pending + confirmed + ...
(parse-dtc-records #"\1\23\54\221\64\100")     ; => list of dtc
```

## 格式说明

- 肯定响应是请求 SID 置位 bit 6（0x40）后的结果；否定响应为 `7F <echoed SID> <NRC>`。
- 请求子功能字节的 bit 7 是 `suppressPosRspMsgIndicationBit`；`parse-sub-function-byte` 负责把它拆分出来。
- DTC 编号：bit 15–14 为系统字母（P=00、C=01、B=10、U=11），bit 13–12 为第一位数字，其后是三个 BCD 半字节。"P0420" → 0x0420。
- 全部数值常量都与公开的 [python-udsoncan](https://github.com/pylessard/python-udsoncan) 实现（MIT）交叉核对过；测试套件把这些值固化为 golden 向量。

## 局限

- 安全算法（seed/key）因 ECU 而异，留待调用方处理。
- 不做会话/时序管理；本库只是一个消息编解码器。

## 许可证

[MIT](LICENSE)
