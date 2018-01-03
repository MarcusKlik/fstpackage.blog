---
title: "Multi-threaded compression from R using LZ4 and ZSTD"
author: "Mark Klik"
date: '2017-12-16'
coverImage: /img/fst_compression/media/space_coast.jpg
editor_options:
  chunk_output_type: console
metaAlignment: center
slug: fst_compression
tags:
- fst package
- compression
thumbnailImage: /img/fst_compression/media/compression.jpg
thumbnailImagePosition: left
categories:
- R
- compression
- fst package
---

Version 0.8.0 of R's _fst_ package has been released to CRAN. The package is now multi-threaded allowing for even faster serialization of data frames to disk.

<!--more-->

This post covers some of the enhancements that have been made to _fst_ and introduces the new in-memory compression and hashing features. Some benchmarks are shown comparing performance against data frame serialization methods offered by packages _data.table_, _feather_ and by _base R_ itself.

<!-- toc -->


## Multi-threaded access to LZ4 and ZSTD compressors

The LZ4 and ZSTD compressors can now be used directly using methods _compress\_fst_ and _decompress\_fst_. For example, to compress the csv file  _survey\_results\_public.csv_ [from Kaggle](https://www.kaggle.com/stackoverflow/so-survey-2017) (with data about StackOverflow users), you can use:




```r
# file downloaded from https://www.kaggle.com/stackoverflow/so-survey-2017
sample_file <- "large/survey_results_public.csv"
raw_vec <- readBin(sample_file, "raw", file.size(sample_file))  # read byte contents 

# compress bytes with ZSTD
compressed_vec <- compress_fst(raw_vec, "ZSTD", 10)

length(compressed_vec) / length(raw_vec)  # compression ratio
```

```
## [1] 0.1194816
```

This compresses the contents of the _survey\_results\_public.csv_ file to about 12 percent of the original size. You can decompress again with:


```r
raw_vec_decompressed <- decompress_fst(compressed_vec)
```

What's special about the fst implementation is that it's a fully multi-threaded implementation of the underlying compression algorithms, boosting the compression and decompression speeds:





```r
# compress with LZ4 on maximum compression setting
compress_time <- microbenchmark(
  compress_fst(raw_vec, "ZSTD", 10),
  times = 10
)

# decompress again
decompress_time <- microbenchmark(
  decompress_fst(compressed_vec),
  times = 10
)

cat("Compress: ", 1e3 * as.numeric(object.size(raw_vec)) / median(compress_time$time),
    "Decompress: ", 1e3 * as.numeric(object.size(raw_vec)) / median(decompress_time$time))
```


```
## Compress:  1509.439 Decompress:  2908.441
```

The measurement was done using 8 threads. Just like with _write\_fst_, compression is done on multiple threads, but there is no optimization for specific types (because the raw input vector can contain any type of data).
