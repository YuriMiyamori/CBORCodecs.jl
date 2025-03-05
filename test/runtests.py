import cbor2

def generate_expected_data():
  # ここでruntests.jlの全てのテストケース用の正解データを定義する
  expected_data = {
    "integer": 42,
    "float": 3.14159,
    "string": "Hello, CBOR!",
    "array": [1, 2, 3],
    "map": {"a": 1, "b": 2},
    "bool_true": True,
    "bool_false": False,
    "none": None,
    "binary": b'\xde\xad\xbe\xef',
    "nested": {"list": [1, {"inner": "value"}]}
  }
  # expected_data をCBOR形式に変換
  return cbor2.dumps(expected_data)

def main():
  # CBOR形式の正解データをファイルに書き出す
  cbor_bytes = generate_expected_data()
  with open("expected_data.cbor", "wb") as f:
    f.write(cbor_bytes)
  print("正解データが expected_data.cbor に生成されました。")

if __name__ == "__main__":
  main()

def generate_expected_data():
  # ここでruntests.jlのテストケース用の正解データを定義する
  expected_data = {
    "integer": 42,
    "float": 3.14159,
    "string": "Hello, CBOR!",
    "array": [1, 2, 3],
    "map": {"a": 1, "b": 2}
  }
  # expected_data をCBOR形式に変換
  return cbor2.dumps(expected_data)

def main():
  # CBOR形式の正解データをファイルに書き出す
  cbor_bytes = generate_expected_data()
  with open("expected_data.cbor", "wb") as f:
    f.write(cbor_bytes)
  print("正解データが expected_data.cbor に生成されました。")

if __name__ == "__main__":
  main()