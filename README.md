# GenLivePhoto

一个独立的 macOS 实况照片生成工具。选择一张照片，或直接从视频中选取某个画面作为封面，即可生成可导入 Apple“照片”App 的 `.pvt` 实况照片包。

本项目与 JackAICut 无关，不依赖 JackAICut 的源码或运行环境。

[下载最新版本](https://github.com/JackAIStudio/GenLivePhoto/releases/latest) · [查看更新日志](CHANGELOG.md) · [参与贡献](CONTRIBUTING.md)

## 下载与安装

不需要编译源码：

1. 在 [Releases](https://github.com/JackAIStudio/GenLivePhoto/releases/latest) 下载 `GenLivePhoto-*-macos-universal.zip`。
2. 解压后，将 `GenLivePhoto.app` 拖入“应用程序”文件夹。
3. 按下方说明安装 MakeLive，然后打开 App。

发布包同时支持 Intel 和 Apple 芯片，最低需要 macOS 13。

如果 macOS 首次打开时提示无法验证开发者，请在访达中按住 Control 点击 App，选择“打开”；也可以前往“系统设置 → 隐私与安全性”确认打开。发布包的签名与公证状态会在对应 Release 说明中标注。

## 功能

- 支持 PNG、JPG、JPEG、HEIC、HEIF、TIFF、BMP、GIF、WebP 等常见封面图片
- 非 JPEG/HEIC 图片会在生成时自动转换，PNG 透明区域使用白色背景
- 支持 MOV、MP4、M4V 视频
- 视频和封面照片可以按任意顺序选择
- 选择视频后自动显示封面预览和胶片时间轴
- 可拖动封面选择条，并用“早一点 / 晚一点”做精细调整
- 拖放或文件选择
- 默认使用视频文件名作为实况照片名称，也可随时修改
- 一键生成 `.pvt`
- 默认保存到 `~/Downloads/GenLivePhoto`
- 不修改源文件
- 同名结果自动追加序号，不覆盖已有文件
- 生成后可在访达中显示，或直接导入“照片”App

## 依赖

- macOS 13 或更高版本
- [MakeLive](https://github.com/RhetTbull/makelive)
- `makelive` 命令，或能够运行 `uvx makelive` 的 `uvx`

当前应用会依次查找：

1. `~/.local/bin/makelive`
2. Homebrew 常见路径下的 `makelive`
3. `~/.local/bin/uvx`
4. Homebrew 常见路径下的 `uvx`

可选的一次性安装：

```bash
./scripts/setup-makelive.sh
```

只下载 App、不下载源码的用户，可以先按 [uv 官方说明](https://docs.astral.sh/uv/getting-started/installation/)安装 `uv`，再执行：

```bash
uv tool install makelive
```

## 开发运行

一键编译最新代码并启动 macOS App（推荐）：

```bash
./scripts/run-app.sh
```

该命令的行为类似 Xcode 的 Run：结束上一次启动的 App，构建最新代码，签名并打开 `dist/GenLivePhoto.app`。

也可以直接以 Swift Package 可执行程序的形式运行：

```bash
swift run
```

## 测试

```bash
swift test
```

## 构建 macOS App

```bash
./scripts/build-app.sh
```

构建结果位于：

```text
dist/GenLivePhoto.app
```

默认会构建同时支持 Intel 与 Apple 芯片的通用 App。只构建单一架构时可使用：

```bash
GENLIVEPHOTO_ARCHS="arm64" ./scripts/build-app.sh
```

生成可用于 GitHub Release 的压缩包和 SHA-256 校验文件：

```bash
./scripts/package-release.sh 1.0.0
```

## 使用

1. 选择动态视频和封面照片；两者可以按任意顺序选择，也可以直接拖入窗口。
2. 如果不使用单独的照片，可从视频时间轴选取一帧，并用“早一点 / 晚一点”精细调整。
3. 应用会使用视频文件名作为实况照片名称；如有需要，可修改名称或默认输出文件夹。
4. 点击“创建实况照片”。
5. 点击“导入照片”，或将生成的 `.pvt` 隔空投送到 iPhone。

为了减少封面切换到动态画面时的跳变，建议封面与视频使用相同的尺寸、比例和方向。

## 隐私

视频和照片都在本机处理，GenLivePhoto 不会上传媒体文件，也不包含分析或追踪服务。安装或首次运行外部依赖时，`uv`/`uvx` 可能访问网络下载 MakeLive。

## 安全与贡献

- 发现安全问题请阅读[安全政策](SECURITY.md)，不要在公开 Issue 中披露漏洞细节。
- Bug、功能建议和代码贡献请参考[参与贡献](CONTRIBUTING.md)。

## 许可证

GenLivePhoto 使用 [MIT License](LICENSE) 开源。MakeLive 是独立安装的第三方工具，使用其自己的 MIT License。
