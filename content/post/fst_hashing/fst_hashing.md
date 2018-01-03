---
title: "Multi-threaded hashing with xxHash"
author: "Mark Klik"
date: '2017-12-16'
coverImage: //d1u9biwaxjngwg.cloudfront.net/welcome-to-tranquilpeak/city.jpg
editor_options:
  chunk_output_type: console
metaAlignment: center
slug: fst_hashing
tags:
- compression
- serialization
- fst package
- hashing
- benchmark
thumbnailImage: /img/fst_hashing/media/fingerprint.jpg
thumbnailImagePosition: left
categories:
- R
- compression
- serialization
- hashing
- benchmark
- fst package
---

Version 0.8.0 of R's _fst_ package has been released to CRAN. The package is now multi-threaded allowing for even faster serialization of data frames to disk.

<!--more-->

This post covers some of the enhancements that have been made to _fst_ and introduces the new in-memory compression and hashing features. Some benchmarks are shown comparing performance against data frame serialization methods offered by packages _data.table_, _feather_ and by _base R_ itself.

<!-- toc -->


## Multi-threaded hashing


```r
# file downloaded from https://www.kaggle.com/stackoverflow/so-survey-2017
sample_file <- "large/survey_results_public.csv"
raw_vec <- readBin(sample_file, "raw", file.size(sample_file))  # read byte contents 

# file size (in MB)
1e-6 * file.size(sample_file)
```

```
## [1] 93.09709
```

The last feature that I would like to mention briefly is the multi-threaded hashing algorithm that has been added to fst v0.8.0:


```r
hash_fst(raw_vec)
```

```
## [1]  1853499107 -1914678989
```

The return value is a length two integer vector because the hashing algorithm is actually a 64-bit hashing algorithm. Based on the already fast [xxHash](http://cyan4973.github.io/xxHash/) algorithm, the speed of the multi-threaded hash implementation in _fst_ is pretty extreme:




```r
threads_fst(8)

hash_timing <- microbenchmark(
  hash_fst(raw_vec),
  times = 1000
)

# hashing speed (GB/s)
as.numeric(object.size(raw_vec)) / median(hash_timing$time)
```


```r
as.numeric(object.size(raw_vec)) / median(hash_timings$time)
```

```
## [1] 44.06274
```

That's a hashing speed of more than 44 GB/s !

