import numpy as np
from PIL import Image

# 设置图像尺寸
width, height = 640, 480
total_pixels = width * height

# 读取每行的十六进制字符串
with open('output1.txt', 'r', encoding='utf-8') as f:
    hex_lines = [line.strip() for line in f if line.strip()]

# 数据校验与修正
if len(hex_lines) < total_pixels:
    print(f"数据不足 {total_pixels} 像素，自动补零")
    hex_lines += ['00'] * (total_pixels - len(hex_lines))  # 补0
elif len(hex_lines) > total_pixels:
    print(f"数据超出 {total_pixels} 像素，自动截断")
    hex_lines = hex_lines[:total_pixels]

# 转换为灰度整数值
pixels = [int(h, 16) for h in hex_lines]
image_array = np.array(pixels, dtype=np.uint8).reshape((height, width))

# 生成并显示图像
image = Image.fromarray(image_array, mode='L')  # 'L' 表示灰度图
image.show()

# 保存图像
image.save('gray_output.png')
print("灰度图已生成并保存为 gray_output.png")
