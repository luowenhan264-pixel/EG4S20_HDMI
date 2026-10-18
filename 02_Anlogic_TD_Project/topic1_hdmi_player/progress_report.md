# topic1_hdmi_player 进度说明

> 工作区：`C:\Users\AUSU\Desktop\FPGA\work\topic1_hdmi_player`  
> 基于 `lab_ex5_i2s` 复制后改造；**未修改** `lab_ex4_tf` / `lab_ex5_i2s` 原目录。

## 1. 相对 lab_ex4 / lab_ex5 的差异点

| 项目 | lab_ex4_tf | lab_ex5_i2s | 本终稿 topic1 |
|------|------------|-------------|---------------|
| HDMI 音频 | 硬连 0 | PLL + I2S tone + ACR | **保留 ex5 全音频通路** |
| POR / 复位 | sys+video lock + 20 ms | 仅 `audio_pll_lock` | **ex4 POR + 仍要求 audio PLL lock** |
| 找图方式 | SCAN_START~MAX 全盘盲扫 BM | 同左 | **固定扇区 playlist**（上电按表加载） |
| 读图超时 | ~1 s `load_abort` | 无 | **合并 ex4 timeout/abort** |
| 写完成闩锁 | `write_done_seen` | 仅瞬时 pulse | **合并 `write_done_seen`** |
| 轮播周期 | 绑 `CLK_FREQ_HZ-1`（约 1 s） | 同左 | **`AUTO_PERIOD_MS` 独立参数**（默认 2000 ms） |
| 屏幕扩展 | 无数码管外的 OSD | 同左 | **左上角 OSD 色块**（图序号 / AUTO / 状态码） |

### playlist 默认扇区表（需与烧卡布局一致）

在 `top_tf_hdmi_audio.v` / `sd_card_bmp` 参数：

- `IMG_COUNT = 4`
- `IMG_SECTOR0 = 0`
- `IMG_SECTOR1 = 2048`
- `IMG_SECTOR2 = 4096`
- `IMG_SECTOR3 = 6144`

每张图约占 1800 扇区（640×480×24 BMP ≈ 921654 字节 ≈ 1801 扇区），2048 扇区间距为等间距占位。  
加载时仍按 `load_sector` 读扇区并校验 `BM` 头 + 分辨率/色深，但**不再**做 `SCAN_START~SCAN_MAX` 全盘扫描。

### OSD 含义（左上角）

1. 四个灰/黄方块：当前图序号 0~3（高亮黄）
2. 绿色块 = 自动轮播 ON；红色块 = OFF
3. 四个蓝/暗小块：`state_code[3:0]` 位指示

### 按键

- `key1`：下一张
- `key2`：自动轮播开/停（需 ≥2 张）

---

## 2. 安路 TD 6.2.1 打开 / 综合 / 生成 bit / 下载

### GUI 步骤（推荐）

1. 启动 `D:\TD_6.2.1\bin\td.exe`
2. **Project → Open Project**，选择：  
   `C:\Users\AUSU\Desktop\FPGA\work\topic1_hdmi_player\src\td_project\topic1_hdmi_player.al`
3. 确认：
   - Device：`EG4S20BG256`
   - Top Module：`top`
   - 源文件列表含 `osd_overlay_640x480.v`、`top_tf_hdmi_audio.v`、`SD/sd_card_bmp.v` 等
4. 执行全流程：**Process → Run**（或工具栏 Run，跑到 Bitgen）
5. 成功后 bit 一般在：  
   `src\td_project\topic1_hdmi_player_Runs\phy_1\`（或同级 `*.bit`）
6. 复制到目标路径：  
   `C:\Users\AUSU\Desktop\FPGA\work\output_bit\topic1_hdmi_player.bit`
7. 下载：TD 下载器，或命令行参考：  
   `output_bit\download.tcl` 形式：  
   `download -bit {C:/Users/AUSU/Desktop/FPGA/work/output_bit/topic1_hdmi_player.bit} -cable 0`

### CLI 尝试

工程根目录提供 `build_topic1.tcl`。在 TD 命令提示符中：

```text
cd C:/Users/AUSU/Desktop/FPGA/work/topic1_hdmi_player
source build_topic1.tcl
```

或：

```text
D:\TD_6.2.1\bin\td_commands_prompt.exe C:/Users/AUSU/Desktop/FPGA/work/topic1_hdmi_player/build_topic1.tcl
```

若 CLI 因工程 Runs 路径/许可失败，请改用上述 GUI 步骤；源码按可综合方式编写。

---

## 3. 硬件连接与烧卡对齐

- **HDMI**：接开发板 **HDMI_B**（`pin.adc` 中 C3/G5/F1/E1 + DDC P2/R2），勿改引脚
- **TF 卡**：SPI 引脚同例程（A12/A13/A14/B14）
- **扇区对齐建议**：
  1. 使用 `doc/convert/sync_to_sd.py` 清空卡并顺序写入 ≥4 张 640×480×24 非压缩 BMP（脚本会破坏旧 BM 头，避免残留误识别——本终稿虽不盲扫，烧卡清洁仍建议做）
  2. 用十六进制工具或读卡器确认各 BMP 文件起始 LBA/扇区；将实测值填入 `IMG_SECTOR0..3`
  3. 若无法测扇区：在空卡上按固定顺序连续写入 4 张图后，用工具查看簇/扇区起始，或按 FAT 数据区布局推算后改参数重编
  4. 默认 `0/2048/4096/6144` 仅为占位，**必须与实际卡布局一致**，否则首图 BM 校验失败、黑屏或超时 abort

---

## 4. 已知缺口 / 未上板验证项

- [x] CLI 已跑通 syn → phy → bitgen（`build_topic1.tcl` / `build_phy_only.tcl`）
- [ ] **上板未验证**：HDMI_B 出图 + 扬声器测试音
- [ ] **上板未验证**：key1/key2、OSD 色块、2 s 自动轮播
- [ ] 实测 TF 扇区表与默认 `IMG_SECTOR*` 是否一致；不一致需改参重编
- [ ] `pin.adc` 中 key/rst 仍为 `PULLTYPE=NONE`（ex5 原样）；若板级无外部上拉可能抖键，可按需改为 PULLUP
- [ ] 音频仍为内部音阶测试音，非 BMP/文件内容音频
- [ ] 时序报告存在 Setup WNS 负值（与例程量级类似，需上板确认稳定性）

---

## 5. bit 输出目标

已生成：`C:\Users\AUSU\Desktop\FPGA\work\output_bit\topic1_hdmi_player.bit`  
（同源：`src\td_project\topic1_hdmi_player_Runs\phy_1\topic1_hdmi_player.bit`）
