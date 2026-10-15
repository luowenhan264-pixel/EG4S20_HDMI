def extract_last_nonzero_field(filename):
    results = []
    with open(filename, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip().startswith("|"):
                parts = [item.strip() for item in line.strip().split('|') if item.strip()]
                for val in reversed(parts):
                    if val != '00':
                        results.append(val)
                        break
    return results

def save_to_txt(data, output_file):
    with open(output_file, 'w', encoding='utf-8') as f:
        for item in data:
            f.write(item + '\n')

input_file = 'xin.txt'
output_file = 'output1.txt'

data = extract_last_nonzero_field(input_file)
save_to_txt(data, output_file)

print(f"共提取 {len(data)} 个值，输出到到 {output_file}")

