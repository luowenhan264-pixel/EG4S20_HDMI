# 安路 EG4S20 HDMI 多媒体播放系统 - 全套项目工程与资料总目录

本工程为 **2026年全国大学生嵌入式芯片与系统设计竞赛（安路赛道 选题一）**：**基于安路 EG4S20 的 HDMI 多媒体播放系统** 专用开发根目录。

> **竞赛题目**：选题一：基于安路 EG4S20 的 HDMI 多媒体播放系统  
> **推荐平台**：平台 1 —— **HX4S20C 开发板**  
> **核心芯片**：安路科技 **EG4S20BG256**（19,600 LUT4、19,600 DFF、片内 SiP 合封 64Mbit 32-bit SDRAM、4 PLL）  
> **EDA 工具**：Anlogic TD 6.2.1 / ModelSim SE  
> **核心硬红线**：**100% FPGA 纯硬件逻辑自主编程实现，严禁外挂任何额外处理器（无论辅助控制还是算法预处理）**  

---

## 一、目录结构说明

| 文件夹 | 用途说明 |
| :--- | :--- |
| [**`01_Bitstream_Ready_To_Flash/`**](file:///C:/Users/75941/Desktop/Anlogic_EG4S20_Project/01_Bitstream_Ready_To_Flash) | **【已编译就绪位流】** 存放最终通过物理布局布线生成的 `.bit` 固化位流与上板说明。 |
| [**`02_Anlogic_TD_Project/`**](file:///C:/Users/75941/Desktop/Anlogic_EG4S20_Project/02_Anlogic_TD_Project) | **【安路 TD 主工程】** 包含主工程工程文件（`.al`）、约束文件（`pin.adc`、`timing.sdc`）与综合/实现脚本。 |
| [**`03_RTL_And_ModelSim/`**](file:///C:/Users/75941/Desktop/Anlogic_EG4S20_Project/03_RTL_And_ModelSim) | **【硬件 RTL 源码与仿真】** TF卡FAT32/BMP解析器、SDRAM帧缓存控制器、HDMI音视频打包器、转场特效与音频可视化算法模块及全套测试台。 |
| [**`04_Hardware_Docs_And_Schematics/`**](file:///C:/Users/75941/Desktop/Anlogic_EG4S20_Project/04_Hardware_Docs_And_Schematics) | **【硬件手册与授权】** HX4S20C 原理图、EG4S20 数据手册、板载外设引脚映射表及正版 `Anlogic.lic` 授权。 |
| [**`05_Contest_Guides_And_Reports/`**](file:///C:/Users/75941/Desktop/Anlogic_EG4S20_Project/05_Contest_Guides_And_Reports) | **【赛题指南与报告】** 官方选题指南 PDF、最新 Q&A 答疑纪要、板卡网盘下载链接与开发报告模板。 |

---

## 二、赛题一核心指标与任务拆解

### 1. 基础必做指标
1. **存储介质管理与图像解析**：
   - 纯硬件读取 TF（MicroSD）卡，支持标准 **FAT32** 文件系统解析；
   - 自动扫描并解析 BMP 格式图像的标头与像素阵列（24-bit RGB888）。
2. **片内合封 SDRAM 帧缓存管理**：
   - 驱动 EG4S20 内部 SiP 合封的 32-bit SDRAM（2M×32bits = 64Mbit）；
   - 构建多端口仲裁控制器与双缓冲/乒乓（Ping-Pong）机制，彻底消除画面撕裂。
3. **HDMI 视频高清显示输出**：
   - FPGA 纯逻辑实现 HDMI TX（TMDS 8b/10b 编码与串行差分驱动）；
   - 输出标准 720P / 1080P 稳定视频时序，直驱板载 HDMI 接口。
4. **HDMI 音频输出与音画同步**：
   - 硬件读取音频数据（WAV / PCM），生成 HDMI 音频时钟再生包（ACR）与音频采样包（Audio Sample Packet）；
   - 实现声音与画面的同步联动播放。
5. **多媒体交互控制**：
   - 板载按键控制上一张/下一张切换、自动轮播/暂停播放、音量加减。

### 2. 扩展加分指标（高分夺冠杀手锏）
- [x] **扩展 1：图层叠加与字幕效果**（动态滚动字幕跑马灯、时间戳、半透明 Alpha 遮罩混合）；
- [x] **扩展 2：图片轮播与转场特效**（淡入淡出 Crossfade、百叶窗、水平/垂直滑动转场）；
- [x] **扩展 3：图片自适应缩放适配**（硬件插值算法，不同分辨率 BMP 自动缩放全屏显示）；
- [x] **扩展 4：实时参数调节与 OSD 叠加**（按键调节亮度、对比度，画面实时叠加 OSD 状态进度条）；
- [x] **扩展 5：音频可视化展示**（硬件 64/128 点 FFT 频谱分析或波形生成，在画面底部叠加动态频谱柱状图）。

---

## 三、官方竞赛红线与注意事项（Q&A 划重点）

1. **绝对严禁外挂 CPU / 单片机**：赛题一全流程（含文件检索、图像解析、按键交互、音频处理）**必须在 FPGA 内部纯硬件实现**。
2. **TF 卡规范**：TF 卡必须格式化为 **FAT32** 格式，存放标准 `.bmp` 图片与 `.wav` 音频。
3. **HDMI 驱动规范**：严禁使用外部 HDMI 转接板/驱动板，差分信号由 FPGA 内部硬核/IO 逻辑直驱。
4. **音频输出规范**：显示设备需支持 HDMI 音视频输入或有外接音箱，评测会现场检验音频播放效果。
5. **开发板网盘资料**：
   - 百度网盘：`https://pan.baidu.com/s/1ysv_FmmgZKuM0rBiHfSv8w` 提取码：`M5N1`
   - 板载免驱下载器，Win11 若出现驱动感叹号需关闭内存完整性或签名强制。
