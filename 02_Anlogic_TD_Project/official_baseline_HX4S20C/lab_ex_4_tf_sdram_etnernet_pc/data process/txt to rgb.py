import numpy as np
from PIL import Image
import os

WIDTH = 640
HEIGHT = 480
TOTAL_PIXELS = WIDTH * HEIGHT

def extract_last_rgb_per_line(filename):
    rgb_data = []
    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line.startswith("|"):
                parts = [item.strip() for item in line.split('|') if item.strip()]
                non_zero = [val for val in reversed(parts) if val != '00']
                if len(non_zero) >= 3:
                    rgb = list(reversed(non_zero[:3]))
                    rgb_data.append(rgb)
    return rgb_data

def save_to_txt(data, output_file):
    with open(output_file, 'w', encoding='utf-8') as f:
        for rgb in data:
            f.write(' '.join(rgb) + '\n')

def rgb_data_to_fixed_image(rgb_data, output_image, width=WIDTH, height=HEIGHT):
    expected_pixels = width * height
    if len(rgb_data) < expected_pixels:
        print(f"像素不足 {expected_pixels}，补黑像素")
        rgb_data += [['00', '00', '00']] * (expected_pixels - len(rgb_data))
    elif len(rgb_data) > expected_pixels:
        print(f"像素超出 {expected_pixels}，自动截断")
        rgb_data = rgb_data[:expected_pixels]

    rgb_values = [tuple(int(x, 16) for x in rgb) for rgb in rgb_data]
    image_array = np.array(rgb_values, dtype=np.uint8).reshape((height, width, 3))

    image = Image.fromarray(image_array, mode='RGB')
    image = image.transpose(Image.ROTATE_180)  # 旋转180度

    image.save(output_image)
    image.show()
    print(f"图像保存为：{output_image}（{width}x{height}）")

if __name__ == "__main__":
    input_file = 'xin.txt'      # 请替换为你的输入文件名
    output_txt = 'output4.txt'
    output_image = 'color_output.png'

    if not os.path.exists(input_file):
        print(f"找不到文件：{input_file}")
        exit(1)

    rgb_pixels = extract_last_rgb_per_line(input_file)
    print(f"提取了 {len(rgb_pixels)} 个 RGB 像素")
    save_to_txt(rgb_pixels, output_txt)
    print(f"RGB 数据已保存到：{output_txt}")

    rgb_data_to_fixed_image(rgb_pixels, output_image)
