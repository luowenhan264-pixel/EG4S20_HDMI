# FPGA 声音科普交互展示系统

2026-11-03 当前版本：HX4S20 / EG4S20BG256，640×480 HDMI 画面与音频。

四页分别展示声音波形、频率与音高、振幅与音量、音乐与提示音混合。已接入四幅标注原始分辨率的图片、中文滚动说明、576×64 实时波形及亮度/对比度菜单。

## 打开和使用

- TD 工程：`src/td_project/topic1_hdmi_player.al`。
- 全部原始代码：`src/user_source/hdl_source`；顶层 `top_tf_hdmi_audio.v`。
- 当前下载文件：`build/run_20261103_171402_416/phy/topic1_hdmi_player.bit`。
- 配套 TF 镜像：`build/sound_science_card.img`，需要替换旧消防镜像。
- KEY1 复位；KEY2 下一页；KEY3 上一页；KEY4 短按实验切换，长按菜单。
- 菜单中 KEY2/KEY3 下/上一项，KEY4 修改。VOL/BRI/CON/SUB/AUTO/TIME，默认手动展示。

详细操作、各页实验、源码结构、技术限制及上板检查见 [声音科普交互展示说明.md](声音科普交互展示说明.md)。

## 构建和验证

在项目根目录运行 PowerShell `./build.ps1`，生成独立时间戳 build/run_* 目录；运行 `./sim/run.ps1` 执行完整 ModelSim 回归。完整显示链仿真会自动用 Python 标准库将四张 BMP 转成测试输入，不依赖 Pillow；重生成中文字模才需要 Pillow 和 Windows 宋体。

最终 TD 时序通过：setup +0.955 ns、hold +0.003 ns，约束错误 0。具体回归及哈希见当前构建目录 `science_review.json`。新版本尚待开发板、显示器和耳机实测；仿真通过不等同于上板验收。

旧消防/背景音乐版本和历史 build 均保留，旧 README 在 `doc/history/README_before_sound_science_20261103.md`。
