# Walrus Sites Storage Cost Estimate

## Build Output

| File | Raw Size | Gzipped |
|------|----------|---------|
| `index.html` | 1.16 KB | 0.63 KB |
| `assets/index-DgoMNfSc.js` | 565.49 KB | 177.60 KB |
| `assets/index-BLaUjd_y.css` | 34.04 KB | 6.91 KB |
| **Total** | **600.69 KB** | **185.14 KB** |

## Walrus Dry-Run Results (testnet, 1 epoch)

| File | Unencoded | Encoded (with metadata) | Cost |
|------|-----------|-------------------------|------|
| `index.html` | 1.13 KiB | 63.0 MiB | 0.0002 WAL |
| `index-DgoMNfSc.js` | 552 KiB | 64.9 MiB | 0.0002 WAL |
| `index-BLaUjd_y.css` | 33.2 KiB | 63.0 MiB | 0.0002 WAL |
| **Per-blob total** | **586.33 KiB** | **190.9 MiB** | **0.0006 WAL** |

## Notes on Actual Deploy Cost

- **site-builder uses quilts**: Small files get batched into a single blob, reducing per-blob metadata overhead. The actual number of blobs may be less than 3.
- **Dry-run was on testnet**: Testnet epochs are 1 day. Mainnet epochs are 14 days. Pricing per epoch differs between networks.
- **Encoded size is high relative to raw size**: This is expected. Walrus uses RedStuff/Reed-Solomon erasure coding that replicates data across 1000 shards for fault tolerance. The 63 MiB minimum is the metadata overhead baseline per blob.
- **Gas costs**: Each blob storage transaction also costs SUI gas (~0.005 SUI per transaction, 3 transactions per blob).
- **ws-resources.json**: The site-builder also stores this config on-chain, adding a small additional cost.

## Estimated Total for 1 Epoch on Mainnet

Based on testnet dry-run data and cost calculator defaults:

- **Storage**: ~0.0006 WAL (may be less with quilt batching)
- **Gas**: ~0.045 SUI (3 blobs x 3 txns x 0.005 SUI)
- **Recommendation**: Have at least **0.01 WAL** and **0.1 SUI** in your mainnet wallet to cover storage + gas with margin.

## References

- [Walrus Cost Calculator](https://costcalculator.wal.app/)
- [Walrus Sites Documentation](https://docs.wal.app/walrus-sites/overview.html)
