# 更新日志

本项目的重要变更都会记录在这里。版本格式遵循[语义化版本](https://semver.org/lang/zh-CN/)。

## [8.15.8] - 2026-08-15

### 改进

- 简化 README，让普通用户和开发者都能快速找到需要的步骤。
- 完善通用 App 的 Developer ID 签名、打包与发布验证流程。
- 发布包通过 Apple 公证，并内置可由 Gatekeeper 验证的公证票据。

## [1.0.0] - 2026-08-15

### 新增

- 原生 macOS 图形界面，可选择视频和单独的封面照片。
- 可从视频时间轴选取封面帧，并按源视频帧率精细调整。
- 支持常见图片格式，必要时自动转换为 JPEG。
- 生成 Apple“照片”App 可导入的 `.pvt` 实况照片包。
- 自动生成不冲突的输出名称，并支持从 App 直接导入“照片”。
- 提供 Intel 与 Apple 芯片通用的 macOS App 发布包。

[8.15.8]: https://github.com/JackAIStudio/GenLivePhoto/releases/tag/v8.15.8
[1.0.0]: https://github.com/JackAIStudio/GenLivePhoto/releases/tag/v1.0.0
