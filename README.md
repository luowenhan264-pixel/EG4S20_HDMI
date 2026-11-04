# 基于 FPGA 的声音科普交互展示系统

最新资料同步日期：2026-11-04。平台：HX4S20 / EG4S20BG256；视频输出：640×480 HDMI。

系统通过声音与波形、音高与频率、音量与振幅、音乐与混音四页实验，结合 TF 图片、实时 PCM 波形、中文字幕和按键菜单开展科普展示。图片由 TF 卡读取并最近邻缩放，声音由 FPGA 合成。

## 最新工程与提交材料

| 内容 | 入口 |
| --- | --- |
| 最新声音科普工程 | [topic1_hdmi__player](topic1_hdmi__player/) |
| TD 工程 | [topic1_hdmi_player.al](topic1_hdmi__player/src/td_project/topic1_hdmi_player.al) |
| 操作与实现说明 | [声音科普交互展示说明](topic1_hdmi__player/声音科普交互展示说明.md) |
| 修订技术文档 Word | [下载 Word](output/document_revision_20261104/基于FPGA的声音科普交互展示系统技术文档_修订版.docx) |
| 修订技术文档 PDF | [查看 PDF](output/document_revision_20261104/基于FPGA的声音科普交互展示系统技术文档.pdf) |
| 不署名 A3 作品海报 | [查看海报](output/pdf/作品提交材料_20261104/基于FPGA的声音科普交互展示系统_作品海报_A3.pdf) |
| 文档指定构建位流 | [171402_416 位流](topic1_hdmi__player/build/run_20261103_171402_416/phy/topic1_hdmi_player.bit) |
| 同日另一构建位流 | [233855_984 位流](topic1_hdmi__player/build/run_20261103_233855_984/phy/topic1_hdmi_player.bit) |
| 声音科普 TF 镜像（无损压缩） | [sound_science_card.img.gz](topic1_hdmi__player/build/sound_science_card.img.gz) |
| 同步文件与哈希 | [SYNC_MANIFEST_20261104.json](SYNC_MANIFEST_20261104.json) |

两份位流为不同构建产物。技术文档的离线验证数据对应 run_20261103_171402_416，请记录实际下载文件，不混用不同版本的测试结论。

TF 镜像以 gzip 无损压缩形式发布。在最新工程目录运行 `python tools/unpack_card_image.py`，恢复 `build/sound_science_card.img`，脚本会校验原镜像 SHA-256。解压后再按技术文档写卡。

## 操作

- KEY1：复位。
- KEY2 / KEY3：下一页 / 上一页。
- KEY4 短按：切换本页实验；长按约 0.8 秒：打开或关闭菜单。
- 菜单：音量、亮度、对比度、字幕、自动轮播、驻留时间。

## 已有验证记录与范围

- [现有回归日志](topic1_hdmi__player/sim/results/run_20261103_171352_247/)中 26 项测试均记录通过，其中声音科普专项 5 项。
- [指定构建的最终时序报告](topic1_hdmi__player/build/run_20261103_171402_416/phy/final_timing.rpt)：setup WNS +0.955 ns，hold WNS +0.003 ns，STA 覆盖率 99.82%。结论限于所用约束及分析覆盖范围。
- tb_science_display 验证音频生成、波形和 OSD 像素流水线；TF、缩放、缓存等由其他测试分别覆盖，不能称为单一 TF→SDRAM→HDMI 端到端整机仿真。
- 与原构建清单对照，94 个文件中 93 个匹配，.al 工程文件不匹配。原清单及原验证记录保留，本次同步清单单独记录当前交付文件。
- 项目照片为实拍，但照片与具体位流的对应关系及完整上板验收记录尚未提供。此次同步未重新编译、运行仿真或进行板级测量。

运行时未实现通用 FAT32 目录/簇链解析，应使用配套连续存储 BMP 镜像。声音由 FPGA 内部合成，波形显示不等同于 FFT 或外部声压测量。

## 构建

在最新工程目录执行 ./build.ps1 -TdHome <本机TD安装目录>。回归入口为 ./sim/run.ps1，具体工具配置见脚本。构建输出按时间戳分目录；仓库保留指定发布产物与证据，过滤编译数据库及缓存。

## 历史工程与资料

- 早期播放器已移至 [Git 历史版本](https://github.com/luowenhan264-pixel/EG4S20_HDMI/tree/d31522120b8c4f083650ba5ac09de3e89fdaa1b1/02_Anlogic_TD_Project/topic1_hdmi_player)，当前入口统一使用 topic1_hdmi__player/。
- 02_Anlogic_TD_Project/official_baseline_HX4S20C/：官方参考例程。
- 旧播放器位流可从 [历史目录](https://github.com/luowenhan264-pixel/EG4S20_HDMI/tree/d31522120b8c4f083650ba5ac09de3e89fdaa1b1/01_Bitstream_Ready_To_Flash) 恢复；当前声音科普版使用上表指定产物。
- [旧版仓库说明](05_Contest_Guides_And_Reports/history/README_20261018.md)中的功能勾选和路径属于历史记录，不作为当前实现或验收证明。

签名授权书按所有者要求仅保留本地，不提交到仓库。

清理范围及保留策略见 [CLEANUP_20261104.md](CLEANUP_20261104.md)。

