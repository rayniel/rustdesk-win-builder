# rustdesk-win-builder

在线构建最新版 RustDesk Windows 客户端，并可为自建服务器生成可直接部署的安装包脚本。

## 工作流入口

- GitHub Actions: `.github/workflows/build-rustdesk-win.yml`
- 手动触发参数:
	- `rustdesk_ref`: RustDesk 分支、标签或提交
	- `upload_release`: 是否发布到 GitHub Release
	- `package_selfhost_config`: 如果存在自建服务器配置 secret，则生成自建服务器安装脚本

## 自建服务器配置

推荐方式是直接使用分项 Secret，让工作流自动生成 RustDesk 配置字符串。

推荐配置的 GitHub Secret:

- `RUSTDESK_HOST`: 必填，通常是 hbbs 地址
- `RUSTDESK_KEY`: 必填，服务器公钥
- `RUSTDESK_RELAY`: 可选，通常是 hbbr 地址
- `RUSTDESK_API`: 可选，Pro 场景 API 地址

工作流会优先使用上面这组分项 Secret。只要你设置了其中任意一个分项 Secret，就必须至少同时提供 `RUSTDESK_HOST` 和 `RUSTDESK_KEY`，否则工作流会直接失败，避免产出未绑定服务器的错误包。

兼容方式才是导出整串配置字符串。也就是先在一台 RustDesk 客户端中完成自建服务器网络配置，然后从“设置 -> 网络 -> Export Server Config”导出配置字符串。

将导出的配置字符串保存为仓库或组织 Secret:

- `RUSTDESK_CONFIG`

优先级如下:

1. 如果存在 `RUSTDESK_HOST` 和 `RUSTDESK_KEY`，优先由工作流自动生成配置字符串
2. 否则如果存在 `RUSTDESK_CONFIG`，直接使用它

工作流构建完成后，产物目录 `dist` 会包含:

- RustDesk Windows 安装包 `rustdesk-*-install.exe`
- Flutter 构建输出目录内容
- `install-selfhosted.ps1`
- `install-selfhosted.bat`
- `selfhost-config-source.txt`

同时还会额外生成一个可直接分发的压缩包:

- `rustdesk-windows-<ref>-bundle.zip`

其中安装脚本会:

1. 静默安装构建出的 RustDesk 客户端
2. 调用 `rustdesk.exe --config <config-string>` 导入你的自建服务器配置

## 说明

- 当前方案兼容 RustDesk 开源版常规构建流程，不依赖 Pro 的 custom client generator
- 如果未设置上述任何自建服务器 secret，工作流仍会正常构建客户端，只是不生成自建服务器安装脚本
- Windows runner 上的 NASM 和 vcpkg 不能盲目跟随最新版本；本仓库固定 NASM 2.16.03 和 RustDesk 上游 CI 使用的 vcpkg commit，以避免 `aom:x64-windows-static` 在新工具链上构建失败
