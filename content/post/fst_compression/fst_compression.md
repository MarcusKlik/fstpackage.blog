---
title: "Multi-threaded LZ4 and ZSTD compression from R"
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

The _fst_ package uses LZ4 and ZSTD compression to compact data stored in the _fst_ format. In the latest release, methods _compress\_fst_ and _decompress\_fst_ were added to provide direct multi-threaded access to these compressors.

<!--more-->

## LZ4 and ZSTD

[LZ4](http://lz4.github.io/lz4/) is one of the fastest compressors around, and like all LZ77-type compressors, decompression is even faster. The _fst_ package uses LZ4 to compress and decompress data when lower compression levels are selected (for _write\_fst_). For higher compression levels, the [ZSTD](https://github.com/facebook/zstd) compressor is used, which offers superior compression ratio's but requires more CPU resources.

## Multi-threaded access to LZ4 and ZSTD compressors

In _fst_ version 0.8.0, methods _compress\_fst_ and _decompress\_fst_ were added. These methods give you direct access to LZ4 and ZSTD. As an example of how they can be used, we download the _survey\_results\_public.csv_ file [from Kaggle](https://www.kaggle.com/stackoverflow/so-survey-2017) and recompress it using ZSTD:




```r
library(fst)

# you can download this file from https://www.kaggle.com/stackoverflow/so-survey-2017
sample_file <- "survey_results_public.csv"

# read file into a raw vector
raw_vec <- readBin(sample_file, "raw", file.size(sample_file))  # read byte contents 

# compress bytes with ZSTD (at a 50 percent compression level setting)
compressed_vec <- compress_fst(raw_vec, "ZSTD", 20)

# write the compressed data into a new file
writeBin(compressed_vec, "survey_results_public.fsc")

length(raw_vec) / length(compressed_vec)  # compression ratio
```

```
## [1] 8.949771
```

The contents of the _survey\_results\_public.csv_ file are ecompressed to about 11 percent of the original size (the inverse of the compression ratio). In this example a compression setting of 20 percent of maximum was used. To decompress again you can do:


```r
raw_vec_decompressed <- decompress_fst(compressed_vec)  # decompress raw vector
```

What's special about the _fst_ implementation is that it's a fully multi-threaded implementation of the underlying compression algorithms. This is accomplished by dividing the data into (at maximum) 48 blocks, which are then compressed in parallel. This increases the compression and decompression speeds significantly at a small cost to compression ratio:


```r
library(microbenchmark)

threads_fst(8)  # use 8 threads

# measure ZSTD compression performance at low setting
compress_time <- microbenchmark(
  compress_fst(raw_vec, "ZSTD", 10)
)

# decompress again
decompress_time <- microbenchmark(
  decompress_fst(compressed_vec)
)

cat("Compress: ", 1e3 * as.numeric(object.size(raw_vec)) / median(compress_time$time),
    "Decompress: ", 1e3 * as.numeric(object.size(raw_vec)) / median(decompress_time$time))
```


```
## Compress:  1299.649 Decompress:  1948.932
```

The contents of the _survey\_results\_public.csv_ file can be compressed with a factor of 8.4 at a compression speed of around 1.3 GB/s, that's pretty fast!

## Bring on the cores

With more cores, you can do more parallel compression work. With a small benchmark we can show this dependency:


```r
library(data.table)

# benchmark results
bench <- data.table(Threads = as.integer(NULL), Time = as.numeric(NULL),
  Mode = as.character(NULL), Level = as.integer(NULL), Size = as.numeric(NULL))

# Note that compression with levels above 50 percent take a long time.
# If you want to run this code yourself, start with levels 10 * 0:5
for (level in 10 * 0:10) {
  for (threads in 1:parallel::detectCores()) {

    cat(".")  # show some progress
    threads_fst(threads)  # set number of threads to use
    
    # compress and decompress measurements
    compress_time <- microbenchmark(compressed_vec <- compress_fst(raw_vec, "ZSTD", level), times = 25)
    decompress_time <- microbenchmark(decompress_fst(compressed_vec), times = 25)
    
    # add compress and decompress measurements to the benchmark results
    bench <- rbindlist(list(bench, 
      data.table(
        Threads = threads,
        Time = median(compress_time$time),
        Mode = "Compress",
        Level = level,
        Size = as.integer(object.size(compressed_vec))),
      data.table(
        Threads = threads,
        Time = median(decompress_time$time),
        Mode = "Decompress",
        Level = level,
        Size = as.integer(object.size(compressed_vec)))))
  }
}
```

This creates a _data.table_ with compression and decompression benchmark results. We can display these results in a graph:


```r
library(ggplot2)

bench[, Speed := 1e3 * object.size(raw_vec) / Time]
bench[, Level := as.factor(Level)]

ggplot(bench) +
  geom_line(aes(Threads, Speed, colour = Level)) +
  geom_point(aes(Threads, Speed, colour = Level)) +
  facet_wrap(~Mode) +
  theme_minimal()
```

![plot of chunk unnamed-chunk-9](/img/fst_compression/img/fig-unnamed-chunk-9-1.png)

As can be expected, the compression speed is highest for lower compression level settings. But interesting enough, decompression speeds actually increase with higher compression settings! Additionaly, with stronger compression the length of the result (compressed) vector will decrease (higher compression ratio):

![plot of chunk unnamed-chunk-10](/img/fst_compression/img/fig-unnamed-chunk-10-1.png)

# The case for high compression levels

In many setups you need to compress your data once but decompress it often. Fo example, you compressed and stored a file that will need to be read many times in the future. In that case it's very useful to spend the CPU resources on compressing at a higher setting. It will give you higher decompression speeds during reads and the compressed data will occupy less space!
