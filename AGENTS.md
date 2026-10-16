# AGENTS.md

ISO 14229（Unified Diagnostic Services）的纯 Racket 实现（MIT，已上架 Racket catalog）。

## 结构

Multi-collection 包：collection 即 `uds/` 子目录，scribblings 声明在 `uds/info.rkt`（collection 级）。

## 常用命令

```bash
raco pkg install --auto --link "$(pwd)"
raco test -p uds
```

## 验证与发版

- CI（`ci.yml`）：即上面两条命令，三平台跑。
- 发版 = tag `v<版本>` + CHANGELOG 同步；catalog 侧为手动提交（pkgd）。
