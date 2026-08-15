# GenLivePhoto

在 Mac 上，把一张照片和一段视频做成 iPhone 实况照片。

素材只在你的电脑上处理，不会上传，也不会修改原文件。

**[下载最新版 App](https://github.com/JackAIStudio/GenLivePhoto/releases/latest)**

支持 macOS 13 及以上版本，同时支持 Intel 和 Apple 芯片。

## 直接使用 App

不需要 Xcode，也不需要自己编译。

### 1. 安装一次生成工具

GenLivePhoto 需要 MakeLive 来生成实况照片。它只需要安装一次。

打开 Mac 的“终端”App，依次粘贴下面两行命令：

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
~/.local/bin/uv tool install makelive
```

### 2. 下载 App

1. 打开[最新版下载页面](https://github.com/JackAIStudio/GenLivePhoto/releases/latest)。
2. 下载名字中带有 `macos-universal.zip` 的文件。
3. 解压后，把 `GenLivePhoto.app` 拖进“应用程序”文件夹。

第一次打开时，如果 macOS 弹出安全提示：

1. 在访达中找到 `GenLivePhoto.app`。
2. 按住 Control 点击它，选择“打开”。
3. 再确认一次“打开”。

### 3. 制作实况照片

1. 选择一段视频。
2. 选择一张封面照片，或者直接从视频里挑一帧。
3. 点击“创建实况照片”。
4. 完成后点击“导入照片”。

默认结果保存在“下载/GenLivePhoto”文件夹。遇到同名文件时会自动换一个名字，不会覆盖旧文件。

## 支持的文件

- 视频：MOV、MP4、M4V
- 图片：JPG、PNG、HEIC、WebP、GIF、TIFF、BMP 等常见格式

为了让封面切换到视频时更自然，建议照片和视频使用相同的尺寸和方向。

## 给开发者

这是一个使用 Swift 和 SwiftUI 编写的 macOS 项目。

```bash
git clone https://github.com/JackAIStudio/GenLivePhoto.git
cd GenLivePhoto
./scripts/setup-makelive.sh
./scripts/run-app.sh
```

运行测试：

```bash
swift test
```

生成 GitHub Release 安装包：

```bash
./scripts/package-release.sh 1.0.0
```

更多内容：

- [更新日志](CHANGELOG.md)
- [参与贡献](CONTRIBUTING.md)
- [安全问题报告](SECURITY.md)

## 开源许可

[MIT License](LICENSE)
