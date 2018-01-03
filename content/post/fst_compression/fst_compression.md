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


```
## Error in threads_fst(8): could not find function "threads_fst"
```


```r
# file downloaded from https://www.kaggle.com/stackoverflow/so-survey-2017
sample_file <- "large/survey_results_public.csv"
raw_vec <- readBin(sample_file, "raw", file.size(sample_file))  # read byte contents 

# compress bytes with ZSTD
compressed_vec <- compress_fst(raw_vec, "ZSTD", 10)
```

```
## Error in compress_fst(raw_vec, "ZSTD", 10): could not find function "compress_fst"
```

```r
length(compressed_vec) / length(raw_vec)  # compression ratio
```

```
## Error in eval(expr, envir, enclos): object 'compressed_vec' not found
```









