# 参与贡献

感谢你愿意改进 GenLivePhoto。提交改动前，请先确认相关 Issue 是否已经存在；较大的功能建议先创建 Issue 说明使用场景和方案。

## 开发环境

- macOS 13 或更高版本
- Swift 6.2 或更高版本
- Xcode Command Line Tools
- 运行集成测试时需要安装 [MakeLive](https://github.com/RhetTbull/makelive)

```bash
git clone https://github.com/JackAIStudio/GenLivePhoto.git
cd GenLivePhoto
swift test
./scripts/run-app.sh
```

## 提交要求

1. 每个提交只处理一个明确问题。
2. 新功能或缺陷修复应尽量补充测试。
3. 提交前运行 `swift test`，并确认 `scripts/*.sh` 能通过 `bash -n` 检查。
4. 不要提交个人媒体、凭据、`.env` 文件、构建目录或生成的 `.pvt` 文件。
5. Pull Request 中说明改动目的、用户影响和验证方式；涉及界面时请附截图。

可选的真实媒体测试通过环境变量启用：

```bash
GENLIVEPHOTO_FRAME_VIDEO=/path/to/video.mov swift test
GENLIVEPHOTO_INTEGRATION_IMAGE=/path/to/cover.jpg \
GENLIVEPHOTO_INTEGRATION_VIDEO=/path/to/video.mov \
swift test
```

参与本项目即表示你同意将贡献内容按项目的 [MIT License](LICENSE) 发布。
