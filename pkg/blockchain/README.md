# Blockchain dengan Protokol Konsensus Avalanche Paralel

Implementasi sederhana dari blockchain yang menggunakan protokol konsensus Avalanche dengan optimasi pemrosesan paralel. Blockchain ini memanfaatkan teknologi ParallelDAG untuk meningkatkan throughput transaksi.

## Fitur Utama

- **Protokol Konsensus Avalanche**: Menggunakan protokol konsensus Avalanche yang robust dengan finality yang cepat.
- **Pemrosesan Paralel**: Memanfaatkan ParallelDAG untuk memproses transaksi dan blok secara paralel.
- **API HTTP**: Menyediakan API HTTP untuk berinteraksi dengan blockchain.
- **Struktur DAG**: Mendukung struktur Directed Acyclic Graph (DAG) untuk blok, bukan hanya rantai linier.

## Cara Menjalankan

### Prasyarat

- Go 1.19 atau lebih baru
- Akses ke kode sumber avalanche-parallel

### Menjalankan Node

```bash
# Compile dan jalankan node dengan parallelism 4 dan port API 8545
go run cmd/blockchain/main.go --parallelism=4 --api-port=8545 --log-level=info
```

### Opsi Konfigurasi

- `--parallelism`: Jumlah maksimum worker paralel (default: 4)
- `--api-port`: Port untuk API HTTP (default: 8545)
- `--log-level`: Level logging (debug, info, warn, error)

## API HTTP

Blockchain node menyediakan API HTTP untuk berinteraksi dengan blockchain:

### Mendapatkan Informasi Blockchain

```
GET /info
```

Response:
```json
{
  "height": 10,
  "latestBlocksCount": 2
}
```

### Mendapatkan Blok

```
GET /blocks
GET /blocks?height=5
```

Response:
```json
[
  {
    "id": "2ZP5jTgGgBKfEePc1AEPyEAJ4aGUkjG4JEd3g5HHDpc1d3",
    "parentIDs": ["P1L4D7Qnj9Ebh75Y3YLMDMhFEtXACy7M8oyKGmrTNyi2w"],
    "height": 5,
    "timestamp": 1653986420000000000,
    "transactions": [...]
  }
]
```

### Mendapatkan Blok Berdasarkan ID

```
GET /block?id=2ZP5jTgGgBKfEePc1AEPyEAJ4aGUkjG4JEd3g5HHDpc1d3
```

### Mendapatkan Transaksi

```
GET /transactions
```

### Mendapatkan Transaksi Berdasarkan ID

```
GET /transaction?id=21PeVxd9soBshXxK4yWAfHiT2P1DprS6A5TSYQTX1yHe6
```

### Mengirim Transaksi

```
POST /submit-transaction
```

Body:
```json
{
  "sender": "alice",
  "recipient": "bob",
  "amount": 100,
  "nonce": 1
}
```

Response:
```json
{
  "success": true,
  "txId": "21PeVxd9soBshXxK4yWAfHiT2P1DprS6A5TSYQTX1yHe6",
  "message": "Transaction submitted successfully"
}
```

### Membuat Blok

```
POST /create-block
```

Body:
```json
{
  "parentIds": ["P1L4D7Qnj9Ebh75Y3YLMDMhFEtXACy7M8oyKGmrTNyi2w"],
  "maxTransactions": 10
}
```

Response:
```json
{
  "success": true,
  "blockId": "2ZP5jTgGgBKfEePc1AEPyEAJ4aGUkjG4JEd3g5HHDpc1d3",
  "height": 5,
  "transactionCount": 3,
  "message": "Block created and submitted successfully"
}
```

## Komponen Utama

### Transaction

`Transaction` merepresentasikan transaksi dalam blockchain dan mengimplementasikan interface `snowstorm.Tx` dari Avalanche.

Atribut utama:
- `TxID`: ID transaksi
- `Sender`: Pengirim transaksi
- `Recipient`: Penerima transaksi
- `Amount`: Jumlah yang dikirim
- `Nonce`: Nomor urut transaksi
- `Signature`: Tanda tangan digital

### Block

`Block` merepresentasikan blok dalam blockchain dan mengimplementasikan interface `avalanche.Vertex` dari Avalanche.

Atribut utama:
- `BlockID`: ID blok
- `ParentIDs`: ID blok-blok parent
- `Height`: Tinggi blok dalam blockchain
- `Transactions`: Daftar transaksi dalam blok

### Blockchain

`Blockchain` adalah komponen utama yang mengelola state blockchain dan menggunakan ParallelEngine untuk konsensus.

Fungsi utama:
- `AddTransaction`: Menambahkan transaksi ke mempool
- `CreateBlock`: Membuat blok baru dengan transaksi dari mempool
- `SubmitBlock`: Mengirimkan blok ke engine konsensus
- `ProcessPendingBlocks`: Memproses blok-blok yang pending

### Node

`Node` menyediakan API HTTP untuk berinteraksi dengan blockchain.

## Proses Konsensus Avalanche Paralel

1. Transaksi ditambahkan ke mempool.
2. Blok dibuat dengan memilih transaksi dari mempool.
3. Blok disubmit ke ParallelEngine untuk diproses.
4. ParallelEngine menggunakan ParallelDAG untuk memproses blok secara paralel.
5. Blok yang diterima ditambahkan ke blockchain dan transaksinya diterima.

## Performa

Dengan memanfaatkan pemrosesan paralel, blockchain ini dapat mencapai throughput yang lebih tinggi dibandingkan dengan implementasi sekuensial tradisional.

- Dengan 4 thread paralel, throughput dapat meningkat hingga 4x.
- Scaling linear dengan jumlah thread (hingga batas paralelisme yang dapat dicapai).
- Latency transaksi yang lebih rendah karena pemrosesan yang lebih cepat. 