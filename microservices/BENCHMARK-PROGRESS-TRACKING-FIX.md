# Perbaikan Progress Tracking di run-benchmark.sh

## 🔧 Masalah yang Diperbaiki

**Masalah:** Variable `test_count` tidak pernah ter-increment dalam loop progress tracking, sehingga selalu menampilkan `[0%] (0/12)` meskipun test sedang berjalan.

## ✅ Solusi yang Diimplementasikan

### 1. **Dynamic Progress Tracking**
```bash
# Sebelum (SALAH):
test_count=0  # Tidak pernah di-update

while kill -0 $BENCHMARK_PID 2>/dev/null; do
    for i in $(seq 0 ${#SPINNER}); do
        test_progress=$((test_count * 100 / total_tests))
        printf "... [${test_progress}%%] (${test_count}/${total_tests})"
        sleep 0.2
    done
done
```

```bash
# Setelah (BENAR):
# Melacak berdasarkan file hasil yang dibuat
while kill -0 $BENCHMARK_PID 2>/dev/null; do
    if [ -d "$RESULTS_DIR" ]; then
        current_results=$(find "$RESULTS_DIR" -name "benchmark_results_*.json" 2>/dev/null | wc -l)
        test_count=$((current_results - initial_results))
        
        # Cap maksimal agar tidak melebihi 100%
        if [ $test_count -gt $total_tests ]; then
            test_count=$total_tests
        fi
    fi
    
    test_progress=$((test_count * 100 / total_tests))
    printf "... [${test_progress}%%] (${test_count}/${total_tests})"
    sleep 0.5
done
```

### 2. **Baseline Tracking**
- **Mendapatkan hitungan file awal** sebelum benchmark dimulai
- **Menghitung progress** berdasarkan file baru yang dibuat
- **Mencegah overflow** dengan cap maksimal

### 3. **Enhanced Display Messages**
```bash
# Pesan dinamis berdasarkan progress
if [ $test_count -eq 0 ]; then
    progress_msg="Initializing tests..."
elif [ $test_count -eq $total_tests ]; then
    progress_msg="Finalizing results..."
else
    progress_msg="Running worker variation tests..."
fi
```

### 4. **Accurate Final Summary**
```bash
# Menampilkan jumlah yang akurat setelah selesai
final_results=$(find "$RESULTS_DIR" -name "benchmark_results_*.json" 2>/dev/null | wc -l)
final_test_count=$((final_results - initial_results))

echo "✓ All worker variation tests completed! (${final_test_count}/${total_tests} tests)"
echo "New results generated: ${new_results} benchmark files"
echo "Total results in directory: ${result_count} benchmark files"
```

## 📊 Peningkatan User Experience

### Sebelum:
```
⠋ Running worker variation tests... [0%] (0/12)  # Tidak berubah
⠙ Running worker variation tests... [0%] (0/12)  # Tidak berubah
⠹ Running worker variation tests... [0%] (0/12)  # Tidak berubah
```

### Sesudah:
```
⠋ Initializing tests... [0%] (0/12)
⠙ Running worker variation tests... [25%] (3/12)
⠹ Running worker variation tests... [50%] (6/12)
⠸ Running worker variation tests... [75%] (9/12)
⠼ Finalizing results... [100%] (12/12)
✓ All worker variation tests completed! (12/12 tests)
```

## 🔍 Technical Details

### Key Changes:
1. **Real-time file monitoring** untuk melacak hasil benchmark
2. **Baseline tracking** dengan `initial_results`
3. **Progress capping** untuk mencegah persentase > 100%
4. **Improved spinner timing** (0.5s untuk responsiveness yang lebih baik)
5. **Contextual messages** berdasarkan tahap progress

### Error Handling:
- Fallback jika direktori hasil tidak ada
- Penanganan jika file hasil lebih banyak dari ekspektasi
- Graceful handling untuk edge cases

## 🚀 Cara Testing

1. Jalankan benchmark script:
   ```bash
   cd microservices/scripts/benchmark
   ./run-benchmark.sh
   ```

2. Observasi progress counter yang sekarang akan:
   - ✅ Increment secara real-time
   - ✅ Menampilkan persentase yang akurat
   - ✅ Memberikan feedback visual yang informatif
   - ✅ Menampilkan summary yang benar di akhir

## 📈 Performance Impact

- **Minimal overhead:** Hanya menjalankan `find` command setiap 0.5 detik
- **Better UX:** User dapat melihat progress yang real dan akurat
- **Debugging:** Lebih mudah untuk mengetahui jika ada test yang stuck 