from PIL import Image

def rgb_to_txt(image_path, output_txt_path):
    img = Image.open(image_path).convert('RGB')
    width, height = img.size

    assert width == 64 and height == 64, "图像尺寸必须为 64x64"

    pixels = list(img.getdata())

    with open(output_txt_path, 'w', encoding='utf-8') as f:
        for idx, (r, g, b) in enumerate(pixels):
            address = f"{idx:04x}"  # 4位十六进制地址
            rgb_hex = f"{r:02x}{g:02x}{b:02x}"  # 每个通道2位，共6位
            line = f"f1{address}{rgb_hex}"
            f.write(line + '\n')

    print(f"转换完成，共写入 {len(pixels)} 行，保存为：{output_txt_path}")

# 示例使用
rgb_to_txt("logo.png", "output_logo.txt")
