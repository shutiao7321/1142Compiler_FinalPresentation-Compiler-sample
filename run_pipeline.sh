#!/bin/bash

# 切換到專案資料夾
cd ~/final/1142Compiler_FinalPresentation-Compiler-sample/

echo "=========================================="
echo " 歡迎使用第 13 組編譯器專題流水線"
echo "=========================================="

# 1. 讓使用者選擇 sample 1 ~ sample 8
while true; do
    read -p "請輸入想要測試的編譯號碼 (1 ~ 8): " NUM
    # 檢查輸入是否為 1 到 8 的單一數字
    if [[ "$NUM" =~ ^[1-8]$ ]]; then
        FILE_NAME="sample${NUM}"
        break
    else
        echo "❌ 輸入錯誤！請輸入 1 到 8 之間的有效數字。"
    fi
done

echo "=========================================="
echo "🚀 開始執行編譯鏈流水線，目前目標檔案: ${FILE_NAME}.c"
echo "=========================================="

# 2. 檢查檔案是否存在，並使用自製編譯器進行「詞彙、語法、語意」三階段檢查
echo "[步驟 1/8] 使用自製編譯器進行全面前端檢查..."
if [ ! -f "${FILE_NAME}.c" ]; then
    echo "❌ 錯誤：找不到 ${FILE_NAME}.c 檔案，請確認檔案是否存在！"
    exit 1
fi

# 執行自製編譯器並擷取輸出內容
COMPILE_OUTPUT=$(./Compile < "${FILE_NAME}.c" | tee /dev/stderr)

# 設定一個標記變數，用來記錄有沒有任何一個階段出錯
HAS_ERROR=0

echo "------------------------------------------"
echo "🔍 正在分析編譯器檢查結果..."

# 階段 A：檢查詞彙錯誤 (Lexical Error)
if echo "$COMPILE_OUTPUT" | grep -iq "lexical error"; then
    echo "🛑 【階段錯誤】偵測到 🔴 詞彙錯誤 (Lexical Error)！"
    echo "   👉 說明：程式碼中包含自製編譯器看不懂的非法字元或火星文。"
    HAS_ERROR=1
fi

# 階段 B：檢查語法錯誤 (Syntax Error)
if echo "$COMPILE_OUTPUT" | grep -iq "syntax error"; then
    echo "🛑 【階段錯誤】偵測到 🟡 語法錯誤 (Syntax Error)！"
    echo "   👉 說明：程式碼結構不符合語法規則（例如括號沒對齊、少分號、結構寫錯）。"
    HAS_ERROR=1
fi

# 階段 C：檢查語意錯誤 (Semantic Error)
if echo "$COMPILE_OUTPUT" | grep -iq "semantic error"; then
    echo "🛑 【階段錯誤】偵測到 🔵 語意錯誤 (Semantic Error)！"
    echo "   👉 說明：結構正確但邏輯不通（例如使用未宣告變數 ${FILE_NAME}.c 中的 PI、型態不匹配）。"
    HAS_ERROR=1
fi

# 總結判定
if [ $HAS_ERROR -eq 1 ]; then
    echo ""
    echo "**************************************************"
    echo "❌ 專案前端檢查未通過，流水線已安全攔截並中斷！"
    echo "   請修正 ${FILE_NAME}.c 後再重新執行。"
    echo "**************************************************"
    exit 1
fi

echo "✅ 詞彙、語法、語意全數檢查通過！繼續執行後端優化與編譯流程..."
echo "------------------------------------------"

# 3. 安裝 LLVM 與 Clang 後端工具
echo "[步驟 2/8] 檢查並安裝 Clang 與 LLVM..."
sudo apt-get install clang llvm -y

# 4. 顯示版本資訊
echo "[步驟 3/8] 檢查編譯器版本..."
clang --version
llc --version

# 5. 產生 LLVM IR 中間碼 (.ll) - 【新增防禦】
echo "[步驟 4/8] 正在將 C 碼轉為 LLVM IR 中間碼..."
if ! clang -S -emit-llvm "${FILE_NAME}.c"; then
    echo "❌ 錯誤：Clang 生成 LLVM IR 失敗！核心編譯中斷。"
    exit 1
fi

# 6. 進行 LLVM 最佳化 - 【新增防禦】
echo "[步驟 5/8] 正在使用 opt 進行 mem2reg 最佳化..."
if ! opt -S -passes='globalopt,loop-simplify,mem2reg' "${FILE_NAME}.ll" -o "${FILE_NAME}_opt.ll"; then
    echo "❌ 錯誤：opt 最佳化分析失敗！"
    exit 1
fi

# 7. 將最佳化後的中間碼轉為組合語言 (.s) - 【新增防禦】
echo "[步驟 6/8] 正在使用 llc 將中間碼轉為 x86 組合語言..."
if ! llc "${FILE_NAME}_opt.ll" -o "${FILE_NAME}.s"; then
    echo "❌ 錯誤：llc 轉換為 x86 組合語言失敗！"
    exit 1
fi

# 8. 將組合語言組譯成目的檔 (.o) - 【新增防禦】
echo "[步驟 7/8] 正在使用 GNU As組譯器生成 ${FILE_NAME}.o..."
if ! as "${FILE_NAME}.s" -o "${FILE_NAME}.o"; then
    echo "❌ 錯誤：as 組譯器執行失敗！"
    exit 1
fi

# 9. 使用手動 ld 核心連結 - 【新增防禦】
echo "[步驟 8/8] 正在手動使用 ld 連結 C 語言標準庫..."
if ! ld -o "${FILE_NAME}_ex" \
   -dynamic-linker /lib64/ld-linux-x86-64.so.2 \
   /usr/lib/x86_64-linux-gnu/crt1.o \
   /usr/lib/x86_64-linux-gnu/crti.o \
   "${FILE_NAME}.o" \
   -lc \
   /usr/lib/x86_64-linux-gnu/crtn.o; then
    echo "❌ 錯誤：ld 連結器包裝失敗！"
    exit 1
fi

echo "=========================================="
echo "🎉 連結成功！正在直接執行產出的程式 ${FILE_NAME}_ex："
echo "------------------------------------------"
./"${FILE_NAME}_ex"
echo "------------------------------------------"
echo "=========================================="
